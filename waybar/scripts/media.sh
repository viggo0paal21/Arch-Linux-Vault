#!/usr/bin/env bash
# Media module for Waybar: "Media" when nothing plays, otherwise "Artist – Title".
# Classes: idle / playing / paused (for style.css)

SEP=$'\x1f'

emit() {
  local status artist title text
  IFS="$SEP" read -r status artist title <<<"$1"

  if [[ -z "$status" || "$status" == "Stopped" || -z "$title" ]]; then
    jq -cn '{text: "Media", class: "idle", tooltip: "Nothing is playing"}'
    return
  fi

  text="$title"
  [[ -n "$artist" ]] && text="$artist – $title"

  local cls="paused"
  [[ "$status" == "Playing" ]] && cls="playing"

  jq -cn --arg t "$text" --arg c "$cls" --arg s "$status" \
    '{text: $t, class: $c, tooltip: ($s + ": " + $t)}'
}

emit ""
playerctl --follow metadata \
  --format "{{status}}${SEP}{{artist}}${SEP}{{title}}" 2>/dev/null |
while IFS= read -r line; do
  emit "$line"
done
