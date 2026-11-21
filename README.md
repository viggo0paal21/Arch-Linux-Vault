# Arch-Linux-Vault

Everything I need to keep my Arch Linux system running and to rebuild it from scratch:
my personal `~/.config` files (Hyprland rice), maintenance and performance guides, and helper scripts.

> **State: 21.11.2026.** Since 19.11.2026 my rice is **self-built** (written and understood by me, line by line):
> Hyprland (Lua config) + Waybar + rofi + swaync + kitty, black and white, slightly transparent with blur.
> The old AI-made setup (Quickshell shell "oled-bw", zsh with fastfetch in kitty) is still in this repo,
> but **no longer in use**. Everything from it is kept, nothing was deleted, see [What changed](#what-changed-since-the-old-vault).
> The gaming / latency optimizations from the old setup are **still in use** (now in [`hypr/performance.lua`](hypr/performance.lua)).

## Install everything with one command

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/viggo0paal21/Arch-Linux-Vault/main/install.sh)
```

That's all. The script downloads this vault to `~/config-backup` by itself (installs `git` first if needed; if the folder already exists it is updated with `git pull`) and installs from there. Run it as your normal user, not with `sudo`, it asks for the password itself.

If you already have the vault on the PC: `~/config-backup/install.sh`

What [`install.sh`](install.sh) does:

1. **Programs:** full system upgrade (`pacman -Syu`), then every program the configs need with `pacman -S --needed` (already installed ones are skipped). Anything pacman doesn't know is installed from the AUR with yay; if yay is missing, it installs yay first. `lib32-*` packages need the [multilib] repo, see [Install the programs](#install-the-programs).
2. **Backup:** every file on the PC that is about to be replaced and differs from the vault is copied to `~/.config-backup-before-install-<date>` first.
3. **Files:** every config folder → `~/.config/<folder>`, `starship.toml` → `~/.config/`, `home/` → `~` (scripts in `~/.local/bin` get made executable), `etc/sudoers.d/pwfeedback` → `/etc/sudoers.d/` (checked with `visudo` first). Not copied: guides and README, `quickshell-old-design/` (alternative design), `oled-bw/` (duplicate) and the old D-Bus override (it would block swaync).
4. **Extras:** bluetooth on at boot, Nautilus as default file manager, blueman tray icon off, font cache rebuilt.

Options: `./install.sh --yes` (no question at the start), `./install.sh --no-packages` (only copy the files). Then log out and back in.

> 📖 **[Arch Linux System Maintenance Guide](Arch%20Linux%20System%20Maintenance%20Guide.md)**: safe updates, recovery playbook and all commands.

> ⚡ **[Performance Optimization](Performance%20Optimization.md)**: system tweaks for gaming performance and latency: NTSync, split lock, CPU and GPU max performance (incl. the NVIDIA/AMD scripts), shader cache, gaming scheduler.

> 🎮 **[Low Latency Gaming](Low%20Latency%20Gaming.md)**: best setup with and without tearing, and how tearing works on Wayland/Hyprland.

> 🖤 **[Quickshell Guide](Quickshell%20Guide.md)** *(old shell, not in use anymore)*: my black-and-white Quickshell shell, smooth 170 Hz on NVIDIA (Vulkan, no MangoHud), FPS counter, using the fix with other shells.

> 🩺 **[Quickshell Stutter Guide](Quickshell%20Stutter%20Guide.md)** *(old shell, still useful knowledge)*: how Quickshell stutters and freezes happen, how to measure them and how I fixed each one (NVIDIA/Vulkan, pixel jitter, snapping animations, 60–130 ms freezes caused by zsh history in `~`).

## My current rice (self-built)

| Part | Program | Files |
|---|---|---|
| Window manager | Hyprland, Lua config | [`hypr/hyprland.lua`](hypr/hyprland.lua) (my own), plus [`hypr/system.lua`](hypr/system.lua) and [`hypr/performance.lua`](hypr/performance.lua) (pulled in with `require`) |
| Bar | Waybar: cat `(=^.^=)` with "meow" tooltip, workspace dots, window title, clock with date, tray, Bluetooth with number of devices, network, CPU, RAM, volume (Nerd Font icons) | [`waybar/config.jsonc`](waybar/config.jsonc), [`waybar/style.css`](waybar/style.css) |
| Launcher | rofi (`Super + R`) | [`rofi/config.rasi`](rofi/config.rasi) |
| Notifications | swaync, default look | [`swaync/`](swaync) |
| Terminal | kitty, 75 % opacity | [`kitty/kitty.conf`](kitty/kitty.conf) |
| System info | fastfetch, small Arch logo | [`fastfetch/config.jsonc`](fastfetch/config.jsonc) |
| Lock screen | hyprlock, minimal | [`hypr/hyprlock.conf`](hypr/hyprlock.conf) |
| File manager | Nautilus (`Super + E`) | uses [`gtk-4.0/`](gtk-4.0) |
| GTK 3 / GTK 4 apps | own CSS: true black, white text, 75 % glass | [`gtk-3.0/gtk.css`](gtk-3.0/gtk.css), [`gtk-4.0/gtk.css`](gtk-4.0/gtk.css) |
| Qt apps | qt6ct (style `kvantum`) + my Kvantum theme **MonoGlass** | [`qt6ct/qt6ct.conf`](qt6ct/qt6ct.conf), [`Kvantum/MonoGlass/`](Kvantum/MonoGlass), [`Kvantum/kvantum.kvconfig`](Kvantum/kvantum.kvconfig) |
| Screen-share picker | hyprtoolkit (comes with xdg-desktop-portal-hyprland) | [`hypr/hyprtoolkit.conf`](hypr/hyprtoolkit.conf) |
| Font | Noto Sans everywhere (kitty: its own default), JetBrainsMono Nerd Font for icons | [`fontconfig/`](fontconfig), `settings.ini` in [`gtk-3.0/`](gtk-3.0) and [`gtk-4.0/`](gtk-4.0) |
| Wallpaper | waypaper + awww | [`waypaper/config.ini`](waypaper/config.ini) |
| Music visualizer | cava | [`cava/config`](cava/config) |
| Screen corners (optional) | small Quickshell config, switch `"screen-corners"` in `waybar/config.jsonc` (currently `false`) | [`quickshell/corners/shell.qml`](quickshell/corners/shell.qml) |

### How the look works

- **Colors:** true black `#000000` and white `#ffffff`, grey `#5a5a5a` for inactive things.
- **Rounding:** `rounding = 10` in `hyprland.lua`, the same 10 px in rofi, GTK, menus, hyprtoolkit. Smart gaps (1 tiled window = no gaps, no border, no rounding) are at the end of `hyprland.lua`.
- **Transparency (75 %) + blur:** the background is 75 % black, the text stays fully white. Hyprland's blur (`decoration.blur`) blurs everything behind it.
  - kitty: `background_opacity 0.75`
  - rofi: `bg-glass: #000000bf` (`bf` = 75 %), blur through a layer rule in `hyprland.lua`
  - Waybar: `rgba(0, 0, 0, 0.75)`, layer rule with `blur_popups` for the tray menus; turns solid black with a 250 ms fade when exactly one tiled window is open (class `.solo`), except when that window is kitty (`.solo.kitty`)
  - GTK 3: `window.background` 75 %, everything inside transparent (otherwise layers stack up), own selection color, rounded right-click menus
  - GTK 4 / libadwaita: CSS variables in `:root` (`--window-bg-color`, `--view-bg-color`, sidebar/headerbar transparent)
  - Qt: Kvantum theme MonoGlass (`reduce_window_opacity`). Kvantum only makes the window background transparent, lists stay opaque; OBS uses its own theme and ignores Kvantum
  - hyprtoolkit (screen-share picker): `background = 0xBF000000` (here the alpha comes **first**: `0xAARRGGBB`)
  - Steam, Firefox, Electron apps (Discord/Vesktop) draw their own background and stay opaque
