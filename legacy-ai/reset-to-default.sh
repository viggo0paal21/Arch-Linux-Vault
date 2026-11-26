#!/usr/bin/env bash
# reset-to-default.sh: puts my rice back to the programs' own defaults, so I can
# build everything again myself (with the wikis). Nothing is deleted:
# every file is MOVED into a backup folder, ~/rice-reset-backup-<date>/,
# with the same folder structure as in ~.
#
# Stays as it is:  ~/.config/hypr/  (hyprland.lua, system.lua, performance.lua ...)
#                  ~/.zshrc, app data (Zen profile, Discord, Steam ...)
# Moved away:      everything in the lists below
# Reset:           gsettings for theme, icons, cursor, font; SDDM back to its default theme
#
# Old AI rice back afterwards: ~/config-backup/legacy-ai-help-version.sh  (my own rice: ~/config-backup/install.sh)
# Or only this backup back:    cp -a ~/rice-reset-backup-<date>/. ~/
#
# Run:  ./reset-to-default.sh          (asks before it starts)

set -u

BACKUP="$HOME/rice-reset-backup-$(date +%Y%m%d-%H%M%S)"

# ---- what gets moved (paths relative to ~) ----------------------------------
# Edit these lists if you want to keep something.
PATHS=(
    .config/waybar
    .config/rofi
    .config/swaync
    .config/kitty
    .config/gtk-3.0
    .config/gtk-4.0
    .config/xsettingsd
    .config/qt6ct
    .config/Kvantum
    .config/fastfetch
    .config/fetch
    .config/waypaper
    .config/cava
    .config/sddm
    .config/fontconfig
    .config/MangoHud
    .config/starship.toml
    .config/mimeapps.list
    .config/Vencord/themes
    .config/xdg-desktop-portal
    .config/systemd/user/xdg-desktop-portal-gtk.service.d
    .config/hypr/hyprlock.conf
    .local/share/icons/rice
    .local/share/icons/default/index.theme
    .local/share/applications/zen.desktop
    .local/bin/wallpaper-restore
    .local/bin/dock
    .local/bin/dock-autohide
    .themes/Back-In-Black
    .gtkrc-2.0
)

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }

say "Reset to defaults"
info "Moved to $BACKUP (nothing is deleted):"
for p in "${PATHS[@]}"; do [ -e "$HOME/$p" ] && info "  ~/$p"; done
info "Stays: ~/.config/hypr/hyprland.lua (and the rest of ~/.config/hypr), ~/.zshrc"
info "Reset: gsettings (GTK theme, icons, cursor, font), SDDM theme (needs sudo)"
printf '\n    Continue? [y/N] '
read -r answer < /dev/tty
case "$answer" in y|Y|j|J) ;; *) info "nothing changed"; exit 0 ;; esac

# ---- 1. move files ----------------------------------------------------------
say "1. Moving files"
moved=0
for p in "${PATHS[@]}"; do
    [ -e "$HOME/$p" ] || continue
    mkdir -p "$BACKUP/$(dirname "$p")"
    mv "$HOME/$p" "$BACKUP/$p" && moved=$((moved + 1))
done
info "$moved moved to $BACKUP"

# ---- 2. gsettings back to GNOME's defaults ----------------------------------
say "2. gsettings"
if command -v gsettings >/dev/null; then
    for key in gtk-theme icon-theme cursor-theme cursor-size font-name document-font-name \
               font-antialiasing font-rgba-order color-scheme; do
        gsettings reset org.gnome.desktop.interface "$key" 2>/dev/null
    done
    gsettings reset org.blueman.general plugin-list 2>/dev/null
    info "theme, icons, cursor, font, dark mode reset"
fi

# ---- 3. SDDM back to its default theme ---------------------------------------
say "3. SDDM"
if [ -f /etc/sddm.conf.d/theme.conf ]; then
    sudo mv /etc/sddm.conf.d/theme.conf /etc/sddm.conf.d/theme.conf.bak-reset && info "/etc/sddm.conf.d/theme.conf -> .bak-reset"
fi
if [ -f /etc/sddm.conf ] && grep -q '^Current=' /etc/sddm.conf; then
    # empty Current= = SDDM's built-in default theme (backup .bak-reset)
    sudo sed -i.bak-reset 's/^Current=.*/Current=/' /etc/sddm.conf && info "/etc/sddm.conf: Current= emptied"
fi
info "the theme files in /usr/share/sddm/themes/rice stay (unused)"

# ---- done --------------------------------------------------------------------
say "Done"
info "Log out and back in (or reboot): apps only read their configs at start."
info "Backup: $BACKUP"
info "Old AI rice back: ~/config-backup/legacy-ai-help-version.sh   (my own rice: ~/config-backup/install.sh)"
