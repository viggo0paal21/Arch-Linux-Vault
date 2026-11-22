# AI extras (experimental)

> **Not part of my rice.** Claude built these on 21.11.2026. The normal installer
> (`install.sh`) skips this folder. My own configs in this vault work without it and
> stay exactly as they are until you run `enable.sh`.

Two extras, turned on and off together:

- **Rice Control**: one small GTK 4 app for the look of the whole desktop: border width,
  border colors (active / inactive), rounding, background and text color, opacity, blur,
  gaps, UI font and terminal font. On the right a live preview at real size (1 px = 1 px)
  on the current wallpaper. "Apply" writes it into Hyprland, Waybar, GTK 3, GTK 4, Qt
  (Kvantum, qt6ct), swaync, rofi, kitty, the screen-share picker and fontconfig.
  Opens with a left click on the cat in Waybar.
- **Screen corners**: small black rounded corners under the bar, so the screen looks
  rounded like the windows. A tiny Quickshell config that reads Hyprland's rounding live,
  so it follows Rice Control's rounding slider. Switch in `~/.config/waybar/config.jsonc`:
  `"screen-corners": true` (all 4) / `"top"` (the 2 under the bar, default) / `false`.

## On / off

```
bash experimental/ai-extras/enable.sh     # on
bash experimental/ai-extras/disable.sh    # off: everything back exactly as before, no traces
```

Needs `python-gobject` and `gtk4` for Rice Control and `quickshell` for the corners
(`sudo pacman -S --needed python-gobject gtk4 quickshell`).

`enable.sh` first checks every config. If one doesn't look exactly like the version
in this vault, it stops and changes nothing.

`disable.sh` stops the corners, puts every original back byte for byte, deletes the theme
files, the corners, the app and its data, and restores the GTK fonts (gsettings) and the
Noctis mini player opacity. Changes you made to the look files while the extras were on are lost.

## How it works

- Rice Control's values live in `~/.config/rice-control/theme.json`.
- From them the app writes one file per program, which only it touches:
  `hypr/theme.lua`, `waybar/theme.css`, `gtk-3.0/theme.css`, `gtk-4.0/theme.css`,
  `swaync/theme.css`, `rofi/theme.rasi`, `kitty/theme.conf`, `fontconfig/conf.d/55-rice-fonts.conf`.
- `enable.sh` moves the look values out of my configs and adds one import line instead
  (`@import url("theme.css");`, `include theme.conf`, ...). In `waybar/config.jsonc` the cat's
  click opens Rice Control instead of rofi and the corners switch is added. In `hyprland.lua` an AI EXTRAS block gets
  added at the very end: `require("theme")` plus the start of the corners
  (`qs -n -p ~/.config/quickshell/corners`, `-n` = never twice).
- Programs that can't import files get single lines replaced: `hyprtoolkit.conf`,
  the Kvantum theme, `qt6ct.conf`, GTK `settings.ini`, Noctis. Plus the fonts in gsettings.
- Every apply reloads Hyprland, restarts Waybar, reloads swaync and kitty. GTK and Qt
  apps pick it up when they are opened next.
- Undo in the app: "Rückgängig" (Ctrl+Z), up to 30 steps.
- The corners are layer surfaces under the windows (`aboveWindows: false`) with
  `exclusiveZone: 0`, so they sit right under the space Waybar reserves, never cover
  an app and let every click through.

| File | What |
|---|---|
| `enable.sh` / `disable.sh` | on / off |
| `convert.py` | switches the configs (exact text, checks first, originals as `*.bak-rice-control`) |
| `rice-control` | starter, goes to `~/.local/bin/` |
| `rice/theme.py` | the values and what is derived from them |
| `rice/targets.py` | writes the files for every program, reloads them |
| `rice/preview.py` | the live preview (drawn with Gtk.Snapshot) |
| `rice/app.py` | the window |
| `corners/shell.qml` | the screen corners, goes to `~/.config/quickshell/corners/` |

## Known open points

- Never fully tried in my real session (built and tested in a copy of my configs).
- `size = { 1320, 900 }` in the window rule in `theme.lua`: not sure the syntax is right.
- Waybar reloaded with `SIGUSR2` dropped `style.css` once, so the app restarts Waybar completely.
