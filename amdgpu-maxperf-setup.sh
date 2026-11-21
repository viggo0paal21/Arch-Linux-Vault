#!/bin/bash
# AMD "maximum performance" for Linux/Wayland (amdgpu driver)
# Counterpart to the NVIDIA script: core + memory locked to the highest level,
# persistent across every boot and after every suspend.
# Run with: sudo bash amdgpu-maxperf-setup.sh
#
# Unlike NVIDIA, you don't have to enter any clock values here:
# The "high" mode automatically uses the highest level of your card.
#
# To undo:
#   sudo systemctl disable --now amdgpu-clocks.service
#   sudo rm /etc/systemd/system/amdgpu-clocks.service /usr/local/bin/amdgpu-maxperf.sh
#   then reboot (the card is back on "auto")

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run with sudo: sudo bash $0"
  exit 1
fi

# Find all AMD GPUs (vendor ID 0x1002, with a performance setting)
find_amd_cards() {
  for card in /sys/class/drm/card*; do
    [[ "$(basename "$card")" =~ ^card[0-9]+$ ]] || continue
    dev="$card/device"
    [ "$(cat "$dev/vendor" 2>/dev/null)" = "0x1002" ] || continue
    [ -e "$dev/power_dpm_force_performance_level" ] || continue
    echo "$card"
  done
}

echo "==> AMD-Grafikkarte suchen"
CARDS="$(find_amd_cards)"
if [ -z "$CARDS" ]; then
  echo "ERROR: No AMD GPU with the amdgpu driver found."
  exit 1
fi
for card in $CARDS; do
  name=""
  if command -v lspci >/dev/null 2>&1; then
    name="$(lspci -s "$(basename "$(readlink -f "$card/device")")" | cut -d: -f3- | sed 's/^ //')"
  fi
  echo "    $(basename "$card"): ${name:-AMD-Grafikkarte}"
done

echo "==> Skript /usr/local/bin/amdgpu-maxperf.sh schreiben"
cat > /usr/local/bin/amdgpu-maxperf.sh << 'EOF'
#!/bin/sh
# Sets all AMD GPUs to the highest clock level (core + memory).
# The card number (card0, card1 ...) is looked up again on every start,
# because it can change between reboots.
DRM=/sys/class/drm
found=0
for card in "$DRM"/card*; do
  case "${card##*/}" in
    card[0-9]|card[0-9][0-9]) ;;
    *) continue ;;
  esac
  dev="$card/device"
  [ "$(cat "$dev/vendor" 2>/dev/null)" = "0x1002" ] || continue
  [ -w "$dev/power_dpm_force_performance_level" ] || continue
  echo high > "$dev/power_dpm_force_performance_level" && found=1
done
if [ "$found" -ne 1 ]; then
  echo "No AMD GPU found" >&2
  exit 1
fi
EOF
chmod +x /usr/local/bin/amdgpu-maxperf.sh

echo "==> Service /etc/systemd/system/amdgpu-clocks.service schreiben"
cat > /etc/systemd/system/amdgpu-clocks.service << 'EOF'
[Unit]
Description=AMD maximale Leistung
After=suspend.target hibernate.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/amdgpu-maxperf.sh

[Install]
WantedBy=multi-user.target suspend.target hibernate.target
EOF

echo "==> Enabling and running the service"
systemctl daemon-reload
systemctl enable amdgpu-clocks.service
systemctl restart amdgpu-clocks.service

sleep 2
echo
echo "==> Current state (mode 'high', the highest level is marked with *):"
for card in $(find_amd_cards); do
  dev="$card/device"
  echo "$(basename "$card"): Modus = $(cat "$dev/power_dpm_force_performance_level")"
  if [ -r "$dev/pp_dpm_sclk" ]; then
    echo "  Chip:"
    sed 's/^/    /' "$dev/pp_dpm_sclk"
  fi
  if [ -r "$dev/pp_dpm_mclk" ]; then
    echo "  Speicher:"
    sed 's/^/    /' "$dev/pp_dpm_mclk"
  fi
done
