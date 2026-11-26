#    ___           __
#   / _ \___  ____/ /__
#  / // / _ \/ __/  '_/
# /____/\___/\__/_/\_\
#

#!/bin/bash

style="style-dark.css"
config="$HOME/.config/gtk-3.0/settings.ini"

if [ -f "$config" ]; then
    prefer_dark_theme="$(grep 'gtk-application-prefer-dark-theme' "$config" | sed 's/.*\s*=\s*//')"
    if [ "$prefer_dark_theme" = "0" ]; then
        style="style-light.css"
    fi
fi

if [ ! -f "$HOME/.config/ml4w/settings/dock-disabled" ]; then
    nwg-dock-hyprland -i 40 -mb 6 -x -r -lp start -s "$style" -c "rofi -show drun"
else
    echo ":: Dock disabled"
fi
