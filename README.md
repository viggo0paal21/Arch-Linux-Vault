# config-backup

Backup meiner `~/.config`-Ordner (Arch Linux / Hyprland), erstellt am 28.10.2026.

Wiederherstellen: gewünschten Ordner zurück nach `~/.config/` kopieren.


das in /etc/environment:
MANGOHUD=1
MANGOHUD_DLSYM=1
LD_PRELOAD=/usr/$LIB/mangohud/libMangoHud_opengl.so
__GL_SYNC_TO_VBLANK=1
MANGOHUD_CONFIG=read_cfg,no_display,legacy_layout=1

<!-- INSTALL-START -->

## Programme installieren

_Automatisch erzeugt am 28.10.2026 – offizielle Pakete über pacman, der Rest über yay (AUR)._

| Ordner | Wofür | Pakete |
|---|---|---|
| autostart | Programme, die beim Login automatisch starten | – (kein Paket nötig) |
| fastfetch | Systeminfo im Terminal | `fastfetch` |
| fontconfig | Schriftarten-Einstellungen | `fontconfig`, `ttf-jetbrains-mono-nerd` |
| gtk-3.0 | GTK-3-Design | `gtk3` |
| gtk-4.0 | GTK-4-Design | `gtk4` |
| hypr | Hyprland + Hypr-Tools | `hyprland`, `hyprlauncher`, `hyprlock`, `hyprsunset`, `hyprpicker` |
| hyprpanel | HyprPanel (Leiste) | `ags-hyprpanel-git` (AUR) |
| kitty | Terminal | `kitty` |
| Kvantum | Qt-Design-Engine | `kvantum`, `kvantum-qt5` |
| MangoHud | FPS-/Leistungs-Overlay für Spiele | `mangohud`, `lib32-mangohud` |
| nautilus | Dateimanager | `nautilus` |
| nwg-look | GTK-Einstellungs-Tool | `nwg-look` |
| qt6ct | Qt6-Design-Einstellungen | `qt6ct` |
| swaync | Benachrichtigungen | `swaync` |
| vibrantLinux | Farbsättigung pro Programm | `vibrantlinux` (AUR) |
| waybar | Statusleiste | `waybar`, `blueman`, `pavucontrol` |
| waypaper | Hintergrundbild-Auswahl | `waypaper` (AUR), `swww` (AUR), `swaybg` |
| xdg-desktop-portal | Portale (Screensharing, Dateiauswahl) | `xdg-desktop-portal`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` |
| zshrc.d | Zsh-Shell | `zsh`, `starship` |

### Alles auf einmal installieren

**1. Offizielle Pakete (pacman):**

```bash
sudo pacman -Syu --needed fastfetch fontconfig ttf-jetbrains-mono-nerd gtk3 gtk4 hyprland hyprlauncher hyprlock hyprsunset hyprpicker kitty kvantum kvantum-qt5 mangohud lib32-mangohud nautilus nwg-look qt6ct swaync waybar blueman pavucontrol swaybg xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk zsh starship
```

> `lib32-…`-Pakete brauchen das **multilib**-Repo. Falls pacman sie nicht findet:
> in `/etc/pacman.conf` die Zeilen `[multilib]` und `Include = /etc/pacman.d/mirrorlist` darunter einkommentieren.

**2. AUR-Pakete (yay):**

```bash
yay -S --needed ags-hyprpanel-git vibrantlinux waypaper swww
```

Falls yay noch fehlt:

```bash
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin && makepkg -si && cd .. && rm -rf yay-bin
```

## Configs zurückspielen

> Achtung: Vorhandene Configs mit gleichem Namen werden überschrieben.

```bash
git clone https://github.com/viggo0paal21/config-backup.git ~/config-backup
cd ~/config-backup

# einzelnen Ordner zurückspielen, z. B. MangoHud:
cp -r MangoHud ~/.config/

# oder alle Ordner auf einmal:
for d in */; do cp -r "$d" ~/.config/; done
```

<!-- INSTALL-END -->
