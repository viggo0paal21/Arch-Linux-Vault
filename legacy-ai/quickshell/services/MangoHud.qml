pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// MangoHud configs in ~/.config/MangoHud (Settings > System > Gaming). MangoHud.conf applies globally, a game config
// <name>.conf (name of the executable, for Proton wine-<exe without .exe>) replaces it completely for that game:
// MangoHud takes the first matching file, nothing gets merged. That's why new game configs start as a copy of the global one.
// The chosen file is always the one read and written. Lines the settings don't know and comments
// stay unchanged. Writing is debounced (dragging a slider doesn't write on every pixel).
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.config/MangoHud"
    // File names without .conf, the global one first
    property var configs: ["MangoHud"]
    property string current: "MangoHud"
    readonly property bool isGlobal: root.current === "MangoHud"
    // Lines of the chosen file. ready: the file has been read (nothing is written before that, otherwise a
    // change right after switching could overwrite the file with almost empty content)
    property var lines: []
    property bool ready: false
    onCurrentChanged: root.ready = false
    readonly property var values: root.parse(root.lines)
    // /etc/environment sets MANGOHUD_CONFIG (e.g. read_cfg,no_display,...). That applies before any file.
    readonly property string envConfig: Quickshell.env("MANGOHUD_CONFIG") || ""
    readonly property bool envNoDisplay: root.envConfig.split(",").map(s => s.trim()).indexOf("no_display") >= 0
    // On without an own entry (old layout, legacy_layout=1): fps, frame_timing, cpu_stats, gpu_stats
    readonly property var defaultOn: ["fps", "frame_timing", "cpu_stats", "gpu_stats"]

    function refresh() {
        lister.running = true;
    }

    function select(name) {
        if (name === root.current)
            return;
        root.flush();
        root.current = name;
    }

    function parse(lines) {
        const v = {};
        for (const raw of lines) {
            const l = String(raw).trim();
            if (l === "" || l.startsWith("#"))
                continue;
            const i = l.indexOf("=");
            const k = (i < 0 ? l : l.slice(0, i)).trim();
            v[k] = i < 0 ? "" : l.slice(i + 1).trim();
        }
        return v;
    }

    function has(key) {
        return root.values[key] !== undefined;
    }

    function value(key, fallback) {
        const v = root.values[key];
        return v === undefined ? fallback : v;
    }

    // HUD element on/off (without an entry: MangoHud's default)
    function isOn(key) {
        const v = root.values[key];
        if (v === undefined)
            return root.defaultOn.indexOf(key) >= 0;
        return v !== "0";
    }

    // On = just the name (like in your configs), off = key=0 for default elements, otherwise the line goes
    function setOn(key, on) {
        if (on)
            root.set(key, "");
        else
            root.set(key, root.defaultOn.indexOf(key) >= 0 ? "0" : null);
    }

    // value null = remove the line, "" = just the name, otherwise key=value. The first line with the name is replaced,
    // further ones with the same name are dropped; new lines go before the blank lines at the end.
    function set(key, value) {
        if (!root.ready)
            return;
        const out = [];
        let done = false;
        for (const raw of root.lines) {
            const l = String(raw).trim();
            const i = l.indexOf("=");
            const k = l.startsWith("#") ? "" : (i < 0 ? l : l.slice(0, i)).trim();
            if (k === key) {
                if (!done && value !== null)
                    out.push(value === "" ? key : key + "=" + value);
                done = true;
                continue;
            }
            out.push(raw);
        }
        if (!done && value !== null) {
            let n = out.length;
            while (n > 0 && String(out[n - 1]).trim() === "")
                n--;
            out.splice(n, 0, value === "" ? key : key + "=" + value);
        }
        root.lines = out;
        root.dirty = true;
        writeDelay.restart();
    }

    property bool dirty: false

    function flush() {
        writeDelay.stop();
        if (!root.dirty)
            return;
        root.dirty = false;
        file.setText(root.lines.join("\n"));
    }

    // New game config as a copy of the global one (an existing file stays untouched), then select it
    function addGame(name) {
        const n = String(name).trim().replace(/\.conf$/i, "").replace(/\.exe$/i, "");
        if (!/^[A-Za-z0-9._+-]+$/.test(n) || n === "MangoHud")
            return false;
        root.flush();
        root.pendingSelect = n;
        creator.command = ["sh", "-c", "cd \"$1\" && { [ -e \"$2.conf\" ] || cp MangoHud.conf \"$2.conf\" 2>/dev/null || : > \"$2.conf\"; }", "sh", root.dir, n];
        creator.running = true;
        return true;
    }

    property string pendingSelect: ""

    Timer {
        id: writeDelay

        interval: 250
        onTriggered: root.flush()
    }

    Process {
        id: lister

        command: ["sh", "-c", "cd \"$HOME/.config/MangoHud\" 2>/dev/null && ls -1 -- *.conf 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = this.text.split("\n").map(s => s.trim()).filter(s => s.endsWith(".conf")).map(s => s.slice(0, -5));
                const games = names.filter(s => s !== "MangoHud").sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
                root.configs = ["MangoHud"].concat(games);
                if (root.pendingSelect !== "" && root.configs.indexOf(root.pendingSelect) >= 0) {
                    root.current = root.pendingSelect;
                    root.pendingSelect = "";
                } else if (root.configs.indexOf(root.current) < 0) {
                    root.current = "MangoHud";
                }
            }
        }
    }

    Process {
        id: creator

        onExited: root.refresh()
    }

    FileView {
        id: file

        path: root.dir + "/" + root.current + ".conf"
        printErrors: false
        watchChanges: true
        onFileChanged: {
            if (!root.dirty)
                reload();
        }
        onLoaded: {
            if (!root.dirty)
                root.lines = file.text().split("\n");
            root.ready = true;
        }
        // File missing: start empty (writing creates it)
        onLoadFailed: {
            if (!root.dirty)
                root.lines = [];
            root.ready = true;
        }
    }
}
