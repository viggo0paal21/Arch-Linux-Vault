#!/usr/bin/env bash
# EXPERIMENTAL, AI-made: turns Rice Control on.
# One app for the look of the whole rice (border, colors, rounding, opacity, blur,
# gaps, fonts) with a live preview. Opens with a left click on the cat in Waybar.
# Turn it off again with disable.sh: everything goes back exactly as it was.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$HOME/.local/share/rice-control"
BIN="$HOME/.local/bin/rice-control"
DATA="$HOME/.config/rice-control"
NOCTIS="$HOME/.config/Noctis/settings.json"

if [[ -d "$DATA" ]]; then
    echo "Rice Control ist schon an. Ausschalten: $HERE/disable.sh"
    exit 0
fi
if ! python3 -c 'import gi; gi.require_version("Gtk", "4.0")' 2>/dev/null; then
    echo "Rice Control braucht GTK 4 für Python:  sudo pacman -S --needed python-gobject gtk4" >&2
    exit 1
fi

# 1. check first: if a config looks different than expected, stop before touching anything
python3 "$HERE/convert.py" "$HOME" check

# 2. remember the two things outside the config files that Rice Control changes
mkdir -p "$DATA/before"
if command -v dconf >/dev/null; then
    for key in font-name document-font-name monospace-font-name; do
        printf '%s\t%s\n' "$key" "$(dconf read "/org/gnome/desktop/interface/$key")"
    done > "$DATA/before/dconf.txt"
fi
grep -oE '"miniPlayerBackgroundOpacity"[[:space:]]*:[[:space:]]*[-0-9.eE+]+' "$NOCTIS" 2>/dev/null \
    | grep -oE '[-0-9.eE+]+$' > "$DATA/before/noctis-opacity" || true

# 3. the app
install -d "$APP/rice"
install -m 644 "$HERE"/rice/*.py "$APP/rice/"
install -D -m 755 "$HERE/rice-control" "$BIN"

# 4. look files -> import theme files (originals: *.bak-rice-control)
python3 "$HERE/convert.py" "$HOME" on

# 5. theme files with the default values (= the look you have now), then the
#    require line in hyprland.lua (only now, theme.lua exists)
"$BIN" apply --no-reload >/dev/null || true
python3 "$HERE/convert.py" "$HOME" hypr-on

# 6. reload what is running
[[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && hyprctl reload >/dev/null
if pgrep -x waybar >/dev/null; then
    pkill -x waybar
    while pgrep -x waybar >/dev/null; do sleep 0.1; done
    setsid -f waybar >/dev/null 2>&1
fi
pgrep -x swaync >/dev/null && swaync-client --reload-css >/dev/null 2>&1
pgrep -x kitty >/dev/null && pkill -USR1 -x kitty

echo "Rice Control ist an: Linksklick auf die Katze. Aus: $HERE/disable.sh"