- **Color formats differ per program:** rofi `#RRGGBBAA`, hyprtoolkit `0xAARRGGBB`, Waybar / GTK 3 CSS only `rgba(…)` (GTK 3 does not understand 8-digit hex).

## What changed since the old vault

The old vault ([`-archived-Arch-Linux-Vault`](https://github.com/viggo0paal21/-archived-Arch-Linux-Vault)) was made by AI.
This vault contains **every file of the old vault**:

- If the file still exists on my PC, the **current version from my PC** is in here (e.g. `hyprland.lua`, `waybar/`, `gtk-3.0/gtk.css`, `kitty.conf`, `rofi/config.rasi`, `fastfetch/config.jsonc`, `qt6ct.conf`, `hyprtoolkit.conf`, swaync, hyprlock, starship).
- If it doesn't exist on my PC anymore (or can't be read from there), the **old version** from the archived vault is kept (guides, GPU scripts, `quickshell-old-design/`, `etc/`, `home/.zshrc`, the D-Bus override).
- Scripts in `home/.local/bin/` whose code on my PC is identical but whose comments are still German keep the English version from the old vault.
- **New files** that I use now: `hypr/performance.lua`, `hypr/system.lua`, `fontconfig/`, `Kvantum/MonoGlass/`, `quickshell/corners/shell.qml`, `qt6ct/colors/simplerice.conf`, `cava/config`.

Not in use anymore, but kept: Quickshell shell `quickshell/` (except `corners/`), `quickshell-old-design/`, `oled-bw/`, the zsh setup and the kitty-shell wrapper, `hyprpanel/`, `nwg-dock-hyprland/`, `rofi/monochrome.rasi`, `waybar/scripts/` and the `waybar/transparency*.css` files, `autostart/` (KDE / Cinnamon leftovers), the Quickshell scripts in `home/.local/bin/`.

## Contents

### Guides

| File | What it is |
|---|---|
| [`Arch Linux System Maintenance Guide.md`](Arch%20Linux%20System%20Maintenance%20Guide.md) | Safe updates, recovery playbook, all commands (also as `.txt`) |
| [`Performance Optimization.md`](Performance%20Optimization.md) | System tweaks for gaming performance and latency, incl. how to use the GPU scripts below |
| [`Low Latency Gaming.md`](Low%20Latency%20Gaming.md) | Best display setup with and without tearing, how tearing works on Hyprland |
| [`Quickshell Guide.md`](Quickshell%20Guide.md) | *Old shell, not in use.* My Quickshell shell: files, install, why the start script exists, FPS counter, other shells, rollback |
| [`Quickshell Stutter Guide.md`](Quickshell%20Stutter%20Guide.md) | *Old shell.* Why Quickshell stutters/freezes, how to measure it, every fix I used |

### Scripts

| File | What it is |
|---|---|
| [`nvidia-maxperf-setup.sh`](nvidia-maxperf-setup.sh) | Locks an NVIDIA GPU to max clocks (persists across boot and suspend). Edit the clock values for your card first. See [Performance Optimization, section 4](Performance%20Optimization.md#4-gpu-max-performance-clocks). |
| [`amdgpu-maxperf-setup.sh`](amdgpu-maxperf-setup.sh) | Same for AMD GPUs (sets the performance level to `high`) |
| [`install.sh`](install.sh) | Installs all programs and puts every file of this vault onto the PC, see [Install everything with one command](#install-everything-with-one-command) |

Scripts for `~/.local/bin` (in [`home/.local/bin/`](home/.local/bin)):

| File | What it is |
|---|---|
| [`check-direct-scanout`](home/.local/bin/check-direct-scanout) | **In use.** Notification that shows whether Hyprland's direct scanout is active (`Super + Home`, bind in `hypr/performance.lua`) |
| [`qs`](home/.local/bin/qs), [`quickshell`](home/.local/bin/quickshell) | **In use** (for the screen corners). Wrappers around `/usr/bin/qs` and `/usr/bin/quickshell`: Vulkan backend, without MangoHud / lsfg-vk / vkBasalt, so it applies to every Quickshell config |
| [`qs-start`](home/.local/bin/qs-start) | *Old shell.* Started Quickshell from the Hyprland autostart: Vulkan backend, without MangoHud / lsfg-vk / vkBasalt. See [Quickshell Guide](Quickshell%20Guide.md#3-why-the-start-script-exists-nvidia) |
| [`qs-restart`](home/.local/bin/qs-restart) | *Old shell.* Restarts the Quickshell shell |
| [`qs-dock`](home/.local/bin/qs-dock), [`qs-glass-apply`](home/.local/bin/qs-glass-apply) | *Old shell.* Dock launcher for nwg-dock-hyprland and the helper for Settings > Apps > Opacity (per-app opacity), see the [Quickshell Guide](Quickshell%20Guide.md) |
| [`qs-font-apply`](home/.local/bin/qs-font-apply), [`qs-font-revert`](home/.local/bin/qs-font-revert) | *Old shell.* Quickshell Settings > System > Font: sets the UI font for GTK 3/4 (settings.ini + gsettings), xsettingsd, qt5ct/qt6ct and fontconfig (`sans-serif` / `system-ui`). The first run saves the old state; `qs-font-revert` restores it and hides the menu again |
| [`kitty-shell/`](home/.local/bin/kitty-shell) | *Not in use* (kitty now uses plain bash). kitty started zsh through this wrapper (`shell` line in the old `kitty.conf`). It showed fastfetch before the first prompt when Quickshell Settings > Apps > kitty > "Fastfetch in kitty" was on. While only fastfetch was visible its values updated live about once a second (the image stays, no flicker); typing `fastfetch` brought it back like at the start, live again |
| [`fastfetch-show`](home/.local/bin/fastfetch-show), [`fastfetch-fit`](home/.local/bin/fastfetch-fit), [`fastfetch-logo`](home/.local/bin/fastfetch-logo) | *Not in use.* fastfetch for kitty: picks the biggest variant from [`fastfetch/variants/`](fastfetch/variants) that fits the window, shows it instantly from the last kitty's snapshot and swaps in the fresh values right after, redraws a smaller one when the window shrinks, and cycles the images from Settings > Apps > kitty > "Fastfetch images" (one per new kitty, pixel-exact for the cell size) |
| [`fastfetch-revert-variants`](home/.local/bin/fastfetch-revert-variants) | *Not in use.* Rolls the variants feature back to the local `*.bak-variants` backups (only useful on the machine that has them) |

### Shell

| File | What it is |
|---|---|
| (none) | **Current:** plain bash with Arch's defaults, fastfetch is not started automatically |
| [`home/.zshrc`](home/.zshrc) | *Old setup.* Zsh config (plugins, aliases, history settings) → `~/.zshrc` |
| [`starship.toml`](starship.toml) | Starship prompt config → `~/.config/starship.toml` (now reset to the default prompt) |
| [`shell-packages.txt`](shell-packages.txt) | Packages for the old zsh setup (zsh, plugins, Starship, eza, bat, fd, ripgrep, lazygit) |

### Config folders (→ `~/.config`)

| Folder | What it is |
|---|---|
| [`autostart/`](autostart) | Autostart entries from KDE / Cinnamon (all disabled, leftovers, Hyprland doesn't read them) |
| [`cava/`](cava) | **In use.** Music visualizer in the terminal |
| [`fastfetch/`](fastfetch) | **In use.** System info in the terminal: `config.jsonc` = my own small version ("Arch (btw)", white percentages). The `.txt` logos and `variants/` belong to the old setup |
| [`fontconfig/`](fontconfig) | **In use.** Font settings: `sans-serif` / `system-ui` → Noto Sans |
| [`gtk-3.0/`](gtk-3.0) | **In use.** GTK 3: colors, 75 % glass, rounded right-click menus, font in `settings.ini` |
| [`gtk-4.0/`](gtk-4.0) | **In use.** GTK 4 / libadwaita: CSS variables in `:root` (black/white, 75 % glass, radius) |
| [`hypr/`](hypr) | **In use.** `hyprland.lua` (my own), `system.lua` (env, autostart, fixes), `performance.lua` (MangoHud, VRR, tearing, direct scanout, mouse), `hyprlock.conf`, `hyprtoolkit.conf` (screen-share picker). `hyprland.lua.bak` = the old AI version from the old vault |
| [`hyprpanel/`](hyprpanel) | HyprPanel (bar) OUTDATED NOT IN USE |
| [`kitty/`](kitty) | **In use.** Terminal: only `background_opacity 0.75` |
| [`Kvantum/`](Kvantum) | **In use.** Qt theme engine: `MonoGlass/` = my copy of Monochrome (true black, white text, 75 % glass), active through `kvantum.kvconfig`. `Monochrome/` = the original theme |
| [`MangoHud/`](MangoHud) | **In use.** Stable FPS limiter and performance overlay for games (global + per game: cs2, lichii, UnleashedRecomp) |
| [`nwg-dock-hyprland/`](nwg-dock-hyprland) | Dock of the old setup, not in use |
| [`nwg-look/`](nwg-look) | GTK settings tool |
| [`qt6ct/`](qt6ct) | **In use.** Qt 6 settings: style `kvantum`, Noto Sans; color schemes (`simplerice.conf` was my own palette before Kvantum) |
| [`quickshell/`](quickshell) | *Old shell, not in use:* bar, launcher, control center, dashboard, notifications, OSD, power menu. See [Quickshell Guide](Quickshell%20Guide.md). **Exception:** [`quickshell/corners/`](quickshell/corners) = the screen corners I use now (started with `qs -n -p ~/.config/quickshell/corners`, see below) |
| [`quickshell-old-design/`](quickshell-old-design) | The same old shell with its **old design** (before the November 2026 redesign), kept as an alternative. Copy it to `~/.config/quickshell` instead of `quickshell/`. The whole repo at that point is also the branch [`quickshell-old-design`](https://github.com/viggo0paal21/-archived-Arch-Linux-Vault/tree/quickshell-old-design) ([zip](https://github.com/viggo0paal21/-archived-Arch-Linux-Vault/archive/refs/heads/quickshell-old-design.zip)) of the old vault |
| [`rofi/`](rofi) | **In use.** App launcher: `config.rasi` contains everything (settings + theme, `@theme "/dev/null"`). `monochrome.rasi` = theme of the old setup |
| [`swaync/`](swaync) | **In use.** Notifications, default look (imports `/etc/xdg/swaync/style.css`) |
| [`systemd/`](systemd) | User timers (Arch-Update weekly check, see below) |
| [`vibrantLinux/`](vibrantLinux) | Per-app color saturation (CS2) |
| [`waybar/`](waybar) | **In use.** Status bar: `config.jsonc` + `style.css`. `scripts/` and `transparency*.css` belong to the old setup |
| [`waypaper/`](waypaper) | **In use.** Wallpaper picker (backend awww) |
| [`xdg-desktop-portal/`](xdg-desktop-portal) | Portals (screen sharing, file picker) |

### Other

| Folder | What it is |
|---|---|
| [`etc/`](etc) | Files from outside `~/.config` (skipped by the restore loop in [Restore the configs](#restore-the-configs)) |
| [`home/`](home) | Files that belong directly in `~` (`.zshrc`, `.local/bin` scripts, Quickshell settings in `.local/state`, D-Bus override in `.local/share`). Also skipped by the restore loop |
| [`oled-bw/`](oled-bw) | Settings of the old Quickshell shell (same file as in `home/.local/state/quickshell/by-shell/oled-bw/`) |

## Hyprland: how my config is split

- [`hypr/hyprland.lua`](hypr/hyprland.lua): my own config. Monitor, autostart (Waybar, swaync, awww + waypaper, screen corners, blueman-applet), look (gaps, borders, rounding, blur), keybinds, animations (curve "snap"), `Super + V` = float at 5:3 in the center, layer rules (blur for rofi and Waybar), smart gaps.
- [`hypr/system.lua`](hypr/system.lua): background stuff so apps run and look right (cursor size, Qt through qt6ct, GTK dark + portal, hyprpolkitagent, arch-update tray, fixes). `GTK_THEME` must stay off, otherwise `gtk-4.0/gtk.css` is ignored.
- [`hypr/performance.lua`](hypr/performance.lua): gaming and latency from the old setup (MangoHud env, tearing allowed, direct scanout, VRR fullscreen-only, cursor settings for VRR, flat mouse, rules for videos and DOOM, `Super + Home` = direct scanout check).

Both extra files are loaded at the top of `hyprland.lua` with `require("system")` and `require("performance")`.

Keybinds: `Super + Q` kitty, `Super + R` rofi, `Super + E` Nautilus, `Super + C` close, `Super + Shift + C` kill, `Super + S` special workspace, `Super + V` float, `Super + J` toggle split, `Super + M` exit, `Super + Shift + S` screenshot of a region to the clipboard (grim + slurp + wl-copy), `Super + 1…0` workspaces, `Super + Shift + 1…0` move window, `Super + Shift + arrows` move, `Super + Ctrl + left/right` swap, `Super + mouse` drag / resize.

## Screen corners (optional)

Black rounded corners under the bar, so the screen looks rounded like the windows. A small Quickshell config in [`quickshell/corners/shell.qml`](quickshell/corners/shell.qml):

- reads `decoration.rounding` / `rounding_power` live from Hyprland (`hyprctl getoption`), re-reads them on every config reload
- sits automatically under the space Waybar reserves (layer surface with `exclusiveZone: 0`)
- is drawn **under** the windows (`aboveWindows: false`), so it never covers an app, and lets every click through
- on/off: `"screen-corners": true | "top" | false` in `waybar/config.jsonc`, takes effect immediately

Started by `hyprland.lua` with `qs -n -p ~/.config/quickshell/corners` (`-n` = never twice). `-p` is needed because a `shell.qml` directly in `~/.config/quickshell` (the old shell) makes Quickshell ignore named subfolders.

## Shell: zsh (old setup, not in use)

> Currently I use plain bash. This is the zsh setup from the old vault, kept as it was.

- **Prompt:** Starship (same look as before, config in `starship.toml`)
- **Plugins:** zsh-autosuggestions (gray suggestions from history, accept with →), zsh-syntax-highlighting (green = valid command, red = unknown)
- **Modern commands:** `ls` / `ll` / `tree` use eza, plus bat, fd, ripgrep (`rg`) and lazygit
- **History:** only valid commands are saved, typos and keyboard mashing are not
- **Safety:** `rm` is aliased to `rm --preserve-root=all`

Restore:

```bash
sudo pacman -S --needed - < shell-packages.txt
cp home/.zshrc ~/
cp starship.toml ~/.config/
chsh -s /usr/bin/zsh
```

Then log out and back in.

## Launcher: rofi

**Current setup (in use):**

- **Look:** true black at 75 % with blur, white 1 px border, 10 px rounding, Noto Sans 12, only a search field (no "apps" prompt), selected entry white with black text
- **Files:** only `rofi/config.rasi` (settings and theme in one file, `@theme "/dev/null"` switches off rofi's default theme)
- **Shortcut:** `Super + R` → `rofi -show drun` (variable `menu` in `hyprland.lua`)
- **Blur:** layer rule in `hyprland.lua`:

```lua
hl.layer_rule({ match = { namespace = "rofi" }, blur = true, ignore_alpha = 0 })
```

`ignore_alpha = 0` makes the blur skip fully transparent pixels, otherwise the transparent rounded corners get blurred too and you see a square blurred box.

Restore:

```bash
sudo pacman -S --needed rofi
cp -r rofi ~/.config/
```

**Old setup (from the old vault, kept for reference):**

> Back then rofi was replaced by the Quickshell launcher (`Super + R` ran `qs ipc call launcher toggle`) and kept as a fallback.

- **Look:** monochrome, same background color and 80 % opacity as Kitty, slightly rounded, JetBrains Mono
- **Behavior:** the shortcut opens rofi and closes it when pressed again, one click launches an app, the mouse wheel scrolls line by line
- **Files:** `rofi/config.rasi` (settings) and `rofi/monochrome.rasi` (colors, size, spacing)

To use the old toggle behavior, use this as the command of your launcher shortcut in `hyprland.lua`:

```lua
hl.dsp.exec_cmd("pkill rofi || rofi -show drun")
```

And the old blur + open/close animation at the end of `hyprland.lua`:

```lua
hl.layer_rule({
  match = { namespace = "rofi" },
  name = "rofi-blur",
  blur = true,
  ignore_alpha = 0,
  animation = "popin 90%",
})

-- smooth curve for all overlays (rofi, notifications)
hl.curve("launcherEase", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 2.5, curve = "launcherEase" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5, curve = "launcherEase" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2.5, curve = "launcherEase" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.5, curve = "launcherEase" })
```

Blur must also be enabled globally in `hyprland.lua` (`blur = { enabled = true }` under `decoration`).

## System tweaks (outside `~/.config`)

These live in system files, so they are documented here instead of being copied.

| What | Why | Setup |
|---|---|---|
| **earlyoom** | Kills the biggest Firefox tab before the RAM runs full, instead of the whole system freezing | below |
| **hyprpolkitagent** | Password pop-up for apps that need root (Timeshift, GSmartControl). Without it they silently don't start on Hyprland | `sudo pacman -S hyprpolkitagent`, started in `hypr/system.lua`: `hl.exec_cmd("systemctl --user start hyprpolkitagent")` |
| **Arch-Update weekly check** | Looks for updates every Monday at 17:00 instead of every 6 hours | below |
| **LTS emergency kernel** | Boot fallback if the main kernel breaks after an update | Maintenance Guide, section 4.7 |
| **Gaming performance tweaks** | NTSync, split lock, CPU/GPU max performance, shader cache, scheduler | [Performance Optimization](Performance%20Optimization.md) |
| **Bluetooth at boot** | Headphones connect by themselves after a reboot | `sudo systemctl enable --now bluetooth`, `blueman-applet` in the Hyprland autostart, mark the device as *Trusted* in blueman. Tray icon of blueman off: `gsettings set org.blueman.general plugin-list "['!StatusNotifierItem']"` |
| **Nautilus as default file manager** | Other apps open folders in Nautilus | `xdg-mime default org.gnome.Nautilus.desktop inode/directory` |

**earlyoom:**

```bash
sudo pacman -S earlyoom
sudo tee /etc/default/earlyoom > /dev/null << 'EOF'
EARLYOOM_ARGS="-m 5 -s 100 -r 0 --prefer 'Isolated.Web.Co|Web.Content' --avoid 'Hyprland|Xwayland|cs2|pipewire|wireplumber|vesktop|steam'"
EOF
sudo systemctl enable --now earlyoom
```

**Arch-Update weekly check:**

```bash
mkdir -p ~/.config/systemd/user/arch-update.timer.d
printf '[Timer]\nOnStartupSec=\nOnUnitActiveSec=\nOnCalendar=Mon 17:00\nPersistent=true\n' > ~/.config/systemd/user/arch-update.timer.d/weekly.conf
systemctl --user daemon-reload && systemctl --user restart arch-update.timer
```

## Global MangoHud (system-wide)

`hypr/performance.lua` sets `MANGOHUD=1` for everything started by Hyprland. In the old setup it was also in `/etc/environment`:

```
MANGOHUD=1
MANGOHUD_DLSYM=1
LD_PRELOAD=/usr/$LIB/mangohud/libMangoHud_opengl.so
__GL_SYNC_TO_VBLANK=1
MANGOHUD_CONFIG=read_cfg,no_display,legacy_layout=1
```

Keep `$LIB` exactly as it is (Linux fills it in itself). systemd reads `$LIB` as an empty
variable, so programs started by systemd get a broken path. Fix: create
`~/.config/environment.d/zz-mangohud.conf` containing:

```
LD_PRELOAD=/usr/$$LIB/mangohud/libMangoHud_opengl.so
```

This would also load MangoHud into Quickshell (FPS cap + extra vsync in the shell). The start script
[`qs-start`](home/.local/bin/qs-start) and the `qs` / `quickshell` wrappers keep it out, see the [Quickshell Guide](Quickshell%20Guide.md).
The screen corners are started with `MANGOHUD=0` for the same reason.

<!-- INSTALL-START -->

## Install the programs

_Updated on 21.11.2026: official packages via pacman, everything else via yay (AUR). If pacman can't find a package, try yay._

| Folder | Purpose | Packages |
|---|---|---|
| hypr | Hyprland + Hypr tools | `hyprland`, `hyprlock`, `hyprpolkitagent`, `xdg-desktop-portal-hyprland` (incl. the screen-share picker), `grim`, `slurp`, `wl-clipboard` (screenshot bind) |
| waybar | Status bar | `waybar`, `blueman`, `pavucontrol` |
| rofi | App launcher | `rofi` |
| swaync | Notifications | `swaync` |
| kitty | Terminal | `kitty` |
| fastfetch | System info in the terminal | `fastfetch` |
| cava | Music visualizer | `cava` |
| fontconfig | Font settings | `fontconfig`, `noto-fonts`, `ttf-jetbrains-mono-nerd` |
| gtk-3.0 | GTK 3 theme | `gtk3` |
| gtk-4.0 | GTK 4 theme | `gtk4` |
| Kvantum | Qt theme engine | `kvantum`, `kvantum-qt5` |
| qt6ct | Qt 6 theme settings | `qt6ct`, `qt6-wayland` |
| MangoHud | FPS / performance overlay for games | `mangohud`, `lib32-mangohud` |
| nautilus | File manager | `nautilus` |
| waypaper | Wallpaper picker | `waypaper` (AUR), `awww` (successor of swww) |
| quickshell/corners | Screen corners (optional) | `quickshell` |
| vibrantLinux | Per-app color saturation | `vibrantlinux` (AUR) |
| xdg-desktop-portal | Portals (screen sharing, file picker) | `xdg-desktop-portal`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` |
| nwg-look | GTK settings tool | `nwg-look` |
| *old:* quickshell | Old shell | `quickshell`, `inter-font`, `ttf-nerd-fonts-symbols` |
| *old:* hyprpanel | HyprPanel (bar) | `ags-hyprpanel-git` (AUR) |
| *old:* home/.zshrc | Zsh shell | see `shell-packages.txt` |
| autostart | KDE / Cinnamon leftovers | none needed |

### Install everything at once

**1. Official packages (pacman):**

```bash
sudo pacman -Syu --needed hyprland hyprlock hyprpolkitagent xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk grim slurp wl-clipboard waybar blueman pavucontrol rofi swaync kitty fastfetch cava fontconfig noto-fonts ttf-jetbrains-mono-nerd gtk3 gtk4 kvantum kvantum-qt5 qt6ct qt6-wayland mangohud lib32-mangohud nautilus nwg-look quickshell
```

> `lib32-…` packages need the **multilib** repository. If pacman can't find them,
> uncomment `[multilib]` and the `Include = /etc/pacman.d/mirrorlist` line below it in `/etc/pacman.conf`.
> Do **not** enable `[multilib-testing]` (it sits right above `[multilib]`).
> Never install single packages with `pacman -Sy <package>` (partial upgrade), always `-Syu`.

**2. AUR packages (yay):**

```bash
yay -S --needed waypaper awww vibrantlinux
```

For the old setup additionally: `sudo pacman -S --needed - < shell-packages.txt` (zsh), `sudo pacman -S --needed inter-font ttf-nerd-fonts-symbols` (old Quickshell shell), `sudo pacman -S --needed hyprsunset hyprpicker swaybg` (old Hypr tools and wallpaper backend), `yay -S --needed ags-hyprpanel-git swww` (HyprPanel, old wallpaper daemon).

If yay is missing:

```bash
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin && makepkg -si && cd .. && rm -rf yay-bin
```

## Restore the configs

> The easiest way is [`install.sh`](#install-everything-with-one-command). This section is the manual way.
>
> Warning: existing configs with the same name will be overwritten.

```bash
git clone https://github.com/viggo0paal21/Arch-Linux-Vault.git ~/config-backup
cd ~/config-backup

# restore a single folder, e.g. MangoHud:
cp -r MangoHud ~/.config/

# or all config folders at once (home/, etc/ and oled-bw/ are not ~/.config folders, quickshell-old-design/ is the
# alternative to quickshell/, so they are skipped):
for d in */; do case "$d" in home/|etc/|oled-bw/|quickshell-old-design/) ;; *) cp -r "$d" ~/.config/ ;; esac; done

# starship prompt (default prompt now):
cp starship.toml ~/.config/

# script for direct scanout check (Super + Home) and the Quickshell wrappers used by the screen corners:
mkdir -p ~/.local/bin
cp home/.local/bin/{check-direct-scanout,qs,quickshell} ~/.local/bin/
chmod +x ~/.local/bin/{check-direct-scanout,qs,quickshell}

# Nautilus as default file manager:
xdg-mime default org.gnome.Nautilus.desktop inode/directory
```

Then log out and back in (environment variables in `system.lua` / `performance.lua` only take effect at login).

**Old setup (Quickshell shell, zsh, fastfetch in kitty), from the old vault:**

```bash
# Starship prompt and zsh: see "Shell: zsh" above

# scripts for ~/.local/bin (Quickshell start script + wrappers, check-direct-scanout, qs-dock, qs-glass-apply,
# the fastfetch scripts and the kitty-shell/ folder; "/." also copies subfolders and hidden files):
mkdir -p ~/.local/bin && cp -r home/.local/bin/. ~/.local/bin/
chmod +x ~/.local/bin/{qs-start,qs,quickshell,qs-restart,check-direct-scanout,qs-dock,qs-glass-apply,qs-font-apply,qs-font-revert,fastfetch-show,fastfetch-fit,fastfetch-logo,fastfetch-revert-variants,kitty-shell/zsh}

# fastfetch in kitty: needs zsh, python3 and ImageMagick (magick). Put your images into
# ~/.config/fastfetch/logos (not in the repo, they are big). The old kitty.conf and fastfetch/config.jsonc
# contained /home/viggo paths, change them to your home folder.

# Quickshell settings:
mkdir -p ~/.local/state/quickshell/by-shell/oled-bw
cp home/.local/state/quickshell/by-shell/oled-bw/settings.json ~/.local/state/quickshell/by-shell/oled-bw/

# keep swaync/dunst/mako from taking Quickshell's notification server (D-Bus override).
# Don't copy this with the current setup, otherwise swaync gets no notifications:
mkdir -p ~/.local/share/dbus-1/services
cp home/.local/share/dbus-1/services/org.freedesktop.Notifications.service ~/.local/share/dbus-1/services/
```

Quickshell details and checks after restoring: [Quickshell Guide, section 2](Quickshell%20Guide.md#2-install--restore).

The local folder is called `~/config-backup` on purpose: my backup scripts expect that name.

<!-- INSTALL-END -->
