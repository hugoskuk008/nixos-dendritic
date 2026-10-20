#!/usr/bin/env bash
set -u

export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH"

# These commands need to run inside your graphical session.
if command -v waybar >/dev/null 2>&1; then
 pkill waybar; waybar >/dev/null 2>&1 &
fi

if command -v waypaper >/dev/null 2>&1; then
  waypaper --restore || true
fi

