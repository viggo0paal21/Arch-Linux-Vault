pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

// Hyprland commands that work with the Lua config (>= 0.55) and the old config.
Singleton {
    id: root

    readonly property bool lua: Hyprland.usingLua

    // Windows on the active workspace of the focused monitor, without floating ones
    readonly property int focusedTiledCount: root.tiledCount(Hyprland.focusedMonitor)

    // Windows on the active workspace of a monitor, floating ones not counted.
    // skipKitty: kitty terminals don't count either (Settings > Appearance > Exclude kitty terminal)
    function tiledCount(monitor, skipKitty) {
        const ws = monitor ? monitor.activeWorkspace : null;
        if (!ws)
            return 0;
        let n = 0;
        for (const t of ws.toplevels.values) {
            const o = t.lastIpcObject;
            // Only count once Hyprland has reported that it isn't floating. Otherwise a newly
            // opened floating window briefly counts as tiled and the bar twitches.
            if (o && o.floating === false && !(skipKitty && (o.class === "kitty" || o.initialClass === "kitty")))
                n++;
        }
        return n;
    }

    function refresh() {
        if (typeof Hyprland.refreshToplevels === "function")
            Hyprland.refreshToplevels();
    }

    Component.onCompleted: {
        root.refresh();
        blurApply.restart();
    }

    // Window blur (decoration:blur size/passes) from Settings > Appearance > Blur size / Blur passes.
    // Set at runtime ("hyprctl eval" with the Lua config), hyprland.lua stays unchanged.
    // Runtime values are lost on "hyprctl reload" -> set them again on start and after every reload.
    readonly property int blurSize: Config.opts.hyprBlurSize
    readonly property int blurPasses: Config.opts.hyprBlurPasses
    onBlurSizeChanged: blurApply.restart()
    onBlurPassesChanged: blurApply.restart()

    Timer {
        id: blurApply

        interval: 150
        onTriggered: root.applyBlur()
    }

    function applyBlur() {
        const s = Math.max(0, Math.round(root.blurSize));
        const p = Math.max(1, Math.min(8, Math.round(root.blurPasses)));
        if (root.lua)
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { blur = { size = " + s + ", passes = " + p + " } } })"]);
        else
            Quickshell.execDetached(["hyprctl", "--batch", "keyword decoration:blur:size " + s + " ; keyword decoration:blur:passes " + p]);
    }

    // Whether a window floats is only in lastIpcObject. Hyprland doesn't update it
    // by itself, so query again on matching events.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const n = event.name;
            if (n === "openwindow" || n === "closewindow" || n === "changefloatingmode" || n === "movewindowv2" || n === "workspacev2" || n === "focusedmonv2")
                root.refresh();
            else if (n === "configreloaded")
                blurApply.restart();
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
