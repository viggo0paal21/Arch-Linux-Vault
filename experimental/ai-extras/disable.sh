#!/usr/bin/env bash
# EXPERIMENTAL, AI-made: turns the AI extras (Rice Control + screen corners) off
# and removes every trace of them.
# Afterwards your configs are exactly as before enable.sh (byte for byte).
# Changes you made to the look files while Rice Control was on are lost.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$HOME/.local/share/rice-control"
BIN="$HOME/.local/bin/rice-control"
DATA="$HOME/.config/rice-control"
NOCTIS="$HOME/.config/Noctis/settings.json"

if [[ ! -d "$DATA" ]]; then
    echo "Die AI-Extras sind nicht an."
    exit 0
fi

# 1. the AI EXTRAS block out of hyprland.lua first, so Hyprland never looks for a
#    missing theme.lua; then stop the screen corners
python3 "$HERE/convert.py" "$HOME" hypr-off
pkill -f "$HOME/.config/quickshell/corners" || true

# 2. every original back, theme files and corners away
python3 "$HERE/convert.py" "$HOME" off

# 3. fonts in gsettings (empty = was never set) and the Noctis opacity as before
if [[ -f "$DATA/before/dconf.txt" ]] && command -v dconf >/dev/null; then
    while IFS=$'\t' read -r key value; do
        if [[ -z "$value" ]]; then
            dconf reset "/org/gnome/desktop/interface/$key"
        else
            dconf write "/org/gnome/desktop/interface/$key" "$value"
        fi
    done < "$DATA/before/dconf.txt"
fi
if [[ -s "$DATA/before/noctis-opacity" && -f "$NOCTIS" ]]; then
    value="$(cat "$DATA/before/noctis-opacity")"
    sed -i -E "s/(\"miniPlayerBackgroundOpacity\"[[:space:]]*:[[:space:]]*)[-0-9.eE+]+/\1$value/" "$NOCTIS"
fi

# 4. the app and its data
rm -rf "$APP" "$DATA"
rm -f "$BIN"

# 5. reload what is running
[[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && hyprctl reload >/dev/null
if pgrep -x waybar >/dev/null; then
    pkill -x waybar
    while pgrep -x waybar >/dev/null; do sleep 0.1; done
    setsid -f waybar >/dev/null 2>&1
fi
pgrep -x swaync >/dev/null && swaync-client --reload-css >/dev/null 2>&1
pgrep -x kitty >/dev/null && pkill -USR1 -x kitty

echo "Die AI-Extras sind aus, alles wie vorher."
