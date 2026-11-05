#!/usr/bin/env bash
# Clock for Waybar: text = time, tooltip (hover) = date + weather.
# Weather comes from wttr.in and is refreshed every 15 minutes.
# LOCATION empty = location detected by IP. Otherwise e.g. LOCATION="Berlin"
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

# Fetch the weather in the background: every 15 min, on error retry after 1 min
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
  weather="Loading weather …"
  [[ -s "$cache" ]] && weather=$(<"$cache")

  jq -cn --arg t "$now" --arg tip "$date"$'\n'"$weather" '{text: $t, tooltip: $tip}'

  # Sleep until just after the next full second (no skipping seconds)
  t=${EPOCHREALTIME//[!0-9]/}
  us=$(( 1020000 - 10#${t: -6} ))
  sleep "$(( us / 1000000 )).$(printf '%06d' $(( us % 1000000 )))"
done
