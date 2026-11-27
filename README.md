# Arch-Linux-Vault

My Arch Linux configs. Two versions live in this repo:

| | What | Installed by |
|---|---|---|
| **my own rice** (default) | built and understood by me, line by line (state 26.11.2026) | [`install.sh`](install.sh) |
| **old AI rice** | the AI-made setup I had before, kept complete in [`legacy-ai/`](legacy-ai/) | [`legacy-ai-help-version.sh`](legacy-ai-help-version.sh) |

## Install my own rice

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/viggo0paal21/Arch-Linux-Vault/main/install.sh)
```

The script downloads this vault to `~/config-backup` (or updates it there) and installs from there.
Already have the vault on the PC: `~/config-backup/install.sh`. Run it as your normal user, not with `sudo`.

What it does:

1. **Programs:** `pacman -Syu`, then everything my configs need with `pacman -S --needed`; anything pacman doesn't know comes from the AUR with yay (yay gets installed if missing). `lib32-mangohud` needs the [multilib] repo.
2. **Backup:** every file that is about to be replaced and differs is copied to `~/.config-backup-before-install-<date>` first.
3. **Files:** every folder → `~/.config/<folder>`, `starship.toml` and `mimeapps.list` → `~/.config/`, `home/` → `~`.
4. **Extras:** bluetooth at boot, Nautilus as file manager, gsettings: GTK theme `adw-gtk3-dark`, dark mode, cursor `breeze_cursors` 24, icon theme `rice`, blueman tray icon off (Waybar has its own bluetooth module), font cache.

**Not touched:** `~/.zshrc`, SDDM, anything in `/etc`.

Options: `--yes` (no question at the start), `--no-packages` (only copy the files). Then log out and back in.

## What's in my own rice

| Folder / file | → on the PC | What |
|---|---|---|
| `hypr/` | `~/.config/hypr/` | Hyprland (Lua): `hyprland.lua`, `system.lua`, `performance.lua`, `hyprtoolkit.conf` (screen share picker), avatars |
| `waybar/` | `~/.config/waybar/` | bar: `config.jsonc`, `style.css` (logo click = rofi, grey inactive workspaces, bluetooth with connection count → blueman-manager, Wi-Fi click → nm-wifi-gui) |
| `rofi/` | `~/.config/rofi/` | launcher: `config.rasi` (only app names) + my theme `Modern-Theme.rasi` (matches bold, no underline; `config-beispiel.rasi` = the dumped default as reference) |
| `kitty/` | `~/.config/kitty/` | terminal: 0.8 opacity, beam cursor with trail, `sync_to_monitor no` |
| `fastfetch/` | `~/.config/fastfetch/` | `config.jsonc` (big), `ff.jsonc` (small) |
| `starship.toml` | `~/.config/` | prompt |
| `gtk-3.0/` | `~/.config/gtk-3.0/` | `gtk.css` (glass look for GTK 3, dialogs and Waybar, transparent sidebars, no CSD shadow, menus + tooltips 10px round with 1px white border), `settings.ini` (theme `adw-gtk3-dark`), `bookmarks` |
| `gtk-4.0/` | `~/.config/gtk-4.0/` | `gtk.css` (libadwaita variables: glass, white accent; menus + tooltips 10px round with 1px white border), `settings.ini` |
| `xsettingsd/` | `~/.config/xsettingsd/` | GTK theme + icon theme for X11 apps (Zen, file dialog) |
| `xdg-desktop-portal/` | `~/.config/xdg-desktop-portal/` | `hyprland-portals.conf`: file dialogs come from the GTK portal (own program, so `gtk-3.0/gtk.css` glass works); without it Zen draws its own opaque dialog |
| `qt6ct/` | `~/.config/qt6ct/` | `qt6tc.conf` |
| `systemd/` | `~/.config/systemd/` | arch-update timer: weekly |
| `vibrantLinux/` | `~/.config/vibrantLinux/` | per-app saturation |
| `mimeapps.list` | `~/.config/` | Zen as default browser |
| `home/.local/bin/check-direct-scanout` | `~/.local/bin/` | Super + Home (bind in `performance.lua`) |
| `home/.local/share/applications/zen.desktop` | `~/.local/share/applications/` | starts Zen through XWayland |
| `home/.local/share/icons/rice/` | `~/.local/share/icons/rice/` | icon theme: Adwaita, only the folders white and filled (`Inherits=Adwaita,hicolor`, app icons stay default) |

Notes:

- `fastfetch/config.jsonc` points to `~/.config/fastfetch/hent.txt` (my logo). That file is deliberately **not** in this public repo.
- `hyprland.lua` starts `~/.local/bin/wallpaper-restore` at login. That script belongs to the old rice (`legacy-ai/home/.local/bin/`), my version doesn't install it.
- swaync has no config here, it runs with its defaults.

## Old AI rice (legacy)

Everything the vault contained until 26.11.2026 is in [`legacy-ai/`](legacy-ai/), unchanged: the full AI-made rice, the guides (maintenance, performance, low latency gaming, Quickshell), the setup scripts and `reset-to-default.sh`. Its old README is [`legacy-ai/README.md`](legacy-ai/README.md).

Install it (same backups as above):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/viggo0paal21/Arch-Linux-Vault/main/legacy-ai-help-version.sh)
```

or `~/config-backup/legacy-ai-help-version.sh`. Unlike my own version it also installs the SDDM theme and `/etc/sudoers.d/pwfeedback`, and sets the old gsettings (Back-In-Black, icons rice).
