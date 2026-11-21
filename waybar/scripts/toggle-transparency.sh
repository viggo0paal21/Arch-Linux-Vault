#!/usr/bin/env bash
# Toggles Waybar's dynamic transparency on/off – with a swaync notification.
#   ON  = black with exactly one window, transparent otherwise (with fade)
#   OFF = bar is always black
# Locked while hardened mode (toggle-hardened.sh) is on.
# Works via ~/.config/waybar/transparency.css, which is imported at the
# end of style.css. Waybar reloads the style on its own when it changes.

file="$HOME/.config/waybar/transparency.css"
hardened="$HOME/.config/waybar/transparency-hardened.css"

notify() {
  notify-send -a "Waybar" -u low -t 2000 \
    -h string:x-canonical-private-synchronous:waybar-transparency \
    "Waybar" "$1"
}

# Hardened mode has priority – do nothing while it is on
if grep -q 'MODE: on' "$hardened" 2>/dev/null; then
  notify "Dynamic transparency: <span color='#9ca3af'><b>LOCKED</b></span> – hardened mode is on"
  exit 0
fi

if grep -q 'MODE: off' "$file" 2>/dev/null; then
  new=on
else
  new=off
fi

# Important: write in place (">") so Waybar notices the change
if [[ "$new" == on ]]; then
  cat > "$file" <<'CSS'
/* MODE: on – dynamic transparency (managed by toggle-transparency.sh) */
CSS
  notify "Dynamic transparency: <span color='#4ade80'><b>ON</b></span>"
else
  cat > "$file" <<'CSS'
/* MODE: off – bar always black (managed by toggle-transparency.sh) */
window#waybar,
window#waybar.solo {
  background-color: @bg;
}
CSS
  notify "Dynamic transparency: <span color='#f87171'><b>OFF</b></span>"
fi
