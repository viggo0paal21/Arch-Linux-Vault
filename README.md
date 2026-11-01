# Arch-Vault

Everything I need to keep my Arch Linux system running and to rebuild it from scratch:
my personal `~/.config` files (Hyprland rice), my zsh setup, maintenance and performance guides, and helper scripts.

> 📖 **[Arch Linux System Maintenance Guide](Arch%20Linux%20System%20Maintenance%20Guide.md)**: safe updates, recovery playbook and all commands.

> ⚡ **[Performance Optimization](Performance%20Optimization.md)**: system tweaks for gaming performance and latency: NTSync, split lock, CPU and GPU max performance (incl. the NVIDIA/AMD scripts), shader cache, gaming scheduler.

> 🎮 **[Low Latency Gaming](Low%20Latency%20Gaming.md)**: best setup with and without tearing, and how tearing works on Wayland/Hyprland.

## Contents

### Guides

| File | What it is |
|---|---|
| [`Arch Linux System Maintenance Guide.md`](Arch%20Linux%20System%20Maintenance%20Guide.md) | Safe updates, recovery playbook, all commands |
| [`Performance Optimization.md`](Performance%20Optimization.md) | System tweaks for gaming performance and latency, incl. how to use the GPU scripts below |
| [`Low Latency Gaming.md`](Low%20Latency%20Gaming.md) | Best display setup with and without tearing, how tearing works on Hyprland |

### Scripts

