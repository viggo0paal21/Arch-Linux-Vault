#!/usr/bin/env bash
# Cava visualizer for Waybar: 10 bars made of ▁▂▃▄▅▆▇█

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

# Stop the old instance (e.g. after a Waybar restart)
pkill -f "cava -p $conf" 2>/dev/null

cava -p "$conf" | sed -u "$dict"
