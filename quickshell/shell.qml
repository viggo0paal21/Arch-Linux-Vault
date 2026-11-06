//@ pragma ShellId oled-bw
// Otherwise Qt uses the "basic" mode on NVIDIA, which computes animations at a fixed ~60 Hz.
// "threaded" computes per display frame (170 Hz). If a tray menu ever hangs: remove this line.
//@ pragma Env QSG_RENDER_LOOP=threaded

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.background
import qs.modules.bar
import qs.modules.launcher
import qs.modules.controlcenter
import qs.modules.dashboard
import qs.modules.notifications
import qs.modules.osd
import qs.modules.power
import qs.modules.settings

// OLED black/white Quickshell setup
// Start: qs   |   control via IPC: qs ipc call <target> <function>
ShellRoot {
    id: shell

    // Background (black or image) on every screen
    Variants {
        model: Config.opts.oledBackground ? Quickshell.screens : []

        Wallpaper {}
    }

    // Bar on every screen
    // "Shell glass" (Settings > Bar) recreates the bars, because the layer namespace
    // (Hyprland rules) can only be set when the window is created.
    Variants {
        model: Config.opts.barShellGlass ? [] : Quickshell.screens

        Bar {}
    }

    Variants {
        model: Config.opts.barShellGlass ? Quickshell.screens : []

        Bar {
            glassMode: true
        }
    }

    // Rounded screen corners (optional)
    Variants {
        model: Config.opts.screenCorners ? Quickshell.screens : []

        ScreenCorners {}
    }

    Launcher {}
    ControlCenter {}
    Dashboard {}
    PowerMenu {}
    SettingsPanel {}
    NotifPopups {}
    Osd {}
    FpsOverlay {}

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            Ui.toggle("launcher", null);
        }

        function open(): void {
            Ui.open("launcher", null);
        }

        function close(): void {
            Ui.close();
        }
    }

    IpcHandler {
        target: "control"

        function toggle(): void {
            Ui.toggle("control", null);
        }
    }

    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            Ui.toggle("dashboard", null);
        }
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            Ui.toggle("power", null);
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            Ui.toggle("settings", null);
        }
    }

    IpcHandler {
        target: "panels"

        function close(): void {
            Ui.close();
        }
    }

    IpcHandler {
        target: "audio"

        function up(): void {
            Audio.up();
        }

        function down(): void {
            Audio.down();
        }

        function mute(): void {
            Audio.toggleMute();
        }

        function micMute(): void {
            Audio.toggleMicMute();
        }
    }

    IpcHandler {
        target: "notifs"

        function dnd(): void {
            Notifs.toggleDnd();
        }

        function clear(): void {
            Notifs.clearAll();
        }
    }
}
