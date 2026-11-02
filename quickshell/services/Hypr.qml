pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Hyprland-Befehle, die mit Lua-Config (>= 0.55) und alter Config funktionieren.
Singleton {
    id: root

    readonly property bool lua: Hyprland.usingLua

    // Fenster auf der aktiven Arbeitsflaeche des fokussierten Monitors, ohne schwebende (floating)
    readonly property int focusedTiledCount: root.tiledCount(Hyprland.focusedMonitor)

    // Fenster auf der aktiven Arbeitsflaeche eines Monitors, schwebende (floating) nicht mitgezaehlt
    function tiledCount(monitor) {
        const ws = monitor ? monitor.activeWorkspace : null;
        if (!ws)
            return 0;
        let n = 0;
        for (const t of ws.toplevels.values) {
            const o = t.lastIpcObject;
            if (!(o && o.floating))
                n++;
        }
        return n;
    }

    function refresh() {
        if (typeof Hyprland.refreshToplevels === "function")
            Hyprland.refreshToplevels();
    }

    Component.onCompleted: root.refresh()

    // Ob ein Fenster schwebt, steht nur in lastIpcObject. Das aktualisiert Hyprland nicht
    // von selbst, darum bei passenden Ereignissen neu abfragen.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const n = event.name;
            if (n === "openwindow" || n === "closewindow" || n === "changefloatingmode" || n === "movewindowv2" || n === "workspacev2" || n === "focusedmonv2")
                root.refresh();
        }
    }

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
