#!/usr/bin/env bash
# Wetter für Waybar über wttr.in → Icon + "13° C"
# LOCATION leer = Standort automatisch per IP. Sonst z. B. LOCATION="Berlin"
LOCATION=""

data=$(curl -sf --max-time 10 --get \
  --data-urlencode 'format=%C|%t|%f|%h|%w' \
  "https://wttr.in/${LOCATION// /+}?m")

if [[ -z "$data" || "$data" != *"|"* ]]; then
  jq -cn '{text: " --° C", tooltip: "Wetter nicht erreichbar", class: "error"}'
  exit 0
fi

IFS='|' read -r cond temp feels hum wind <<<"$data"

temp="${temp#+}"
temp="${temp/°C/° C}"
feels="${feels#+}"

hour=$(date +%-H)
night=0
(( hour >= 20 || hour < 6 )) && night=1

case "${cond,,}" in
  *thunder*)                          icon=$'\U000f0593' ;;  # Gewitter
  *snow*|*sleet*|*blizzard*|*ice*)    icon=$'\U000f0598' ;;  # Schnee
  *rain*|*drizzle*|*shower*)          icon=$'\U000f0597' ;;  # Regen
  *fog*|*mist*|*haze*)                icon=$'\U000f0591' ;;  # Nebel
  *partly*)                           icon=$'\U000f0595' ;;  # teils bewölkt
  *clear*|*sunny*)
    if (( night )); then icon=$'\U000f0594'; else icon=$'\U000f0599'; fi ;;
  *)                                  icon=$'\U000f0163' ;;  # Wolke (Outline, wie im Bild)
esac

jq -cn \
  --arg text "$icon $temp" \
  --arg tip "$cond"$'\n'"Gefühlt: $feels"$'\n'"Luftfeuchte: $hum"$'\n'"Wind: $wind" \
  '{text: $text, tooltip: $tip}'
