#!/bin/bash
# AMD "Maximale Leistung" für Linux/Wayland (amdgpu-Treiber)
# Gegenstück zum NVIDIA-Skript: Chip + Speicher fest auf höchster Stufe,
# dauerhaft bei jedem Boot und nach jedem Standby.
# Ausführen mit: sudo bash amdgpu-maxperf-setup.sh
#
# Anders als bei NVIDIA musst du hier keine Taktwerte eintragen:
# Der Modus "high" nimmt automatisch die höchste Stufe deiner Karte.
#
# Rückgängig machen:
#   sudo systemctl disable --now amdgpu-clocks.service
#   sudo rm /etc/systemd/system/amdgpu-clocks.service /usr/local/bin/amdgpu-maxperf.sh
#   danach neu starten (dann steht die Karte wieder auf "auto")

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Bitte mit sudo ausführen: sudo bash $0"
  exit 1
fi

# Alle AMD-Grafikkarten finden (Hersteller-ID 0x1002, mit Leistungs-Einstellung)
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
  echo "FEHLER: Keine AMD-Grafikkarte mit amdgpu-Treiber gefunden."
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
# Setzt alle AMD-Grafikkarten auf die höchste Takt-Stufe (Chip + Speicher).
# Die Kartennummer (card0, card1 ...) wird bei jedem Start neu gesucht,
# weil sie sich zwischen Neustarts ändern kann.
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
  echo "Keine AMD-Grafikkarte gefunden" >&2
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

echo "==> Service aktivieren und ausführen"
systemctl daemon-reload
systemctl enable amdgpu-clocks.service
systemctl restart amdgpu-clocks.service

sleep 2
echo
echo "==> Aktueller Zustand (Modus 'high', jeweils die höchste Stufe mit * markiert):"
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
