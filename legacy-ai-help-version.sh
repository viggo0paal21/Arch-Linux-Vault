#!/usr/bin/env bash
# ==========================================================================
#  legacy-ai-help-version.sh - installs the OLD AI-made rice from legacy-ai/
#
#  This is the setup I had before I built my own rice myself (the state of
#  the vault on 26.11.2026). My own current setup is installed by install.sh.
#
#  1. installs every program the configs need (pacman --needed, AUR via yay)
#  2. backs up every file it is about to replace
#  3. copies every file from the vault to its place on the PC
#  4. small extras (bluetooth on at boot, Nautilus as file manager, fonts)
#
#  Usage (as your normal user, NOT with sudo), just this one line:
#      bash <(curl -fsSL https://raw.githubusercontent.com/viggo0paal21/Arch-Linux-Vault/main/legacy-ai-help-version.sh)
#  The script downloads the vault to ~/config-backup by itself (or updates it
#  if it is already there) and then installs from there.
#
#  Or from an existing copy of the vault:
#      ~/config-backup/legacy-ai-help-version.sh
#
#  Options:  --yes          no question at the start
#            --no-packages  only copy the files, install nothing
# ==========================================================================

set -euo pipefail

# ---- settings ------------------------------------------------------------

# Every program the configs need. pacman installs what it knows, anything it
# can't find is installed from the AUR with yay instead (so it doesn't matter
# if a package lives in the official repos or in the AUR).
PACKAGES=(
    # Hyprland and its tools
    hyprland hyprlock hyprpolkitagent
    xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    grim slurp wl-clipboard            # screenshot bind (Super + Shift + S)
    # bar, launcher, notifications, terminal
    waybar rofi swaync kitty
    sddm                               # login screen, theme "rice" from sddm/rice
    blueman bluez bluez-utils pavucontrol
    # wallpaper
    waypaper awww
    linux-wallpaperengine-git          # animated Steam Wallpaper Engine wallpapers
    # terminal tools
    fastfetch cava
    fetch-git                          # rotating 3D logo (alias fetch in ~/.zshrc)
    jq                                 # used by ~/.local/bin/wallpaper-restore
    # fonts
    fontconfig noto-fonts ttf-jetbrains-mono-nerd
    # GTK and Qt look
    gtk3 gtk4
    adwaita-icon-theme                 # my icon theme rice inherits everything except folders from it
    breeze                             # mouse cursor breeze_cursors
    xsettingsd                         # theme + font for X11 apps (Zen runs on XWayland)
    qt6ct qt6-wayland kvantum kvantum-qt5
    # apps
    nautilus
    zen-browser-bin                    # browser (starts through XWayland, see home/.local/share/applications/zen.desktop)
    arch-update                        # update icon in the tray (started in hypr/system.lua)
    vibrantlinux                       # per-app color saturation
    # gaming
    mangohud lib32-mangohud
)

# Vault folders that are NOT ~/.config folders.
# experimental/ = optional AI-made extras, never installed automatically (see its README)
# old setups kept for reference (Quickshell, HyprPanel, nwg-dock, nwg-look, KDE/Cinnamon autostart files):
# never copied, they would only clutter ~/.config or even start old programs
SKIP_DIRS=(home etc oled-bw quickshell-old-design experimental
           quickshell "quickshell (opencode box)" hyprpanel nwg-dock-hyprland nwg-look autostart)

# Files from home/ that must not be copied:
#  - the D-Bus override blocks swaync from getting notifications (old Quickshell setup)
#  - home/viggo/ is a broken leftover path from the old vault
SKIP_HOME=(
    ".local/share/dbus-1/services/org.freedesktop.Notifications.service"
    "viggo/"
    # old Quickshell setup and its helper scripts, the old dock, the old fastfetch-in-kitty system
    ".local/state/quickshell"
    ".local/bin/qs"
    ".local/bin/quickshell"
    ".local/bin/dock"
    ".local/bin/fastfetch-"
    ".local/bin/kitty-shell/"
    ".cache/nwg-dock-pinned"
)

# ---- helpers -------------------------------------------------------------

REPO_URL="${VAULT_REPO:-https://github.com/viggo0paal21/Arch-Linux-Vault.git}"
CLONE_DIR="$HOME/config-backup"   # my backup scripts expect this name
SCRIPT="${BASH_SOURCE[0]:-}"
ROOT="$(cd "$(dirname "$(readlink -f "${SCRIPT:-.}")")" 2>/dev/null && pwd || true)"   # empty if started via curl
VAULT="$ROOT/legacy-ai"           # the old AI-made rice lives in this subfolder
BACKUP="$HOME/.config-backup-before-install-$(date +%Y%m%d-%H%M%S)"
ASSUME_YES=0
DO_PACKAGES=1

for arg in "$@"; do
    case "$arg" in
        --yes|-y)      ASSUME_YES=1 ;;
        --no-packages) DO_PACKAGES=0 ;;
        -h|--help)     sed -n '2,23p' "$SCRIPT" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
if [ ! -f "$SCRIPT" ] || [ -z "$ROOT" ] || [ ! -d "$VAULT/hypr" ] || [ ! -f "$VAULT/README.md" ]; then
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
    exec bash "$CLONE_DIR/legacy-ai-help-version.sh" "$@" < "$TTY"
fi

say "Arch-Linux-Vault: OLD AI-made rice (legacy-ai/)"
info "Vault:   $VAULT"
info "Home:    $HOME"
[ "$DO_PACKAGES" -eq 1 ] && info "1. install programs (pacman --needed, AUR via yay)"
info "2. back up files that get replaced to: $BACKUP"
info "3. copy all config files from the vault (existing ones are replaced)"
info "4. extras: bluetooth at boot, Nautilus as file manager, SDDM theme, font cache"

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
            warn "$p skipped: needs the [multilib] repo (see README, Install the programs)"
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

