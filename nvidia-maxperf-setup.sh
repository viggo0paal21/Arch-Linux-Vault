#!/bin/bash
# NVIDIA "Maximale Leistung bevorzugen" für Linux/Wayland
# Setzt das komplette Setup (neu): Chip + Speicher fest auf Maximum,
# dauerhaft bei jedem Boot und nach jedem Standby.
# Ausführen mit: sudo bash nvidia-maxperf-setup.sh

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Bitte mit sudo ausführen: sudo bash $0"
  exit 1
fi

# Deine Maximalwerte (prüfen mit:
# nvidia-smi --query-gpu=clocks.max.graphics,clocks.max.memory --format=csv)
GPU_CLK=2100
MEM_CLK=7001

echo "==> Persistence-Daemon aktivieren"
systemctl enable --now nvidia-persistenced.service

echo "==> Skript /usr/local/bin/nvidia-maxperf.sh schreiben"
cat > /usr/local/bin/nvidia-maxperf.sh << EOF
#!/bin/sh
nvidia-smi -lgc ${GPU_CLK},${GPU_CLK}
nvidia-smi -lmc ${MEM_CLK},${MEM_CLK}
EOF
chmod +x /usr/local/bin/nvidia-maxperf.sh

echo "==> Service /etc/systemd/system/nvidia-clocks.service schreiben"
cat > /etc/systemd/system/nvidia-clocks.service << 'EOF'
[Unit]
Description=NVIDIA maximale Leistung
Wants=nvidia-persistenced.service
After=nvidia-persistenced.service suspend.target hibernate.target nvidia-resume.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nvidia-maxperf.sh

[Install]
WantedBy=multi-user.target suspend.target hibernate.target
EOF

echo "==> Service aktivieren und ausführen"
systemctl daemon-reload
systemctl enable nvidia-clocks.service
systemctl restart nvidia-clocks.service

sleep 2
echo
echo "==> Aktuelle Takte (Chip ca. 1860-1875 MHz, Speicher 7001 MHz erwartet):"
nvidia-smi --query-gpu=pstate,clocks.gr,clocks.mem --format=csv
