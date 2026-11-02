pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Hyprland-Befehle, die mit Lua-Config (>= 0.55) und alter Config funktionieren.
Singleton {
    id: root

    readonly property bool lua: Hyprland.usingLua

    function workspace(target) {
        const t = String(target).replace(/["\\]/g, "");
        if (root.lua)
            Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + t + "\" })");
        else
            Hyprland.dispatch("workspace " + t);
    }

    function exit() {
        if (root.lua)
            Hyprland.dispatch("hl.dsp.exit()");
        else
            Hyprland.dispatch("exit");
    }
}
