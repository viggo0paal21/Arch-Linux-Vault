# Quickshell OLED – Black/White

Complete Quickshell setup for Hyprland (Lua config, ≥ 0.55) and Quickshell 0.3.x.
True black (#000000), white text, slightly rounded corners, smooth animations.
Font like the Waybar: Inter 15px bold, icons from JetBrainsMono Nerd Font Propo.

## What's included

| Part | What it does |
|---|---|
| Bar | Arch button (launcher), workspaces as pills, window title, tray with its own B/W menu, CPU/RAM/temp + clock, network/Bluetooth/volume/bell, power. Optional floating bar that docks with a single window (with an optional subpixel glide), optional shell glass (looks like kitty's glass: either the bar blurs the wallpaper itself, or Hyprland blurs the background behind it), Arch or Tux launcher icon with adjustable size, optional group boxes with a color picker |
| Launcher | Fuzzy app search, frequently used apps first, `=` calculator, `>` run a command. Opens in the middle of the screen or slides out of the launcher logo (Settings → Bar → Launcher position) |
| Control center | Profile picture and name in the header (click = profile settings), Wi-Fi and Bluetooth (each with its own page that slides in: nearby networks with password entry, paired and nearby devices with battery), do not disturb, night light, mic, volume/mic sliders with per-app volume (expander below the volume slider, only apps that play audio), media player, notification history. Shows "No internet" only when the shell's own check fails too (NetworkManager's check often fails behind a VPN like NordVPN) |
| Dashboard | Big clock, calendar, system monitor (CPU, NVIDIA GPU, RAM, drives, network with history graphs) |
| Notifications | Own daemon (replaces dunst/swaync), popups slide in from the right, timeout bar, actions |
| OSD | Volume indicator bottom center |
| Power menu | Lock, suspend, log out, reboot, shut down (dangerous ones need a confirmation) |
| Settings | Everything changeable live and saved. Four top tabs: **Quickshell** (appearance, bar, notifications & OSD, animations, performance, commands), **Hyprland** (rounding, shadows, blur, direct scanout, Dynamic Hyprland integration, applied live on top of hyprland.lua), **Apps** (per-app opacity with black & white app icons, fastfetch in kitty), **System** (profile, wallpaper, gaming, system font for every app; `qs-font-revert` undoes only that) |
| Profile (Settings → System) | The account picture shared with KDE Plasma, SDDM and hyprlock (AccountsService), with a picker and a crop dialog (drag, zoom); setting it changes it system-wide, "Restore original" brings the old one back. Optional own display name for the shell and the lock screen |
| Gaming (Settings → System) | Variable refresh rate (Hyprland `misc:vrr`, live) and MangoHud: global or per-game config from a dropdown, HUD at start, position, shown values, FPS limit, vsync |
| Wallpaper (Settings → System) | Pick the wallpaper from previews: the current one large on top, all images of the waypaper folder as tiles (newest first or by name, search, random). A click sets it via `waypaper --wallpaper` (its awww backend, fill mode and transition). Thumbnails are made once with `vipsthumbnail` (ImageMagick as fallback) into `~/.cache/quickshell/wallthumbs` |
| Wallpaper colors | Optional (Settings → Quickshell → Appearance): everything that is highlighted in white (buttons, switches, sliders, active workspace, graphs, selection) takes the color of the wallpaper, like Caelestia. Styles Tonal / Vibrant / Exact. Detected automatically on every wallpaper change (awww cache file, `awww query`, waypaper). Black-and-white wallpapers stay black and white, text and surfaces always stay black and white |
| Background | Optional rounded screen corners (the wallpaper itself comes from waypaper / awww) |

Every monitor gets its own bar.

> Prefer the old look (cards with borders, round buttons, sliders with a knob)? It is kept as an alternative in
> [`../quickshell-old-design`](../quickshell-old-design).

## Installation

```bash
sudo pacman -S --needed quickshell inter-font ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols
# optional: hyprlock hyprsunset networkmanager bluez bluez-utils nvidia-utils mangohud accountsservice
cp -r quickshell ~/.config/quickshell
```

Back up an existing `~/.config/quickshell` first. Full steps (start script, settings, NVIDIA): [Quickshell Guide](../Quickshell%20Guide.md).

For the shell glass (Settings → Quickshell → Bar → Glass blur → Own, experimental), build the small wallpaper helper once (needs `rust`). Without it the bar falls back
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
- Wi-Fi / Bluetooth tile: click = its own page, right click = on/off. On the page: click a network to connect (unknown ones ask for the password right there), click a device to connect/disconnect or pair it; hover a row for Disconnect / Forget. Searching only runs while the page is open. "Network settings" / "Bluetooth settings" at the bottom open nm-connection-editor / blueman-manager (or nmtui / bluetoothctl).
- Close panels with Esc or by clicking outside.

## Files

```
shell.qml              Entry point
config/                Config (saved settings), Theme (colors/sizes), Icons
services/              Audio, network, Bluetooth, system monitor, notifications, media, apps, profile, MangoHud
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
- Icons are boxes: Nerd Font missing → `ttf-jetbrains-mono-nerd`.
- Font looks different from the Waybar: check `fc-list | grep -i inter`, otherwise install `inter-font`.
- Stutter, jitter or short freezes: see the [Quickshell Stutter Guide](../Quickshell%20Stutter%20Guide.md).
