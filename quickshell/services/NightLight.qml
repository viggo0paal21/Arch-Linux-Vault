pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Nachtlicht ueber hyprsunset (optional, "pacman -S hyprsunset").
Singleton {
    id: root

    property bool active: false
    property bool installed: false
    property int temperature: 4500

    function toggle() {
        if (!root.installed)
            return;
        if (root.active) {
            Quickshell.execDetached(["pkill", "-x", "hyprsunset"]);
            root.active = false;
        } else {
            Quickshell.execDetached(["hyprsunset", "-t", String(root.temperature)]);
            root.active = true;
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v hyprsunset >/dev/null 2>&1 || exit 2; pgrep -x hyprsunset >/dev/null 2>&1"]
        onExited: (code, status) => {
            root.installed = code !== 2;
            root.active = code === 0;
        }
    }
}