| File | What it is |
|---|---|
| [`nvidia-maxperf-setup.sh`](nvidia-maxperf-setup.sh) | Locks an NVIDIA GPU to max clocks (persists across boot and suspend). Edit the clock values for your card first. See [Performance Optimization, section 4](Performance%20Optimization.md#4-gpu-max-performance-clocks). |
| [`amdgpu-maxperf-setup.sh`](amdgpu-maxperf-setup.sh) | Same for AMD GPUs (sets the performance level to `high`) |

### Shell

| File | What it is |
|---|---|
| [`home/.zshrc`](home/.zshrc) | Zsh config (plugins, aliases, history settings) → `~/.zshrc` |
| [`starship.toml`](starship.toml) | Starship prompt config → `~/.config/starship.toml` |
| [`shell-packages.txt`](shell-packages.txt) | Packages for the shell setup (zsh, plugins, Starship, eza, bat, fd, ripgrep, lazygit) |

### Config folders (→ `~/.config`)

| Folder | What it is |
|---|---|
| [`autostart/`](autostart) | Programs that start automatically at login |
| [`fastfetch/`](fastfetch) | System info in the terminal |
| [`fontconfig/`](fontconfig) | Font settings |
| [`gtk-3.0/`](gtk-3.0) | GTK 3 theme |
| [`gtk-4.0/`](gtk-4.0) | GTK 4 theme |
| [`hypr/`](hypr) | Hyprland (`hyprland.lua`) and Hypr tools |
| [`hyprpanel/`](hyprpanel) | HyprPanel (bar) OUTDATED NOT IN USE, USE WAYBAR|
| [`kitty/`](kitty) | Terminal |
| [`Kvantum/`](Kvantum) | Qt theme engine |
| [`MangoHud/`](MangoHud) | FPS / performance overlay for games |
| [`nautilus/`](nautilus) | File manager |
| [`nwg-look/`](nwg-look) | GTK settings tool |
| [`qt6ct/`](qt6ct) | Qt 6 theme settings |
| [`rofi/`](rofi) | App launcher: `config.rasi` (settings) + `monochrome.rasi` (theme) |
| [`swaync/`](swaync) | Notifications |
| [`vibrantLinux/`](vibrantLinux) | Per-app color saturation |
| [`waybar/`](waybar) | Status bar |
| [`waypaper/`](waypaper) | Wallpaper picker |
| [`xdg-desktop-portal/`](xdg-desktop-portal) | Portals (screen sharing, file picker) |

### Other

| Folder | What it is |
|---|---|
| [`etc/`](etc) | Files from outside `~/.config` (skipped by the restore loop in [Restore the configs](#restore-the-configs)) |

## Shell: zsh

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

- **Look:** monochrome, same background color and 80 % opacity as Kitty, slightly rounded, JetBrains Mono
- **Behavior:** the shortcut opens rofi and closes it when pressed again, one click launches an app, the mouse wheel scrolls line by line
- **Files:** `rofi/config.rasi` (settings) and `rofi/monochrome.rasi` (colors, size, spacing)

Restore:

```bash
sudo pacman -S --needed rofi
cp -r rofi ~/.config/
```

Then in `~/.config/hypr/hyprland.lua`, use this as the command of your launcher shortcut:

```lua
hl.dsp.exec_cmd("pkill rofi || rofi -show drun")
```

And add blur + open/close animation at the end of `hyprland.lua`:

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
| **hyprpolkitagent** | Password pop-up for apps that need root (Timeshift, GSmartControl). Without it they silently don't start on Hyprland | `sudo pacman -S hyprpolkitagent`, then in `hyprland.lua`: `hl.exec_cmd("systemctl --user start hyprpolkitagent")` |
| **Arch-Update weekly check** | Looks for updates every Monday at 17:00 instead of every 6 hours | below |
| **LTS emergency kernel** | Boot fallback if the main kernel breaks after an update | Maintenance Guide, section 4.7 |
| **Gaming performance tweaks** | NTSync, split lock, CPU/GPU max performance, shader cache, scheduler | [Performance Optimization](Performance%20Optimization.md) |

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

Add to `/etc/environment`:

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

<!-- INSTALL-START -->

## Install the programs

_Generated on 28.10.2026: official packages via pacman, everything else via yay (AUR)._

| Folder | Purpose | Packages |
|---|---|---|
| autostart | Programs that start automatically at login | none needed |
| fastfetch | System info in the terminal | `fastfetch` |
| fontconfig | Font settings | `fontconfig`, `ttf-jetbrains-mono-nerd` |
| gtk-3.0 | GTK 3 theme | `gtk3` |
| gtk-4.0 | GTK 4 theme | `gtk4` |
| hypr | Hyprland + Hypr tools | `hyprland`, `hyprlock`, `hyprsunset`, `hyprpicker` |
| hyprpanel | HyprPanel (bar) | `ags-hyprpanel-git` (AUR) |
| kitty | Terminal | `kitty` |
| Kvantum | Qt theme engine | `kvantum`, `kvantum-qt5` |
| MangoHud | FPS / performance overlay for games | `mangohud`, `lib32-mangohud` |
| nautilus | File manager | `nautilus` |
| nwg-look | GTK settings tool | `nwg-look` |
| qt6ct | Qt 6 theme settings | `qt6ct` |
| rofi | App launcher | `rofi` |
| swaync | Notifications | `swaync` |
| vibrantLinux | Per-app color saturation | `vibrantlinux` (AUR) |
| waybar | Status bar | `waybar`, `blueman`, `pavucontrol` |
| waypaper | Wallpaper picker | `waypaper` (AUR), `swww` (AUR), `swaybg` |
| xdg-desktop-portal | Portals (screen sharing, file picker) | `xdg-desktop-portal`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` |
| home/.zshrc | Zsh shell | see `shell-packages.txt` |

### Install everything at once

**1. Official packages (pacman):**

```bash
sudo pacman -Syu --needed fastfetch fontconfig ttf-jetbrains-mono-nerd gtk3 gtk4 hyprland hyprlock hyprsunset hyprpicker kitty kvantum kvantum-qt5 mangohud lib32-mangohud nautilus nwg-look qt6ct rofi swaync waybar blueman pavucontrol swaybg xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
sudo pacman -S --needed - < shell-packages.txt
```

> `lib32-…` packages need the **multilib** repository. If pacman can't find them,
> uncomment `[multilib]` and the `Include = /etc/pacman.d/mirrorlist` line below it in `/etc/pacman.conf`.
> Do **not** enable `[multilib-testing]` (it sits right above `[multilib]`).

**2. AUR packages (yay):**

```bash
yay -S --needed ags-hyprpanel-git vibrantlinux waypaper swww
```

If yay is missing:

```bash
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin && makepkg -si && cd .. && rm -rf yay-bin
```

## Restore the configs

> Warning: existing configs with the same name will be overwritten.

```bash
git clone https://github.com/viggo0paal21/Arch-Vault.git ~/config-backup
cd ~/config-backup

# restore a single folder, e.g. MangoHud:
cp -r MangoHud ~/.config/

# or all config folders at once (home/ and etc/ are not ~/.config folders, so they are skipped):
for d in */; do case "$d" in home/|etc/) ;; *) cp -r "$d" ~/.config/ ;; esac; done

# Starship prompt and zsh: see "Shell: zsh" above
```

The local folder is called `~/config-backup` on purpose: my backup scripts expect that name.

<!-- INSTALL-END -->
