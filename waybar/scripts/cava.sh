#!/usr/bin/env bash
# Cava-Visualizer für Waybar: 10 Balken aus ▁▂▃▄▅▆▇█

bars=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
dict="s/;//g;"
for i in "${!bars[@]}"; do
  dict+="s/$i/${bars[$i]}/g;"
done

conf="${XDG_RUNTIME_DIR:-/tmp}/waybar-cava.conf"
cat > "$conf" <<EOF
[general]
bars = 10
framerate = 30
sleep_timer = 0

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7

[smoothing]
noise_reduction = 77
EOF

# Alte Instanz (z. B. nach Waybar-Neustart) beenden
pkill -f "cava -p $conf" 2>/dev/null

cava -p "$conf" | sed -u "$dict"
