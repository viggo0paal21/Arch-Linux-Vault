#!/usr/bin/env bash
# Uhr für Waybar: Text = Uhrzeit, Tooltip (Hover) = Datum + Wetter.
# Wetter kommt von wttr.in und wird alle 15 Minuten aktualisiert.
# LOCATION leer = Standort automatisch per IP. Sonst z. B. LOCATION="Berlin"
LOCATION=""

export LC_TIME=C LC_NUMERIC=C
cache="${XDG_RUNTIME_DIR:-/tmp}/waybar-clock-weather.txt"

update_weather() {
  local data cond temp icon hour
  data=$(curl -sf --max-time 10 --get \
    --data-urlencode 'format=%C|%t' \
    "https://wttr.in/${LOCATION// /+}?m") || return 1
  [[ "$data" == *"|"* ]] || return 1

  IFS='|' read -r cond temp <<<"$data"
  temp="${temp#+}"
  temp="${temp/°C/° C}"

  hour=$(date +%-H)
  case "${cond,,}" in
    *thunder*)                        icon=$'\U000f0593' ;;
    *snow*|*sleet*|*blizzard*|*ice*)  icon=$'\U000f0598' ;;
    *rain*|*drizzle*|*shower*)        icon=$'\U000f0597' ;;
    *fog*|*mist*|*haze*)              icon=$'\U000f0591' ;;
    *partly*)                         icon=$'\U000f0595' ;;
    *clear*|*sunny*)
      if (( hour >= 20 || hour < 6 )); then icon=$'\U000f0594'; else icon=$'\U000f0599'; fi ;;
    *)                                icon=$'\U000f0163' ;;
  esac

  printf '%s  %s  ·  %s' "$icon" "$temp" "$cond" > "$cache"
}

# Wetter im Hintergrund holen: alle 15 Min, bei Fehler nach 1 Min nochmal
(
  while :; do
    if update_weather; then sleep 900; else sleep 60; fi
  done
) &
weather_pid=$!
trap 'kill "$weather_pid" 2>/dev/null' EXIT
trap 'exit 0' TERM INT HUP

while :; do
  printf -v now  '%(%I:%M:%S %p)T' -1
  printf -v date '%(%A, %B %d %Y)T' -1
  weather="Wetter lädt …"
  [[ -s "$cache" ]] && weather=$(<"$cache")

  jq -cn --arg t "$now" --arg tip "$date"$'\n'"$weather" '{text: $t, tooltip: $tip}'

  # Bis kurz nach der nächsten vollen Sekunde schlafen (kein Springen der Sekunden)
  t=${EPOCHREALTIME//[!0-9]/}
  us=$(( 1020000 - 10#${t: -6} ))
  sleep "$(( us / 1000000 )).$(printf '%06d' $(( us % 1000000 )))"
done
