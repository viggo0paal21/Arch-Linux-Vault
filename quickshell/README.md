# Quickshell OLED – Black/White

Complete Quickshell setup for Hyprland (Lua config, ≥ 0.55) and Quickshell 0.3.x.
True black (#000000), white text, slightly rounded corners, smooth animations.
Font like the Waybar: Inter 15px bold, icons from JetBrainsMono Nerd Font Propo.

## What's included

| Part | What it does |
|---|---|
| Bar | Arch button (launcher), workspaces as pills, window title, tray with its own B/W menu, CPU/RAM/temp + clock, network/Bluetooth/volume/bell, power. Optional floating bar that docks with a single window (with an optional subpixel glide), optional shell glass (looks like kitty's glass: either the bar blurs the wallpaper itself, or Hyprland blurs the background behind it), Arch or Tux launcher icon with adjustable size, optional group boxes with a color picker |
| Launcher | Fuzzy app search, frequently used apps first, `=` calculator, `>` run a command |
| Control center | Network, Bluetooth, do not disturb, stay awake, night light, mic, volume/mic sliders, media player, notification history |
| Dashboard | Big clock, calendar, system monitor (CPU, NVIDIA GPU, RAM, drives, network with history graphs) |
| Notifications | Own daemon (replaces dunst/swaync), popups slide in from the right, timeout bar, actions |
| OSD | Volume indicator bottom center |
| Power menu | Lock, suspend, log out, reboot, shut down (dangerous ones need a confirmation) |
| Settings | Everything changeable live and saved (radius, bar, font, transparency, animations, …) |
| Background | OLED black or your own image, optional rounded screen corners |

Every monitor gets its own bar.

## Installation

```bash
sudo pacman -S --needed quickshell inter-font ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols
# optional: hyprlock hyprsunset networkmanager bluez bluez-utils nvidia-utils
cp -r quickshell ~/.config/quickshell
```

Back up an existing `~/.config/quickshell` first. Full steps (start script, settings, NVIDIA): [Quickshell Guide](../Quickshell%20Guide.md).

For the shell glass (Settings → Bar), build the small wallpaper helper once (needs `rust`). Without it the bar falls back
to decoding the wallpaper itself, which looks very slightly different from awww:

```bash
cargo build --release --locked --manifest-path ~/.config/quickshell/tools/glasswall/Cargo.toml \
    --target-dir ~/.cache/quickshell/glasswall-target
install -Dm755 ~/.cache/quickshell/glasswall-target/release/qs-glasswall ~/.local/bin/qs-glasswall
```

Then copy the contents of `hyprland-quickshell.lua` into your `~/.config/hypr/hyprland.lua`
and remove waybar, dunst and swaybg from the autostart (only one notification daemon can run).

## Keyboard shortcuts (from the snippet)

| Shortcut | Action |
|---|---|
| Super + Space | Launcher |
| Super + A | Control center |
| Super + D | Dashboard |
| Super + Esc | Power menu |
| Super + , | Settings |
| Super + N | Do not disturb on/off |

Everything also works from the terminal: `qs ipc call <target> <function>`

```
launcher  toggle | open | close
control   toggle
dashboard toggle
power     toggle
settings  toggle
panels    close
audio     up | down | mute | micMute
notifs    dnd | clear
fps       toggle
```

## Usage

- Bar: scrolling on the workspaces switches them, scrolling on the status area changes the volume, middle click mutes.
- Tray: left click opens the app, right click the menu, middle click the secondary action.
- Notification: click = default action, middle click = close, hovering pauses the timer.
- Bluetooth tile: click = on/off, right click = blueman-manager (or bluetoothctl).
- Close panels with Esc or by clicking outside.

## Files

```
shell.qml              Entry point
config/                Config (saved settings), Theme (colors/sizes), Icons
services/              Audio, network, Bluetooth, system monitor, notifications, media, apps
components/            Building blocks (buttons, sliders, switches, cards, panel base, color picker)
modules/               Bar, launcher, control center, dashboard, popups, OSD, power, settings
shaders/               Hyprland's blur shaders for the shell glass (.frag source + compiled .frag.qsb)
tools/glasswall/       qs-glasswall: the wallpaper exactly as awww shows it, for the shell glass (Rust)
```

Settings are stored in `~/.local/state/quickshell/by-shell/oled-bw/settings.json`.
Change colors: `config/Theme.qml`. Quickshell reloads automatically when you save.

## If something doesn't work

- `qs log` shows the logs of the running instance.
- On QML errors Quickshell shows a small error window with file and line after reloading.
- No notifications: is `dunst`/`swaync`/`mako` still running? → stop it.
- Background doesn't stay black: `swaybg`/`hyprpaper` is still running → stop it, or turn off "OLED background" in the settings.
- Icons are boxes: Nerd Font missing → `ttf-jetbrains-mono-nerd`.
- Font looks different from the Waybar: check `fc-list | grep -i inter`, otherwise install `inter-font`.
- Stutter, jitter or short freezes: see the [Quickshell Stutter Guide](../Quickshell%20Stutter%20Guide.md).
