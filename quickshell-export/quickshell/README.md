# Quickshell OLED – Schwarz/Weiß

Komplettes Quickshell-Setup für Hyprland (Lua-Config, ≥ 0.55) und Quickshell 0.3.x.
Echtes Schwarz (#000000), weiße Schrift, leicht abgerundete Ecken, weiche Animationen.
Schrift wie die Waybar: Inter 15px Bold, Icons aus JetBrainsMono Nerd Font Propo.

## Was drin ist

| Teil | Was es macht |
|---|---|
| Leiste | Arch-Knopf (Launcher), Arbeitsflächen als Pillen, Fenstertitel, Uhr (Mitte), Tray mit eigenem S/W-Menü, CPU/RAM/Temp, Netz/Bluetooth/Lautstärke/Glocke, Power |
| Launcher | Unscharfe App-Suche, häufig genutzte Apps zuerst, `=` Rechner, `>` Befehl ausführen |
| Kontrollzentrum | Netzwerk, Bluetooth, Nicht stören, Wach bleiben, Nachtlicht, Mikro, Lautstärke-/Mikro-Regler, Mediaplayer, Benachrichtigungsverlauf |
| Dashboard | Große Uhr, Kalender, Systemmonitor (CPU, NVIDIA-GPU, RAM, Laufwerke, Netzwerk mit Verlaufsgraphen) |
| Benachrichtigungen | Eigener Daemon (ersetzt dunst/swaync), Popups gleiten von rechts rein, Laufzeitbalken, Aktionen |
| OSD | Lautstärke-Anzeige unten mittig |
| Power-Menü | Sperren, Bereitschaft, Abmelden, Neustart, Ausschalten (gefährliche mit Bestätigung) |
| Einstellungen | Alles live änderbar und gespeichert (Radius, Leiste, Schrift, Animationen, …) |
| Hintergrund | OLED-Schwarz oder eigenes Bild, optional abgerundete Bildschirmecken |

Jeder Monitor bekommt eine eigene Leiste.

## Installation

```bash
sudo pacman -S --needed quickshell inter-font ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols
# optional: hyprlock hyprsunset networkmanager bluez bluez-utils nvidia-utils
tar xzf quickshell-oled.tar.gz
cd quickshell-oled
./install.sh
```

Eine vorhandene `~/.config/quickshell` wird vorher als `quickshell.bak-DATUM` gesichert.

Danach den Inhalt von `hyprland-quickshell.lua` in deine `~/.config/hypr/hyprland.lua` übernehmen
und waybar, dunst und swaybg aus dem Autostart entfernen (nur ein Benachrichtigungs-Daemon kann laufen).

## Tastenkürzel (aus dem Snippet)

| Kürzel | Aktion |
|---|---|
| Super + Leertaste | Launcher |
| Super + A | Kontrollzentrum |
| Super + D | Dashboard |
| Super + Esc | Power-Menü |
| Super + , | Einstellungen |
| Super + N | Nicht stören an/aus |

Alles geht auch per Terminal: `qs ipc call <ziel> <funktion>`

```
launcher  toggle | open | close
control   toggle
dashboard toggle
power     toggle
settings  toggle
panels    close
audio     up | down | mute | micMute
notifs    dnd | clear
```

## Bedienung

- Leiste: Mausrad auf den Arbeitsflächen wechselt sie, Mausrad auf dem Status-Bereich ändert die Lautstärke, Mittelklick schaltet stumm.
- Tray: Linksklick öffnet die App, Rechtsklick das Menü, Mittelklick die Zweitaktion.
- Benachrichtigung: Klick = Standardaktion, Mittelklick = schließen, Maus drüber pausiert den Timer.
- Bluetooth-Kachel: Klick = an/aus, Rechtsklick = blueman-manager (oder bluetoothctl).
- Panels schließen mit Esc oder Klick daneben.

## Dateien

```
shell.qml              Einstieg
config/                Config (gespeicherte Einstellungen), Theme (Farben/Größen), Icons
services/              Audio, Netzwerk, Bluetooth, Systemmonitor, Benachrichtigungen, Medien, Apps
components/            Bausteine (Knöpfe, Regler, Schalter, Karten, Panel-Basis)
modules/               Leiste, Launcher, Kontrollzentrum, Dashboard, Popups, OSD, Power, Einstellungen
```

Einstellungen landen in `~/.local/state/quickshell/by-shell/oled-bw/settings.json`.
Farben ändern: `config/Theme.qml`. Quickshell lädt beim Speichern automatisch neu.

## Wenn etwas nicht geht

- `qs log` zeigt die Logs der laufenden Instanz.
- Quickshell zeigt bei QML-Fehlern nach dem Neuladen ein kleines Fehlerfenster mit Datei und Zeile.
- Keine Benachrichtigungen: läuft noch `dunst`/`swaync`/`mako`? → beenden.
- Hintergrund bleibt nicht schwarz: `swaybg`/`hyprpaper` läuft noch → beenden oder in den Einstellungen „OLED-Hintergrund“ aus.
- Icons sind Kästchen: Nerd Font fehlt → `ttf-jetbrains-mono-nerd`.
- Schrift sieht anders aus als die Waybar: `fc-list | grep -i inter` prüfen, sonst `inter-font` installieren.
