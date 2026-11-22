#!/bin/bash
# Waybar fragt dieses Skript, welche Katze gezeigt wird.
# Läuft rofi gerade, bekommt das Modul die CSS-Klasse "happy".
if pgrep -x rofi >/dev/null; then
    echo '{"text": " ", "class": "happy", "tooltip": "meow"}'
else
    echo '{"text": " ", "tooltip": "meow"}'
fi
