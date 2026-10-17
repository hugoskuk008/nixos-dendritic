#!/usr/bin/env bash
#
# theme-switch: imperatively symlink per-app theme configuration into
# $XDG_CONFIG_HOME, independently of Home Manager.
#
# Usage:
#   theme-switch gruvbox        select $SELECTIONS_DIR/gruvbox.json
#   theme-switch -f ./some.json select an explicit selection file
#   theme-switch --list         list the selections in $SELECTIONS_DIR
#
# Selection file (JSON):
#   {
#     "theme":   "gruvbox",           required: theme name
#     "host":    "laptop",            optional: overrides the detected hostname
#     "apps":    ["kitty", "waybar"], required: apps whose theme is switched
#     "command": "hyprctl reload"     optional: run after a successful switch
#   }
#
# "command" is either a string (run with bash -c) or an array of strings
# (executed directly as argv, no shell). It runs only if at least one link was
# applied, and sees THEME_SWITCH_THEME and THEME_SWITCH_HOST in its environment.
#
# Theme sources are looked up in order (first existing path wins):
#   1. $CONFIG_ROOT/$host/$app/$theme   host-specific
#   2. $CONFIG_ROOT/$app/$theme         shared
#
# Each resolved source is symlinked to $XDG_CONFIG_HOME/$app.
#
# Change marker: after linking, a stamp file named .theme-switch-marker is
# (re)written into every theme directory of each switched app, next to the
# configuration files. Its content differs on every switch, so whichever theme
# directory Home Manager sources for that app changes, and the next rebuild
# re-links it. The files must be visible to Nix (tracked, e.g. `git add -N -f`).
# Theme sources that are plain files cannot hold a marker and are skipped.
# Disable with --no-marker.
 
set -euo pipefail
 
readonly PROGRAM_NAME="theme-switch"
readonly EXIT_FAILURE=1
readonly EXIT_USAGE=64
 
readonly XDG_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly DENDRITIC_DIR="${THEME_SWITCH_DENDRITIC_DIR:-$HOME/nixos-dendritic}"
readonly DEFAULT_CONFIG_ROOT="$DENDRITIC_DIR/config"
readonly DEFAULT_SELECTIONS_DIR="$DENDRITIC_DIR/themes"
readonly MARKER_NAME=".theme-switch-marker"
 
CONFIG_ROOT="${THEME_SWITCH_CONFIG_ROOT:-$DEFAULT_CONFIG_ROOT}"
SELECTIONS_DIR="${THEME_SWITCH_SELECTIONS_DIR:-$DEFAULT_SELECTIONS_DIR}"
SELECTION_NAME=""
SELECTION_FILE=""
LIST_ONLY=false
DRY_RUN=false
STRICT=false
WRITE_MARKER=true
 
# Parallel arrays describing the validated plan: PLAN_SOURCES[i] -> PLAN_TARGETS[i].
PLAN_SOURCES=()
PLAN_TARGETS=()
PLAN_ERRORS=0
 
# Theme directories that receive a change marker once linking succeeded.
MARKER_DIRS=()
 
log_info() { printf '%s: %s\n' "$PROGRAM_NAME" "$*"; }
log_warn() { printf '%s: warning: %s\n' "$PROGRAM_NAME" "$*" >&2; }
log_error() { printf '%s: error: %s\n' "$PROGRAM_NAME" "$*" >&2; }
 
die() {
  local -r status="$1"
  shift
  log_error "$*"
  exit "$status"
}
 
usage() {
  cat <<USAGE
Usage: $PROGRAM_NAME [options] [NAME]
 
Select NAME from $DEFAULT_SELECTIONS_DIR (NAME.json), or pass -f for an
explicit selection file.
 
Options:
  -f, --file PATH     Selection JSON file (instead of NAME)
  -l, --list          List available selections and exit
  -r, --root PATH     Theme config root   (default: $DEFAULT_CONFIG_ROOT)
  -n, --dry-run       Show what would change without touching the filesystem
  -s, --strict        Treat a missing theme for any app as a fatal error
  -M, --no-marker     Do not write the change marker for Home Manager
  -h, --help          Show this help
USAGE
}
 
parse_args() {
  while (($# > 0)); do
    case "$1" in
      -f | --file)
        [[ $# -ge 2 ]] || die "$EXIT_USAGE" "$1 requires a value"
        SELECTION_FILE="$2"
        shift 2
        ;;
      -r | --root)
        [[ $# -ge 2 ]] || die "$EXIT_USAGE" "$1 requires a value"
        CONFIG_ROOT="$2"
        shift 2
        ;;
      -l | --list)
        LIST_ONLY=true
        shift
        ;;
      -n | --dry-run)
        DRY_RUN=true
        shift
        ;;
      -s | --strict)
        STRICT=true
        shift
        ;;
      -M | --no-marker)
        WRITE_MARKER=false
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -*)
        usage >&2
        die "$EXIT_USAGE" "unknown option: $1"
        ;;
      *)
        [[ -z "$SELECTION_NAME" ]] || die "$EXIT_USAGE" "only one selection name may be given"
        SELECTION_NAME="$1"
        shift
        ;;
    esac
  done
}
 
