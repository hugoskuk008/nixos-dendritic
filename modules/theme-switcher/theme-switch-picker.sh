#!/usr/bin/env bash
#claude on the beat

# theme-switch-picker: choose a theme from a rofi thumbnail grid and apply it
# with theme-switch.
#
# Each selection themes/NAME.json may have a preview image beside it
# (NAME.png, NAME.jpg, NAME.jpeg or NAME.webp). Selections without an image
# are shown as text-only tiles.

set -euo pipefail

readonly PROGRAM_NAME="theme-switch-picker"
readonly DENDRITIC_DIR="${THEME_SWITCH_DENDRITIC_DIR:-$HOME/nixos-dendritic}"
readonly SELECTIONS_DIR="${THEME_SWITCH_SELECTIONS_DIR:-$DENDRITIC_DIR/themes}"
readonly PREVIEW_EXTENSIONS=(png jpg jpeg webp)

# Rofi grid layout: large icons above centered labels, three tiles per row.
readonly ROFI_GRID_THEME='
  window   { width: 66em; }
  mainbox  { padding: 1em; }
  listview { columns: 3; lines: 2; layout: vertical; spacing: 1em; }
  element  { orientation: vertical; padding: 15px; }
  element-icon { size: 20em; horizontal-align: 0.5; }
  element-text { horizontal-align: 0.5; }
'


notify_error() {
  notify-send --urgency=critical "$PROGRAM_NAME" "$*"
}

# Print the preview image path for a selection, or nothing if none exists.
find_preview() {
  local -r name="$1"
  local extension candidate
  for extension in "${PREVIEW_EXTENSIONS[@]}"; do
    candidate="$SELECTIONS_DIR/$name.$extension"
    if [[ -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

# Emit rofi dmenu rows: "name" plus an icon hint when a preview exists.
# Rofi's row format is: text NUL "icon" US icon-path, newline-terminated.
emit_rows() {
  local name preview
  while IFS= read -r name; do
    if preview="$(find_preview "$name")"; then
      printf '%s\0icon\x1f%s\n' "$name" "$preview"
    else
      printf '%s\n' "$name"
    fi
  done
}

main() {
  local names
  if ! names="$(theme-switch --list 2>&1)" || [[ -z "$names" ]]; then
    notify_error "no theme selections found in $SELECTIONS_DIR"
    exit 1
  fi

  # Cancelling the picker (Escape) is not an error.
  local choice
  choice="$(
    emit_rows <<<"$names" |
      rofi -dmenu -i -show-icons -no-custom -format s \
        -p theme -theme-str "$ROFI_GRID_THEME"
  )" || exit 0
  [[ -n "$choice" ]] || exit 0

  local output
  if ! output="$(theme-switch "$choice" 2>&1)"; then
    notify_error "switching to '$choice' failed: $output"
    exit 1
  fi
}

main "$@"
