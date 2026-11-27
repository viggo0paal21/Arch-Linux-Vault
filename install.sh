#!/usr/bin/env bash
# ==========================================================================
#  install.sh - puts MY OWN rice from this vault onto an Arch Linux PC
#
#  My own setup, built and understood by me (state 26.11.2026):
#  Hyprland (Lua) + Waybar + rofi + kitty + fastfetch + starship,
#  GTK 3 with adw-gtk3-dark + my gtk.css, GTK 4 / libadwaita with my gtk.css.
#  The old AI-made rice is in legacy-ai/, installed by legacy-ai-help-version.sh.
#
#  1. installs the programs my configs need (pacman --needed, AUR via yay)
#  2. backs up every file it is about to replace
#  3. copies my config files to their place on the PC
#  4. small extras (bluetooth at boot, Nautilus as file manager, GTK theme)
#
#  Not touched: ~/.zshrc, SDDM, anything in /etc.
#
#  Usage (as your normal user, NOT with sudo), just this one line:
#      bash <(curl -fsSL https://raw.githubusercontent.com/viggo0paal21/Arch-Linux-Vault/main/install.sh)
#  The script downloads the vault to ~/config-backup by itself (or updates it
#  if it is already there) and then installs from there.
#
#  Or from an existing copy of the vault:
#      ~/config-backup/install.sh
#
#  Options:  --yes          no question at the start
#            --no-packages  only copy the files, install nothing
# ==========================================================================

set -euo pipefail

# ---- settings ------------------------------------------------------------

# Every program my configs need. pacman installs what it knows, anything it
# can't find is installed from the AUR with yay instead.
PACKAGES=(
    # Hyprland and its tools
    hyprland hyprpolkitagent
    xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    grim slurp wl-clipboard            # screenshot bind (Super + Shift + S)
    # bar, launcher, notifications, terminal (all started in hypr/hyprland.lua)
    waybar rofi swaync kitty
    blueman bluez bluez-utils          # Waybar bluetooth module, click opens blueman-manager
    nm-wifi-gui                        # Wi-Fi GUI (libadwaita), click on the Waybar network module
    awww                               # wallpaper daemon (awww-daemon in the autostart)
    # terminal
    fastfetch starship
    # fonts (Waybar uses Noto Sans + JetBrains Mono Nerd Font for the icons)
    fontconfig noto-fonts ttf-jetbrains-mono-nerd
    # GTK and Qt look
    gtk3 gtk4
    adw-gtk-theme                      # GTK 3 theme adw-gtk3-dark (looks like libadwaita)
    adwaita-icon-theme                 # my icon theme "rice" takes everything except the folders from it
    breeze                             # mouse cursor breeze_cursors (hypr/system.lua)
    xsettingsd                         # theme for X11 apps (Zen runs on XWayland)
    qt6ct qt6-wayland                  # QT_QPA_PLATFORMTHEME=qt6ct (hypr/system.lua)
    # apps
    nautilus
    zen-browser-bin                    # starts through XWayland, see home/.local/share/applications/zen.desktop
    arch-update                        # update icon in the tray (hypr/system.lua)
    vibrantlinux                       # per-app color saturation
    # gaming (MANGOHUD=1 in hypr/performance.lua)
    mangohud lib32-mangohud
)

# Vault folders that are NOT ~/.config folders
SKIP_DIRS=(home legacy-ai)

# ---- helpers -------------------------------------------------------------

REPO_URL="${VAULT_REPO:-https://github.com/viggo0paal21/Arch-Linux-Vault.git}"
CLONE_DIR="$HOME/config-backup"
SCRIPT="${BASH_SOURCE[0]:-}"
VAULT="$(cd "$(dirname "$(readlink -f "${SCRIPT:-.}")")" 2>/dev/null && pwd || true)"   # empty if started via curl
BACKUP="$HOME/.config-backup-before-install-$(date +%Y%m%d-%H%M%S)"
ASSUME_YES=0
DO_PACKAGES=1

