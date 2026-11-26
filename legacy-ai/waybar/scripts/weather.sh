#!/usr/bin/env bash
# Weather for Waybar via wttr.in → icon + "13° C"
# LOCATION empty = location detected by IP. Otherwise e.g. LOCATION="Berlin"
LOCATION=""

data=$(curl -sf --max-time 10 --get \
  --data-urlencode 'format=%C|%t|%f|%h|%w' \
  "https://wttr.in/${LOCATION// /+}?m")

if [[ -z "$data" || "$data" != *"|"* ]]; then
  jq -cn '{text: " --° C", tooltip: "Weather unavailable", class: "error"}'
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
  *thunder*)                          icon=$'\U000f0593' ;;  # thunderstorm
  *snow*|*sleet*|*blizzard*|*ice*)    icon=$'\U000f0598' ;;  # snow
  *rain*|*drizzle*|*shower*)          icon=$'\U000f0597' ;;  # rain
  *fog*|*mist*|*haze*)                icon=$'\U000f0591' ;;  # fog
  *partly*)                           icon=$'\U000f0595' ;;  # partly cloudy
  *clear*|*sunny*)
    if (( night )); then icon=$'\U000f0594'; else icon=$'\U000f0599'; fi ;;
  *)                                  icon=$'\U000f0163' ;;  # cloud (outline)
esac

jq -cn \
  --arg text "$icon $temp" \
  --arg tip "$cond"$'\n'"Feels like: $feels"$'\n'"Humidity: $hum"$'\n'"Wind: $wind" \
  '{text: $text, tooltip: $tip}'
