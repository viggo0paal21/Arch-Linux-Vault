#!/usr/bin/env bash
# Media-Modul für Waybar: "Media" wenn nichts läuft, sonst "Künstler – Titel".
# Klassen: idle / playing / paused (für style.css)

SEP=$'\x1f'

emit() {
  local status artist title text
  IFS="$SEP" read -r status artist title <<<"$1"

  if [[ -z "$status" || "$status" == "Stopped" || -z "$title" ]]; then
    jq -cn '{text: "Media", class: "idle", tooltip: "Nichts spielt gerade"}'
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
