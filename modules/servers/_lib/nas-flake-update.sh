#!/usr/bin/env bash
set -Eeuo pipefail

# Installed via pkgs.writeShellScript; all configuration comes from the NixOS unit.
: "${NAS_UPDATE_REPO:?}"
: "${NAS_UPDATE_USER:?}"
: "${NAS_UPDATE_URL:?}"
: "${NAS_UPDATE_TOKEN_FILE:?}"
: "${NAS_UPDATE_STATE_DIR:?}"

mode="${1:-}"
state_dir="$NAS_UPDATE_STATE_DIR"
repo="$NAS_UPDATE_REPO"
number="unknown"
lock_modified=false
pending_written=false

# ntfy auth is passed via curl's configuration file descriptor, rather than argv.
# Do not log the token or put it into a Nix derivation/environment variable.
notify() {
  local title="$1" priority="$2" message="$3" token
  token="$(tr -d '\r\n' < "$NAS_UPDATE_TOKEN_FILE")"
  if [[ ! "$token" =~ ^tk_[[:alnum:]_-]+$ ]]; then
    echo "Invalid ntfy token file format" >&2
    return 1
  fi
  printf '%s' "$message" | curl --silent --show-error --fail \
    --retry 2 --retry-delay 3 --retry-connrefused --connect-timeout 10 \
    --max-time 30 --output /dev/null \
    --config <(printf 'header = "Authorization: Bearer %s"\n' "$token") \
    --header "Title: $title" \
    --header "Priority: $priority" \
    --data-binary @- "$NAS_UPDATE_URL"
}

as_owner() {
  runuser -u "$NAS_UPDATE_USER" -- "$@"
}

# Notifications are sent even if an update fails. An uncommitted lockfile is
# restored to the pre-update checkpoint, without touching other tracked files.
on_exit() {
  local rc=$?
  if [[ "$mode" == run && "$rc" -ne 0 ]]; then
    if [[ "$lock_modified" == true ]]; then
      as_owner git -C "$repo" restore --staged --worktree -- flake.lock || true
    fi
    if [[ "$pending_written" == true ]]; then
      rm -f -- "$state_dir/pending"
    fi
    notify "NAS update #${number} FAILED" "5" \
      "Automatic NAS flake update #${number} failed (exit ${rc}). Review: journalctl -u nas-flake-update.service -n 100" || true
  fi
}
trap on_exit EXIT