# A path component must be a plain name: no separators, no traversal, no
# leading dash. This prevents a malformed selection file or argument from
# escaping the theme tree or the XDG config directory.
is_safe_name() {
  local -r name="$1"
  [[ -n "$name" && "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && "$name" != *..* ]]
}
 
# Print the name of every selection available in $SELECTIONS_DIR.
list_selections() {
  [[ -d "$SELECTIONS_DIR" ]] || die "$EXIT_FAILURE" "selections directory not found: $SELECTIONS_DIR"
 
  local file
  for file in "$SELECTIONS_DIR"/*.json; do
    [[ -e "$file" ]] || continue
    basename "$file" .json
  done
}
 
# Turn the parsed arguments into a single SELECTION_FILE path.
resolve_selection_file() {
  if [[ -n "$SELECTION_FILE" && -n "$SELECTION_NAME" ]]; then
    die "$EXIT_USAGE" "give either a selection name or --file, not both"
  fi
 
  if [[ -n "$SELECTION_NAME" ]]; then
    is_safe_name "$SELECTION_NAME" || die "$EXIT_USAGE" "invalid selection name: '$SELECTION_NAME'"
    SELECTION_FILE="$SELECTIONS_DIR/$SELECTION_NAME.json"
  fi
 
  if [[ -z "$SELECTION_FILE" ]]; then
    usage >&2
    die "$EXIT_USAGE" "no selection given"
  fi
}
 
# Verify the selection file exists and has the expected JSON shape.
validate_selection_file() {
  [[ -f "$SELECTION_FILE" ]] || die "$EXIT_FAILURE" "selection file not found: $SELECTION_FILE"
 
  jq -e '
    (.theme | type == "string") and
    (.apps  | type == "array" and all(type == "string")) and
    ((.host // "") | type == "string") and
    ((.command == null) or
     (.command | (type == "string" and length > 0) or
                 (type == "array" and length > 0 and all(type == "string" and length > 0))))
  ' "$SELECTION_FILE" >/dev/null ||
    die "$EXIT_FAILURE" "invalid selection file (see header of $PROGRAM_NAME for the schema): $SELECTION_FILE"
}
 
# Resolve the host name: JSON override first, then the system hostname.
resolve_host() {
  local host
  host="$(jq -r '.host // empty' "$SELECTION_FILE")"
  if [[ -z "$host" ]]; then
    host="$(hostname)"
  fi
  printf '%s' "$host"
}
 
# Print the first existing theme source for an app, or nothing if none exists.
find_theme_source() {
  local -r host="$1" app="$2" theme="$3"
  local candidate
  for candidate in \
    "$CONFIG_ROOT/$host/$app/$theme" \
    "$CONFIG_ROOT/$app/$theme"; do
    if [[ -e "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}
 
# A target may be absent or an existing symlink. Anything else is user data
# that this tool must never destroy.
is_replaceable_target() {
  local -r target="$1"
  [[ ! -e "$target" && ! -L "$target" ]] || [[ -L "$target" ]]
}
 
record_error() {
  log_error "$*"
  PLAN_ERRORS=$((PLAN_ERRORS + 1))
}
 
# Queue every theme directory of an app (host-specific and shared) for a marker.
# All of them are stamped because Home Manager may source a different theme
# than the one being switched to.
collect_marker_dirs() {
  local -r host="$1" app="$2"
  local base dir
  for base in "$CONFIG_ROOT/$host/$app" "$CONFIG_ROOT/$app"; do
    for dir in "$base"/*/; do
      [[ -d "$dir" ]] || continue
      MARKER_DIRS+=("${dir%/}")
    done
  done
}
 
# Validate one app and, if everything checks out, append it to the plan.
plan_app() {
  local -r host="$1" theme="$2" app="$3"
  local source target
 
  if ! is_safe_name "$app"; then
    record_error "invalid app name: '$app'"
    return
  fi
 
  target="$XDG_CONFIG_DIR/$app"
  if ! is_replaceable_target "$target"; then
    record_error "$app: refusing to replace non-symlink at $target"
    return
  fi
 
  if ! source="$(find_theme_source "$host" "$app" "$theme")"; then
    if [[ "$STRICT" == true ]]; then
      record_error "$app: theme '$theme' not found under $CONFIG_ROOT"
    else
      log_warn "$app: theme '$theme' not found, skipping"
    fi
    return
  fi
 
  PLAN_SOURCES+=("$source")
  PLAN_TARGETS+=("$target")
  collect_marker_dirs "$host" "$app"
}
 
# Replace $target with a symlink to $source without any window in which the
# target is missing: create under a temporary name, then rename over it.
link_atomically() {
  local -r source="$1" target="$2"
  local -r staging="$target.$PROGRAM_NAME.$$"
 
  ln -s -- "$source" "$staging"
  mv -T -- "$staging" "$target"
}
 
apply_plan() {
  local index source target
  for index in "${!PLAN_SOURCES[@]}"; do
    source="${PLAN_SOURCES[$index]}"
    target="${PLAN_TARGETS[$index]}"
 
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[dry-run] $target -> $source"
    else
      link_atomically "$source" "$target"
      log_info "$target -> $source"
    fi
  done
}
 
# Write one marker atomically (temporary name, then rename). The temporary
# file is removed if anything fails.
write_marker_file() {
  local -r dir="$1" content="$2"
  local -r marker="$dir/$MARKER_NAME"
  local -r staging="$marker.$PROGRAM_NAME.$$"
 
  if ! {
    printf '%s\n' "$content" >"$staging" &&
      mv -T -- "$staging" "$marker"
  }; then
    rm -f -- "$staging"
    return 1
  fi
}
 
# Stamp every queued theme directory. The timestamp guarantees the content
# differs between consecutive switches, even to the same theme.
write_markers() {
  local -r host="$1" theme="$2"
  local content dir
 
  content="$(printf 'theme=%s\nhost=%s\nswitched=%s' \
    "$theme" "$host" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"
 
  for dir in "${MARKER_DIRS[@]}"; do
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[dry-run] would write marker in $dir"
      continue
    fi
    write_marker_file "$dir" "$content" || {
      log_error "could not write marker in $dir"
      return 1
    }
  done
}
 
# Run the optional post-switch command from the selection file.
# A string runs through bash -c; an array is executed directly as argv.
run_post_command() {
  local -r host="$1" theme="$2"
  local kind
  kind="$(jq -r '.command // empty | type' "$SELECTION_FILE")"
  [[ -n "$kind" ]] || return 0
 
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[dry-run] would run: $(jq -c '.command' "$SELECTION_FILE")"
    return 0
  fi
 
  export THEME_SWITCH_THEME="$theme"
  export THEME_SWITCH_HOST="$host"
 
  log_info "running post-switch command"
  case "$kind" in
    string)
      local command
      command="$(jq -r '.command' "$SELECTION_FILE")"
      "$BASH" -c "$command"
      ;;
    array)
      local -a argv
      mapfile -t argv < <(jq -r '.command[]' "$SELECTION_FILE")
      "${argv[@]}"
      ;;
    *)
      die "$EXIT_FAILURE" "unsupported command type: $kind"
      ;;
  esac
}
 
