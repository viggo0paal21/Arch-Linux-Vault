# Quickshell Guide

My own Quickshell shell ("oled-bw"): black and white, slightly rounded, Inter 15px bold,
smooth animations at the full **170 Hz** on an NVIDIA card. It replaces Waybar, swaync and rofi.

- [1. Files in this repo](#1-files-in-this-repo)
- [2. Install / restore](#2-install--restore)
- [3. Why the start script exists (NVIDIA)](#3-why-the-start-script-exists-nvidia)
- [4. Measuring the frame rate](#4-measuring-the-frame-rate)
- [5. Other Quickshell shells (Caelestia, Noctalia, ...)](#5-other-quickshell-shells-caelestia-noctalia-)
- [6. AMD / Intel](#6-amd--intel)
- [7. Troubleshooting and rollback](#7-troubleshooting-and-rollback)

---

## 1. Files in this repo

| File | Goes to | What it is |
|---|---|---|
| [`quickshell/`](quickshell) | `~/.config/quickshell/` | The shell itself (bar, launcher, control center, dashboard, notifications, OSD, power menu, settings) |
| [`home/.local/bin/qs-start`](home/.local/bin/qs-start) | `~/.local/bin/` | Start script used by Hyprland's autostart: Vulkan, without MangoHud / lsfg-vk / vkBasalt |
| [`home/.local/bin/qs`](home/.local/bin/qs), [`quickshell`](home/.local/bin/quickshell) | `~/.local/bin/` | Wrappers: same fix for **every** `qs` / `quickshell` call, any config |
| [`home/.local/share/dbus-1/services/org.freedesktop.Notifications.service`](home/.local/share/dbus-1/services/org.freedesktop.Notifications.service) | `~/.local/share/dbus-1/services/` | Stops swaync / dunst / mako from being auto-started by D-Bus and taking the notification server away from Quickshell (see section 7) |
| [`home/.local/state/quickshell/by-shell/oled-bw/settings.json`](home/.local/state/quickshell/by-shell/oled-bw/settings.json) | `~/.local/state/quickshell/by-shell/oled-bw/` | My saved shell settings (radius, bar, font, animation speed, FPS counter, ...) |
| [`hypr/hyprland.lua`](hypr/hyprland.lua) | `~/.config/hypr/` | Autostart runs `qs-start` (Waybar and swaync are commented out), `Super + R` opens the Quickshell launcher |
| [`quickshell/hyprland-quickshell.lua`](quickshell/hyprland-quickshell.lua) | (template) | Keybind and layer-rule snippets for `hyprland.lua` |

Changes made for smooth 170 Hz (all inside `quickshell/`):

| File | Change |
|---|---|
| `components/OverlayPanel.qml` | Closed panels stay mapped but invisible and click-through, so opening one no longer creates a new window (that caused a ~90 ms hitch). When a fullscreen window is active they are unmapped, so direct scanout and tearing in games keep working. |
| `components/DropdownSlot.qml` | Dashboard and control center slide down from under the bar |
| `modules/dashboard/Dashboard.qml` | The dashboard clock only ticks while the dashboard is open |
| `FpsOverlay.qml`, `config/Config.qml`, `modules/settings/SettingsPanel.qml` | FPS counter, switchable in Settings → Behavior → **FPS counter** |

## 2. Install / restore

```bash
sudo pacman -S --needed quickshell inter-font ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols
# optional, used by the shell: hyprlock hyprsunset networkmanager bluez bluez-utils blueman nvidia-utils

cd ~/config-backup
cp -r quickshell ~/.config/
cp hypr/hyprland.lua ~/.config/hypr/
mkdir -p ~/.local/bin ~/.local/state/quickshell/by-shell/oled-bw
cp home/.local/bin/qs-start home/.local/bin/qs home/.local/bin/quickshell ~/.local/bin/
chmod +x ~/.local/bin/qs-start ~/.local/bin/qs ~/.local/bin/quickshell
cp home/.local/state/quickshell/by-shell/oled-bw/settings.json ~/.local/state/quickshell/by-shell/oled-bw/
mkdir -p ~/.local/share/dbus-1/services
cp home/.local/share/dbus-1/services/org.freedesktop.Notifications.service ~/.local/share/dbus-1/services/
```

Log out and back in. Then check:

```bash
which qs quickshell        # both must be ~/.local/bin/..., not /usr/bin/...
for p in $(pgrep -x 'qs|quickshell'); do echo "$p: $(grep -ci mangohud /proc/$p/maps)"; done   # must print 0
```

If `which` shows `/usr/bin/...`, `~/.local/bin` is too late in your `PATH`. Add this to the top of `hyprland.lua`:

```lua
hl.env("PATH", os.getenv("HOME") .. "/.local/bin:" .. os.getenv("PATH"))
```

Only one notification daemon can run: keep `swaync`, `dunst` and `mako` out of the autostart.

## 3. Why the start script exists (NVIDIA)

Symptom: shell animations never felt like 170 Hz. Measured: **85 fps**, and **90–100 ms** hitches when opening a panel.
Three problems stacked on top of each other:

1. **MangoHud inside the shell.** `/etc/environment` loads MangoHud into every OpenGL program via `LD_PRELOAD`
   (that is how all games get the FPS cap without launch options, see [README → Global MangoHud](README.md#global-mangohud-system-wide)).
   Quickshell got it too, including the FPS cap and an extra vsync.
2. **Qt + OpenGL on NVIDIA.** Qt disables threaded OpenGL rendering when the GL vendor is NVIDIA
   ([QTBUG-95817](https://bugreports.qt.io/browse/QTBUG-95817), resize freeze) and falls back to the *basic* render loop,
   which drives animations with a fixed ~16 ms timer (~60 Hz). Forcing `QSG_RENDER_LOOP=threaded` gave exactly 85 fps
   (half of 170: every frame waited for two refreshes). Details: [omarchy issue #7268](https://github.com/omacom/omarchy/issues/7268).
3. **Panels were recreated on every open** (new Wayland surface + swapchain), which blocked the shell for ~90 ms.

Fix:

- `QSG_RHI_BACKEND=vulkan`: on Vulkan the threaded render loop is Qt's default and the driver does vsync like in games → stable 170 fps.
- `MANGOHUD=0`, `unset LD_PRELOAD`, `DISABLE_LSFGVK=1`, `DISABLE_VKBASALT=1`: keeps the game layers out of the shell. Games are unchanged.
- Panels stay mapped (see the table in section 1).

Result: constant **170 fps**, longest gap between two frames **~7 ms**, also while opening panels.

| What I tried (OpenGL) | Result |
|---|---|
| Default (basic loop on NVIDIA) | animations at ~60 Hz |
| `QSG_RENDER_LOOP=threaded` | exactly 85 fps |
| + `__GL_SYNC_TO_VBLANK=0` | 85 fps |
| `QSG_NO_VSYNC=1` + driver vsync | once 170, not reproducible, back to 85 |
| **Vulkan** | **stable 170 fps, max 7 ms** |

## 4. Measuring the frame rate

Settings → Behavior → **FPS counter**, or:

```bash
qs ipc call fps toggle
```

The box under the bar shows `fps` (frames actually sent to Hyprland, counted against the real clock)
and `max` (longest gap between two frames in the last second). The line at the bottom moves constantly, so you can also see
whether motion is even. Good values on a 170 Hz monitor: **~170 fps, max ~6–8 ms**.

## 5. Other Quickshell shells (Caelestia, Noctalia, ...)

**Vulkan / no MangoHud:** automatic. The `qs` and `quickshell` wrappers in `~/.local/bin` apply the fix to every config:

```bash
qs -c caelestia
~/.local/bin/qs-start -c <name>      # same thing, explicit
```

Shells with their own launcher (e.g. `caelestia shell -d`) find the wrappers as long as `~/.local/bin` is first in Hyprland's `PATH` (section 2).
Otherwise put the variables in front of their start command:

```bash
env -u LD_PRELOAD MANGOHUD=0 DISABLE_LSFGVK=1 DISABLE_VKBASALT=1 QSG_RHI_BACKEND=vulkan <start command>
```

Check once per new shell that it doesn't force its own backend:

```bash
grep -rn "pragma Env" ~/.config/quickshell/<name>/shell.qml   # QSG_RHI_BACKEND=opengl would override the wrapper
```

**Panel hitch:** that is code inside each shell. Measure first with this portable counter: save it as `FpsOverlay.qml`
next to the other shell's `shell.qml`, add `FpsOverlay {}` to its root block (`ShellRoot { ... }` or `Scope { ... }`),
then `qs -c <name> ipc call fps toggle`. If `max` jumps to 50 ms or more when opening a panel, that shell recreates
its panel windows and needs the same change as `components/OverlayPanel.qml`.

<details>
<summary>Portable <code>FpsOverlay.qml</code> (works without this shell's theme files)</summary>

```qml
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Portable FPS counter for any Quickshell config.
// Toggle: qs ipc call fps toggle   (named config: qs -c <name> ipc call fps toggle)
PanelWindow {
    id: root

    property bool shown: false
    property int frames: 0
    property real last: Date.now()
    property real prev: 0
    property real worst: 0

    visible: root.shown
    color: "transparent"
    implicitWidth: 190
    implicitHeight: 32
    anchors { top: true; right: true }
    margins { top: 60; right: 8 }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-fps"
    mask: Region {}

    Rectangle {
        id: box
        anchors.fill: parent
        color: "#000000"
        border.width: 1
        border.color: "#2e2e2e"
        radius: 5
        clip: true

        Text {
            id: label
            anchors.centerIn: parent
            color: "#ffffff"
            font.pixelSize: 15
            font.bold: true
            text: "– fps"
        }

        Rectangle {
            id: sweep
            y: box.height - 3
            width: 12
            height: 2
            color: "#ffffff"
            NumberAnimation on x {
                running: root.shown
                from: 0
                to: box.width - sweep.width
                duration: 1000
                loops: Animation.Infinite
            }
        }
    }

    Connections {
        target: label.Window.window
        function onFrameSwapped() {
            const t = Date.now();
            if (root.prev > 0)
                root.worst = Math.max(root.worst, t - root.prev);
            root.prev = t;
            root.frames++;
        }
    }

    Timer {
        interval: 1000
        running: root.shown
        repeat: true
        onTriggered: {
            const now = Date.now();
            const dt = now - root.last;
            label.text = Math.round(root.frames * 1000 / dt) + " fps  ·  max " + Math.round(root.worst) + " ms";
            root.frames = 0;
            root.worst = 0;
            root.last = now;
        }
    }

    onShownChanged: {
        root.frames = 0;
        root.worst = 0;
        root.prev = 0;
        root.last = Date.now();
        label.text = "– fps";
    }

    IpcHandler {
        target: "fps"
        function toggle(): void { root.shown = !root.shown; }
    }
}
```

</details>

## 6. AMD / Intel

The OpenGL problem (point 2 in section 3) only exists on NVIDIA. On Mesa drivers (AMD, Intel) Qt already uses the
threaded loop with OpenGL, so Vulkan brings no gain there, but it also works fine. Keep the MangoHud / lsfg-vk / vkBasalt
lines on every GPU: with Vulkan, a global `MANGOHUD=1` would otherwise load MangoHud's Vulkan layer into the shell.

To use Vulkan only on NVIDIA, replace the backend line in `qs-start` and both wrappers with:

```bash
[ -e /proc/driver/nvidia/version ] && export QSG_RHI_BACKEND=vulkan
```

NVIDIA-only parts to change after switching to AMD: Settings → *GPU monitor (nvidia-smi)*, the NVIDIA max-clock setup
([`nvidia-maxperf-setup.sh`](nvidia-maxperf-setup.sh) → [`amdgpu-maxperf-setup.sh`](amdgpu-maxperf-setup.sh)) and `__GL_SYNC_TO_VBLANK` in `/etc/environment`.

## 7. Troubleshooting and rollback

| Problem | Fix |
|---|---|
| Shell frozen | `pkill -9 -x 'qs\|quickshell'`, then `setsid -f ~/.local/bin/qs-start >/dev/null 2>&1`. Make sure only one instance runs: `pgrep -ax 'qs\|quickshell'` |
| Problems with Vulkan | Remove the `QSG_RHI_BACKEND=vulkan` line from `qs-start` and the wrappers (OpenGL, ~60 Hz animations, but stable) |
| `qt.qpa.wayland.textinput: ... disableSurface ... but 0x0 is focused` when opening or closing a panel | Harmless: panels take the keyboard while open (Esc, typing in the launcher). When they release it, Qt's text-input bookkeeping (for input methods) has already moved on and warns. Typing still works. Hidden by the start script and wrappers with `qt.qpa.wayland.textinput.warning=false` |
| No notifications / `Could not register notification server` | Another daemon owns the notification server. Find it with `busctl --user status org.freedesktop.Notifications \| grep -E '^(PID\|Comm)='`, kill it, restart Quickshell. To stop D-Bus from auto-starting swaync / dunst / mako again (e.g. when an app sends a notification while Quickshell is down), install the override file from section 1 and reload D-Bus: `busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig` |
| Logs | `qs log` |
| Log full of `qt.svg.draw: The requested buffer size is too big, ignoring` or `qt.svg: Invalid path data` | Harmless warnings about broken SVG icons: masks with an empty area (Qt can't allocate a 0-pixel buffer) or invalid path data (drawn up to the broken part). The start script and wrappers hide them with `QT_LOGGING_RULES=qt.svg*.warning=false` |
| Back to Waybar + swaync + rofi | In `hyprland.lua`: comment out the `qs-start` line, remove the `--` in front of `waybar &` and `swaync &`, set `Super + R` back to `hl.dsp.exec_cmd(menu)`. Also `rm ~/.local/share/dbus-1/services/org.freedesktop.Notifications.service` |
| Remove the wrappers | `rm ~/.local/bin/qs ~/.local/bin/quickshell` (the real commands are in `/usr/bin`) |

Kill all instances and start fresh with a pause in between, otherwise `qs ipc` may still reach the old instance:

```bash
qs kill; sleep 1
setsid -f ~/.local/bin/qs-start >/dev/null 2>&1; sleep 2
```
