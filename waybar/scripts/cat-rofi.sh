#!/bin/bash
# Klick auf die Katze: rofi öffnen, Katze happy machen,
# und wenn rofi wieder zu ist, Katze zurücksetzen.
rofi -show drun &
pkill -RTMIN+8 waybar
wait
pkill -RTMIN+8 waybar