main() {
  parse_args "$@"
 
  if [[ "$LIST_ONLY" == true ]]; then
    list_selections
    return 0
  fi
 
  resolve_selection_file
  validate_selection_file
 
  local host theme
  host="$(resolve_host)"
  theme="$(jq -r '.theme' "$SELECTION_FILE")"
 
  is_safe_name "$host" || die "$EXIT_FAILURE" "invalid host name: '$host'"
  is_safe_name "$theme" || die "$EXIT_FAILURE" "invalid theme name: '$theme'"
  [[ -d "$CONFIG_ROOT" ]] || die "$EXIT_FAILURE" "config root not found: $CONFIG_ROOT"
 
  local -a apps
  mapfile -t apps < <(jq -r '.apps[]' "$SELECTION_FILE")
 
  local app
  for app in "${apps[@]}"; do
    plan_app "$host" "$theme" "$app"
  done
 
  ((PLAN_ERRORS == 0)) || die "$EXIT_FAILURE" "$PLAN_ERRORS error(s) found, no changes made"
 
  if ((${#PLAN_SOURCES[@]} == 0)); then
    log_info "nothing to link"
    return 0
  fi
 
  [[ "$DRY_RUN" == true ]] || mkdir -p -- "$XDG_CONFIG_DIR"
  apply_plan
 
  if [[ "$WRITE_MARKER" == true ]] && ! write_markers "$host" "$theme"; then
    die "$EXIT_FAILURE" "could not write change markers (links were already applied)"
  fi
 
  if ! run_post_command "$host" "$theme"; then
    die "$EXIT_FAILURE" "post-switch command failed (links were already applied)"
  fi
}
 
main "$@"
 

