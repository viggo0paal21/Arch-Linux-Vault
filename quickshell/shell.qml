//@ pragma ShellId oled-bw
// Qt nutzt auf NVIDIA sonst den "basic"-Modus, der Animationen mit festen ~60 Hz rechnet.
// "threaded" rechnet pro Bildschirm-Frame (170 Hz). Falls sich ein Tray-Menue mal aufhaengt: Zeile entfernen.
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

// OLED Schwarz/Weiss Quickshell-Setup
// Start: qs   |   Steuerung per IPC: qs ipc call <ziel> <funktion>
ShellRoot {
    id: shell

    // Hintergrund (schwarz oder Bild) auf jedem Bildschirm
    Variants {
        model: Config.opts.oledBackground ? Quickshell.screens : []

        Wallpaper {}
    }

    // Leiste auf jedem Bildschirm
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // Abgerundete Bildschirmecken (optional)
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