if [[ "$mode" == run ]]; then
  mkdir -p -- "$state_dir"
  exec 9>"$state_dir/lock"
  flock -n 9 || { echo "Another NAS update is running" >&2; exit 1; }

  [[ -d "$repo/.git" || -f "$repo/.git" ]] || { echo "Not a Git checkout: $repo" >&2; exit 1; }
  [[ -f "$repo/flake.nix" && -f "$repo/flake.lock" ]] || { echo "Missing flake.nix / flake.lock" >&2; exit 1; }
  [[ ! -e "$state_dir/pending" ]] || { echo "Previous reboot completion is still pending" >&2; exit 1; }
  initial_status="$(as_owner git -C "$repo" status --porcelain --untracked-files=all)"
  [[ -z "$initial_status" ]] || {
    echo "Git checkout is not clean; refuse unattended commit or rebuild" >&2
    exit 1
  }
  as_owner git -C "$repo" symbolic-ref -q --short HEAD >/dev/null || {
    echo "Detached HEAD; refusing automatic commits" >&2
    exit 1
  }

  previous=0
  if [[ -f "$state_dir/sequence" ]]; then
    read -r previous < "$state_dir/sequence" || true
    [[ "$previous" =~ ^[0-9]+$ ]] || { echo "Invalid sequence file" >&2; exit 1; }
  fi
  next=$((10#$previous + 1))
  printf -v number '%06d' "$next"
  printf '%s\n' "$next" > "$state_dir/sequence.tmp"
  mv -f -- "$state_dir/sequence.tmp" "$state_dir/sequence"

  # Require acknowledgement from ntfy before touching the configuration.
  notify "NAS update #${number} STARTED" "3" \
    "NAS flake update #${number} started. Preparing numbered Git checkpoint; then refreshing inputs and building a boot generation."

  # This commit is intentionally empty: the worktree must already be clean.
  # It bookmarks the exact pre-update snapshot without committing unknown files.
  as_owner git -C "$repo" \
    -c user.name='NAS Flake Updater' \
    -c user.email='nas-flake-updater@localhost' \
    commit --allow-empty -m "nas: pre-update #${number}"
  before_sha="$(as_owner git -C "$repo" rev-parse HEAD)"

  # Use the checkout owner's permissions for the lockfile and Git index.
  lock_modified=true
  as_owner bash -c 'cd -- "$1" && exec nix flake update' bash "$repo"

  status="$(as_owner git -C "$repo" status --porcelain --untracked-files=all)"
  if [[ -z "$status" ]]; then
    lock_modified=false
    notify "NAS update #${number} FINISHED" "3" \
      "NAS flake update #${number}: no lockfile changes. Checkpoint ${before_sha:0:12}. No reboot necessary."
    exit 0
  fi
  if [[ "$status" != ' M flake.lock' ]]; then
    echo "Unexpected files changed by flake update: $status" >&2
    exit 1
  fi

  # Do not switch running services halfway through a NAS update.
  # Install only a new boot generation; it activates after reboot.
  nixos-rebuild boot --flake "$repo#nas"
  expected_system="$(readlink -f /nix/var/nix/profiles/system)"
  [[ -n "$expected_system" && -e "$expected_system" ]] || {
    echo "Cannot determine newly staged system generation" >&2
    exit 1
  }

  as_owner git -C "$repo" add -- flake.lock
  as_owner git -C "$repo" \
    -c user.name='NAS Flake Updater' \
    -c user.email='nas-flake-updater@localhost' \
    commit -m "nas: flake.lock update #${number}"
  lock_modified=false
  updated_sha="$(as_owner git -C "$repo" rev-parse HEAD)"

  # For correct post-boot reporting, remember what we installed and which
  # boot ID we started from. Persistent /var/lib survives the reboot.
  boot_id="$(cat /proc/sys/kernel/random/boot_id)"
  {
    printf '%s\n' "$number"
    printf '%s\n' "$boot_id"
    printf '%s\n' "$expected_system"
    printf '%s\n' "$updated_sha"
  } > "$state_dir/pending.tmp"
  mv -f -- "$state_dir/pending.tmp" "$state_dir/pending"
  pending_written=true

  echo "NAS update #$number staged as $expected_system; requesting reboot"
  # Leave pending state intact if systemd stops us immediately for reboot.
  pending_written=false
  if ! systemctl --no-block reboot; then
    rm -f -- "$state_dir/pending"
    exit 1
  fi

elif [[ "$mode" == finish ]]; then
  [[ -f "$state_dir/pending" ]] || exit 0
  exec 9>"$state_dir/lock"
  flock -n 9 || exit 0
  mapfile -t pending < "$state_dir/pending"
  [[ "${#pending[@]}" -eq 4 ]] || { echo "Invalid pending update state" >&2; exit 1; }
  number="${pending[0]}"
  previous_boot="${pending[1]}"
  expected_system="${pending[2]}"
  updated_sha="${pending[3]}"
  current_boot="$(cat /proc/sys/kernel/random/boot_id)"
  [[ "$current_boot" != "$previous_boot" ]] || exit 0
  actual_system="$(readlink -f /run/current-system)"

  if [[ "$actual_system" == "$expected_system" ]]; then
    notify "NAS update #${number} FINISHED" "3" \
      "NAS rebooted successfully into update #${number}. Generation: ${actual_system}; commit: ${updated_sha:0:12}."
  else
    notify "NAS update #${number} BOOT MISMATCH" "5" \
      "NAS has rebooted but the expected generation was NOT activated. Expected: ${expected_system}; running: ${actual_system}. Check bootloader and logs."
  fi
  rm -f -- "$state_dir/pending"
else
  echo "Usage: nas-flake-update {run|finish}" >&2
  exit 2
fi

