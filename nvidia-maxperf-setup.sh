#!/bin/bash
# NVIDIA "Prefer maximum performance" for Linux/Wayland
# Sets up everything (again): core + memory locked to maximum,
# persistent across every boot and after every suspend.
# Run with: sudo bash nvidia-maxperf-setup.sh

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run with sudo: sudo bash $0"
  exit 1
fi

# Your maximum values (check with:
# nvidia-smi --query-gpu=clocks.max.graphics,clocks.max.memory --format=csv)
GPU_CLK=2100
MEM_CLK=7001

echo "==> Enabling the persistence daemon"
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

echo "==> Enabling and running the service"
systemctl daemon-reload
systemctl enable nvidia-clocks.service
systemctl restart nvidia-clocks.service

sleep 2
echo
echo "==> Current clocks (expected: core about 1860-1875 MHz, memory 7001 MHz):"
nvidia-smi --query-gpu=pstate,clocks.gr,clocks.mem --format=csv
