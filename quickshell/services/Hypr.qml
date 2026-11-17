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
    // skipKitty: kitty terminals don't count either (Settings > Quickshell > Bar > Exclude kitty terminal)
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
        overrideApply.restart();
        opacityApply.restart();
    }

    // Settings > Hyprland: values Quickshell applies at runtime on top of hyprland.lua (blur, rounding, shadows,
    // direct scanout). Set with "hyprctl eval" for the Lua config, hyprland.lua stays unchanged. -1 = not
    // set, then hyprland.lua applies. Runtime values are lost on "hyprctl reload" -> set them again at start and after every
    // reload. If a value is reset (set -> -1), Hyprland reloads: then the value from hyprland.lua applies again,
    // and after the reload the remaining own values are applied on top again.
    readonly property int blurSize: Config.opts.hyprBlurSize
    readonly property int blurPasses: Config.opts.hyprBlurPasses
    readonly property int rounding: Config.opts.hyprRounding
    readonly property int shadow: Config.opts.hyprShadow
    readonly property int scanout: Config.opts.hyprDirectScanout
    readonly property string overrideKey: [root.blurSize, root.blurPasses, root.rounding, root.shadow, root.scanout].join(",")
    property string appliedKey: ""
    onOverrideKeyChanged: overrideApply.restart()

    Timer {
        id: overrideApply

        interval: 150
        onTriggered: root.applyOverrides()
    }

    function applyOverrides() {
        const prev = root.appliedKey;
        root.appliedKey = root.overrideKey;
        if (prev !== "") {
            const a = prev.split(",");
            const b = root.overrideKey.split(",");
            for (let i = 0; i < a.length; i++) {
                if (Number(a[i]) >= 0 && Number(b[i]) < 0) {
                    Quickshell.execDetached(["hyprctl", "reload"]);
                    return;
                }
            }
        }
        root.pushOverrides();
    }

    function pushOverrides() {
        const dec = [];
        const kw = [];
        if (root.rounding >= 0) {
            dec.push("rounding = " + Math.round(root.rounding));
            kw.push("keyword decoration:rounding " + Math.round(root.rounding));
        }
        if (root.shadow >= 0) {
            dec.push("shadow = { enabled = " + (root.shadow > 0 ? "true" : "false") + " }");
            kw.push("keyword decoration:shadow:enabled " + (root.shadow > 0 ? "true" : "false"));
        }
        const blur = [];
        if (root.blurSize >= 0) {
            blur.push("size = " + Math.round(root.blurSize));
            kw.push("keyword decoration:blur:size " + Math.round(root.blurSize));
        }
        if (root.blurPasses >= 0) {
            const p = Math.max(1, Math.min(8, Math.round(root.blurPasses)));
            blur.push("passes = " + p);
            kw.push("keyword decoration:blur:passes " + p);
        }
        if (blur.length > 0)
            dec.push("blur = { " + blur.join(", ") + " }");
        const parts = [];
        if (dec.length > 0)
            parts.push("decoration = { " + dec.join(", ") + " }");
        if (root.scanout >= 0) {
            const d = Math.min(2, Math.round(root.scanout));
            parts.push("render = { direct_scanout = " + d + " }");
            kw.push("keyword render:direct_scanout " + d);
        }
        if (parts.length === 0)
            return;
        if (root.lua)
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ " + parts.join(", ") + " })"]);
        else
            Quickshell.execDetached(["hyprctl", "--batch", kw.join(" ; ")]);
    }

    // Settings > Apps > Opacity > Tidal (SONE), otherwise "All apps". SONE draws its window fully opaque and has
    // transparency of its own, so Hyprland makes the whole window translucent (window rule "qs-app-opacity").
    // Like the blur it is set at runtime via "hyprctl eval", hyprland.lua stays unchanged; after "hyprctl reload"
    // the rule is gone -> set it again on start and after every reload. Same name = same rule, the new value wins.
    // kitty gets the same value as background_opacity (qs-glass-apply), so at the same number the background
    // looks the same. Class without backslashes so nothing gets escaped wrongly: [.] = dot, (?i) = any case.
    readonly property int appOpacity: Config.opts.appOpacityTidal >= 0 ? Config.opts.appOpacityTidal : Config.opts.appOpacity
    readonly property string appOpacityClasses: "(?i)(sone|io[.]github[.]lullabyx[.]sone)"
    onAppOpacityChanged: opacityApply.restart()

    Timer {
        id: opacityApply

        interval: 150
        onTriggered: root.applyAppOpacity()
    }

    function applyAppOpacity() {
        if (!root.lua)
            return;
        const a = Math.max(25, Math.min(100, Math.round(root.appOpacity))) / 100;
        Quickshell.execDetached(["hyprctl", "eval", "hl.window_rule({ name = \"qs-app-opacity\", match = { class = \"" + root.appOpacityClasses + "\" }, opacity = \"" + a.toFixed(2) + " override\" })"]);
    }

    // Whether a window floats is only in lastIpcObject. Hyprland doesn't update it
    // by itself, so query again on matching events.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const n = event.name;
            if (n === "openwindow" || n === "closewindow" || n === "changefloatingmode" || n === "movewindowv2" || n === "workspacev2" || n === "focusedmonv2")
                root.refresh();
            else if (n === "configreloaded") {
                root.pushOverrides();
                opacityApply.restart();
            }
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