# single files -> ~/.config (starship prompt, default apps like Nautilus for folders)
put_file "$VAULT/starship.toml" "$HOME/.config/starship.toml"
put_file "$VAULT/mimeapps.list" "$HOME/.config/mimeapps.list"

# home/ -> ~ (scripts in ~/.local/bin, Quickshell settings, ~/.zshrc)
while IFS= read -r -d '' f; do
    rel="${f#"$VAULT"/home/}"
    skip=0
    for s in "${SKIP_HOME[@]}"; do
        case "$rel" in "$s"*) skip=1 ;; esac
    done
    [ "$skip" -eq 1 ] && continue
    # ~/.zshrc I keep up to date myself: only copied when there is none yet
    if [ "$rel" = ".zshrc" ] && [ -e "$HOME/.zshrc" ]; then
        info "~/.zshrc exists, left as it is"
        continue
    fi
    put_file "$f" "$HOME/$rel"
done < <(find "$VAULT/home" -type f -print0)

# scripts must be executable
chmod +x "$HOME"/.local/bin/* "$HOME"/.local/bin/kitty-shell/zsh 2>/dev/null || true

info "$COPIED files copied, $BACKED_UP old versions backed up"
[ "$BACKED_UP" -gt 0 ] && info "backup: $BACKUP"

# files outside the home folder (need sudo)
for f in "$VAULT"/etc/sudoers.d/*; do
    target="/etc/sudoers.d/$(basename "$f")"
    # visudo checks the file first: a broken sudoers file would lock you out of sudo
    if sudo visudo -cf "$f" >/dev/null; then
        sudo install -m 0440 -o root -g root "$f" "$target"
        info "installed $target"
    else
        warn "$target skipped: visudo found an error"
    fi
done

# ---- 4. extras -----------------------------------------------------------

say "4. Extras"

if command -v systemctl >/dev/null && systemctl list-unit-files bluetooth.service >/dev/null 2>&1; then
    sudo systemctl enable --now bluetooth.service && info "bluetooth starts at boot"
fi
if command -v xdg-mime >/dev/null; then
    xdg-mime default org.gnome.Nautilus.desktop inode/directory && info "Nautilus is the default file manager"
fi
if command -v gsettings >/dev/null; then
    # no blueman icon in the tray (Waybar has its own bluetooth module)
    gsettings set org.blueman.general plugin-list "['!StatusNotifierItem']" 2>/dev/null \
        && info "blueman tray icon off"
fi
if command -v gsettings >/dev/null; then
    # GTK 4 / libadwaita apps (Nautilus) take their font from here, not from settings.ini
    gsettings set org.gnome.desktop.interface font-name 'Noto Sans 10' 2>/dev/null \
        && gsettings set org.gnome.desktop.interface document-font-name 'Noto Sans 10' 2>/dev/null \
        && gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null \
        && gsettings set org.gnome.desktop.interface icon-theme 'rice' 2>/dev/null \
        && gsettings set org.gnome.desktop.interface gtk-theme 'Back-In-Black' 2>/dev/null \
        && gsettings set org.gnome.desktop.interface cursor-theme 'breeze_cursors' 2>/dev/null \
        && gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null \
        && gsettings set org.gnome.desktop.interface font-antialiasing 'grayscale' 2>/dev/null \
        && info "GTK: font Noto Sans (no subpixel), dark mode, theme Back-In-Black, icons rice, cursor breeze"
fi
if [ -d /usr/share/sddm ]; then
    # SDDM only reads themes from /usr/share/sddm/themes, and runs as its own user "sddm":
    # copy the theme there and make it readable for everyone (a+rX)
    sudo mkdir -p /usr/share/sddm/themes/rice
    sudo cp -r "$VAULT"/sddm/rice/. /usr/share/sddm/themes/rice/
    sudo chmod -R a+rX /usr/share/sddm/themes/rice
    sudo install -Dm644 "$VAULT/etc/sddm.conf.d/theme.conf" /etc/sddm.conf.d/theme.conf
    # /etc/sddm.conf wins over sddm.conf.d. Other themes write into it (backup .bak-rice):
    #  - Current=<other theme>      -> Current=rice
    #  - InputMethod=... and GreeterEnvironment=...QT_IM_MODULE=qtvirtualkeyboard (e.g. theme "silent")
    #    put a huge virtual keyboard over every theme -> empty / commented out
    if [ -f /etc/sddm.conf ]; then
        sudo sed -i.bak-rice \
            -e 's/^Current=.*/Current=rice/' \
            -e 's/^InputMethod=.*/InputMethod=/' \
            -e 's/^GreeterEnvironment=/#GreeterEnvironment=/' \
            /etc/sddm.conf
    fi
    info "SDDM theme rice installed and selected"
    # start SDDM at boot (fails harmlessly if another display manager is already enabled)
    if sudo systemctl enable sddm.service 2>/dev/null; then
        info "SDDM starts at boot"
    else
        warn "SDDM not enabled: another display manager is active (disable it first)"
    fi
fi
if command -v fc-cache >/dev/null; then
    fc-cache -f >/dev/null && info "font cache rebuilt"
fi

say "Done"
info "Log out and back in (or reboot) so Hyprland, Waybar and the environment variables load."
info "Bluetooth headphones: mark them as Trusted once in blueman, then they connect by themselves."
