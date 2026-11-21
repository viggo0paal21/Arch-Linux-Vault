#!/usr/bin/env bash
# Toggles "hardened dynamic transparency" on/off – with a swaync notification.
#   ON  = transparent only with no windows or only floating windows,
#         black as soon as at least one tiled window is on the workspace
#   OFF = whatever toggle-transparency.sh is set to applies again
# While ON, toggle-transparency.sh is locked.
# Works via ~/.config/waybar/transparency-hardened.css, imported at the very
# end of style.css (after transparency.css, so it wins).

file="$HOME/.config/waybar/transparency-hardened.css"

if grep -q 'MODE: on' "$file" 2>/dev/null; then
  new=off
else
  new=on
fi

# Write in place (">") so Waybar notices the change
if [[ "$new" == on ]]; then
  cat > "$file" <<'CSS'
/* MODE: on – hardened dynamic transparency (managed by toggle-hardened.sh) */

/* Default + one tiled window: black */
window#waybar,
window#waybar.solo {
  background-color: @bg;
  transition: background-color 0.2s ease-in-out;
}

/* No windows, or only floating windows: transparent */
window#waybar.empty,
window#waybar.floating {
  background-color: rgba(0, 0, 0, 0);
  transition: background-color 0.25s ease-out;
}
CSS
  msg="Hardened dynamic transparency: <span color='#4ade80'><b>ON</b></span>"
else
  cat > "$file" <<'CSS'
/* MODE: off – hardened dynamic transparency (managed by toggle-hardened.sh) */
CSS
  msg="Hardened dynamic transparency: <span color='#f87171'><b>OFF</b></span>"
fi

notify-send -a "Waybar" -u low -t 2000 \
  -h string:x-canonical-private-synchronous:waybar-transparency \
  "Waybar" "$msg"
