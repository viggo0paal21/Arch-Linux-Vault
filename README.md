# Arch-Vault

Everything I need to keep my Arch Linux system running and to rebuild it from scratch:
my personal `~/.config` files (Hyprland rice), my zsh setup, a maintenance guide and helper scripts.

> 📖 **[Arch Linux System Maintenance Guide](Arch%20Linux%20System%20Maintenance%20Guide.md)**: safe updates, recovery playbook and all commands.

## Contents

| File / folder | What it is |
|---|---|
| Config folders (`hypr`, `waybar`, `kitty`, …) | My configs from `~/.config` |
| `starship.toml` | Starship prompt config (`~/.config/starship.toml`) |
| `home/.zshrc` | Zsh config (plugins, aliases, history settings) → `~/.zshrc` |
| `shell-packages.txt` | Packages for the shell setup (zsh, plugins, Starship, eza, bat, fd, ripgrep, lazygit) |
| [`Arch Linux System Maintenance Guide.md`](Arch%20Linux%20System%20Maintenance%20Guide.md) | Safe updates, recovery playbook, all commands |
| `nvidia-maxperf-setup.sh` | Locks an NVIDIA GPU to max clocks (persists across boot and suspend). Edit the clock values for your card first. |
| `amdgpu-maxperf-setup.sh` | Same for AMD GPUs (sets the performance level to `high`) |

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

## System tweaks (outside `~/.config`)

These live in system files, so they are documented here instead of being copied.

| What | Why | Setup |
|---|---|---|
| **earlyoom** | Kills the biggest Firefox tab before the RAM runs full, instead of the whole system freezing | below |
| **hyprpolkitagent** | Password pop-up for apps that need root (Timeshift, GSmartControl). Without it they silently don't start on Hyprland | `sudo pacman -S hyprpolkitagent`, then in `hyprland.lua`: `hl.exec_cmd("systemctl --user start hyprpolkitagent")` |
| **Arch-Update weekly check** | Looks for updates every Monday at 17:00 instead of every 6 hours | below |
| **LTS emergency kernel** | Boot fallback if the main kernel breaks after an update | Maintenance Guide, section 4.7 |

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
| hypr | Hyprland + Hypr tools | `hyprland`, `hyprlauncher`, `hyprlock`, `hyprsunset`, `hyprpicker` |
| hyprpanel | HyprPanel (bar) | `ags-hyprpanel-git` (AUR) |
| kitty | Terminal | `kitty` |
| Kvantum | Qt theme engine | `kvantum`, `kvantum-qt5` |
| MangoHud | FPS / performance overlay for games | `mangohud`, `lib32-mangohud` |
| nautilus | File manager | `nautilus` |
| nwg-look | GTK settings tool | `nwg-look` |
| qt6ct | Qt 6 theme settings | `qt6ct` |
| swaync | Notifications | `swaync` |
| vibrantLinux | Per-app color saturation | `vibrantlinux` (AUR) |
| waybar | Status bar | `waybar`, `blueman`, `pavucontrol` |
| waypaper | Wallpaper picker | `waypaper` (AUR), `swww` (AUR), `swaybg` |
| xdg-desktop-portal | Portals (screen sharing, file picker) | `xdg-desktop-portal`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` |
| home/.zshrc | Zsh shell | see `shell-packages.txt` |

### Install everything at once

**1. Official packages (pacman):**

```bash
sudo pacman -Syu --needed fastfetch fontconfig ttf-jetbrains-mono-nerd gtk3 gtk4 hyprland hyprlauncher hyprlock hyprsunset hyprpicker kitty kvantum kvantum-qt5 mangohud lib32-mangohud nautilus nwg-look qt6ct swaync waybar blueman pavucontrol swaybg xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
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

# or all config folders at once (home/ is not a ~/.config folder, so it is skipped):
for d in */; do [ "$d" = "home/" ] || cp -r "$d" ~/.config/; done

# Starship prompt and zsh: see "Shell: zsh" above
```

The local folder is called `~/config-backup` on purpose: my backup scripts expect that name.

<!-- INSTALL-END -->

<!-- INSTALL-END -->