for arg in "$@"; do
    case "$arg" in
        --yes|-y)      ASSUME_YES=1 ;;
        --no-packages) DO_PACKAGES=0 ;;
        -h|--help)     sed -n '2,27p' "$SCRIPT" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)             echo "unknown option: $arg (see --help)"; exit 1 ;;
    esac
done

# questions are read from the keyboard, even when the script itself comes from curl
if { : < /dev/tty; } 2>/dev/null; then TTY=/dev/tty; else TTY=/dev/stdin; fi

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[33m    ! %s\033[0m\n' "$*"; }

in_list() {            # in_list <word> <list...>
    local w="$1"; shift
    local x
    for x in "$@"; do [ "$x" = "$w" ] && return 0; done
    return 1
}

# copies one file to its target; backs up the old one first if it differs
COPIED=0
BACKED_UP=0
put_file() {           # put_file <source> <target>
    local src="$1" dst="$2"
    if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
        mkdir -p "$BACKUP/$(dirname "${dst#"$HOME"/}")"
        cp -a "$dst" "$BACKUP/${dst#"$HOME"/}"
        BACKED_UP=$((BACKED_UP + 1))
    fi
    # scripts get 755 (executable), everything else 644 (normal file you can edit)
    local mode=644
    [ -x "$src" ] && mode=755
    install -D -m "$mode" "$src" "$dst"
    COPIED=$((COPIED + 1))
}

# ---- checks --------------------------------------------------------------

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not with sudo (it asks for the password itself)."
    exit 1
fi
if ! command -v pacman >/dev/null; then
    echo "pacman not found: this installer is for Arch Linux."
    exit 1
fi

# Started on its own (e.g. with curl) instead of from inside the vault?
# Then download the vault first and start the install.sh in there.
if [ ! -f "$SCRIPT" ] || [ -z "$VAULT" ] || [ ! -d "$VAULT/hypr" ] || [ ! -d "$VAULT/legacy-ai" ]; then
    say "Getting the vault"
    if ! command -v git >/dev/null; then
        info "git is missing, installing it"
        # shellcheck disable=SC2024  # reading the keyboard as the normal user is intended
        sudo pacman -Syu --needed git < "$TTY"
    fi
    if [ -d "$CLONE_DIR/.git" ]; then
        # ~/config-backup must be a copy of THIS repo, not of an old/archived one
        origin="$(git -C "$CLONE_DIR" remote get-url origin 2>/dev/null || true)"
        if ! [[ "$origin" =~ [/:]viggo0paal21/Arch-Linux-Vault(\.git)?/?$ ]]; then
            warn "$CLONE_DIR is a copy of another repo: ${origin:-unknown}"
            warn "Move it away first (mv ~/config-backup ~/config-backup-old) and start again."
            exit 1
        fi
        info "updating $CLONE_DIR"
        git -C "$CLONE_DIR" pull --ff-only || warn "could not update, using the copy that is already there"
    else
        info "downloading to $CLONE_DIR"
        git clone "$REPO_URL" "$CLONE_DIR"
    fi
    # questions (this script, pacman, yay) must come from the keyboard, not from curl
    exec bash "$CLONE_DIR/install.sh" "$@" < "$TTY"
fi

say "Arch-Linux-Vault: my own rice"
info "Vault:   $VAULT"
info "Home:    $HOME"
[ "$DO_PACKAGES" -eq 1 ] && info "1. install programs (pacman --needed, AUR via yay)"
info "2. back up files that get replaced to: $BACKUP"
info "3. copy my config files from the vault (existing ones are replaced)"
info "4. extras: bluetooth at boot, Nautilus as file manager, GTK theme adw-gtk3-dark, icons rice, blueman tray icon off, font cache"
info "not touched: ~/.zshrc, SDDM, /etc"

if [ "$ASSUME_YES" -eq 0 ]; then
    printf '\nContinue? [y/N] '
    read -r answer < "$TTY"
    case "$answer" in y|Y|yes|j|J|ja) ;; *) echo "Cancelled, nothing changed."; exit 0 ;; esac
fi

# ---- 1. programs ---------------------------------------------------------

if [ "$DO_PACKAGES" -eq 1 ]; then
    say "1. Installing programs"

    # full system upgrade first (-Syu). Only after that it is safe to install
    # single packages with -S (a plain -Sy + -S is a partial upgrade and breaks Arch)
    sudo pacman -Syu

    # sort into "pacman knows it" and "try the AUR"
    official=()
    aur=()
    for p in "${PACKAGES[@]}"; do
        if pacman -Si "$p" >/dev/null 2>&1; then
            official+=("$p")
        elif [[ "$p" == lib32-* ]]; then
            warn "$p skipped: needs the [multilib] repo (enable it in /etc/pacman.conf)"
        else
            aur+=("$p")
        fi
    done

    sudo pacman -S --needed "${official[@]}"

    if [ "${#aur[@]}" -gt 0 ]; then
        if ! command -v yay >/dev/null; then
            info "yay (AUR helper) is missing, installing it"
            sudo pacman -S --needed git base-devel
            tmp="$(mktemp -d)"
            git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
            (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
            rm -rf "$tmp"
        fi
        yay -S --needed "${aur[@]}" || warn "some AUR packages failed, see the output above"
    fi
else
    say "1. Skipping programs (--no-packages)"
fi

# ---- 2. + 3. files -------------------------------------------------------

say "2./3. Copying files"

# config folders -> ~/.config/<folder>
shopt -s dotglob nullglob
for dir in "$VAULT"/*/; do
    dir="${dir%/}"
    name="$(basename "$dir")"
    [ "$name" = ".git" ] && continue
    in_list "$name" "${SKIP_DIRS[@]}" && continue
    while IFS= read -r -d '' f; do
        put_file "$f" "$HOME/.config/${f#"$VAULT"/}"
    done < <(find "$dir" -type f -print0)
done

# single files -> ~/.config (starship prompt, Zen as default browser)
put_file "$VAULT/starship.toml" "$HOME/.config/starship.toml"
put_file "$VAULT/mimeapps.list" "$HOME/.config/mimeapps.list"

# home/ -> ~ (script in ~/.local/bin, Zen starter in ~/.local/share/applications,
#            icon theme rice in ~/.local/share/icons)
while IFS= read -r -d '' f; do
    put_file "$f" "$HOME/${f#"$VAULT"/home/}"
done < <(find "$VAULT/home" -type f -print0)

info "$COPIED files copied, $BACKED_UP old versions backed up"
[ "$BACKED_UP" -gt 0 ] && info "backup: $BACKUP"

# ---- 4. extras -----------------------------------------------------------

say "4. Extras"

if command -v systemctl >/dev/null && systemctl list-unit-files bluetooth.service >/dev/null 2>&1; then
    sudo systemctl enable --now bluetooth.service && info "bluetooth starts at boot"
fi
if command -v xdg-mime >/dev/null; then
    xdg-mime default org.gnome.Nautilus.desktop inode/directory && info "Nautilus is the default file manager"
fi
if command -v gsettings >/dev/null; then
    # Wayland GTK apps read the theme from here; the same values are in
    # gtk-3.0/settings.ini (fallback) and xsettingsd/xsettingsd.conf (X11 apps)
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null \
        && gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null \
        && gsettings set org.gnome.desktop.interface cursor-theme 'breeze_cursors' 2>/dev/null \
        && gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null \
        && gsettings set org.gnome.desktop.interface icon-theme 'rice' 2>/dev/null \
        && info "GTK: theme adw-gtk3-dark, dark mode, cursor breeze_cursors 24, icons rice (white folders)"
    # no blueman icon in the tray (Waybar has its own bluetooth module); blueman-applet keeps running
    gsettings set org.blueman.general plugin-list '["!StatusNotifierItem"]' 2>/dev/null \
        && info "blueman tray icon off"
fi
if command -v fc-cache >/dev/null; then
    fc-cache -f >/dev/null && info "font cache rebuilt"
fi

say "Done"
info "Log out and back in (or reboot) so Hyprland, Waybar and the environment variables load."
