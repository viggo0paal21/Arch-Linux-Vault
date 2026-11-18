pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config

// Volume/mic via PipeWire. Reports changes for the OSD.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool hasSink: !!(root.sink && root.sink.audio)
    readonly property bool hasSource: !!(root.source && root.source.audio)

    readonly property real volume: root.hasSink ? root.sink.audio.volume : 0
    readonly property bool muted: root.hasSink ? root.sink.audio.muted : true
    readonly property real micVolume: root.hasSource ? root.source.audio.volume : 0
    readonly property bool micMuted: root.hasSource ? root.source.audio.muted : true
    readonly property string sinkName: root.sink ? (root.sink.description || root.sink.nickname || root.sink.name || "") : ""
    readonly property string sourceName: root.source ? (root.source.description || root.source.nickname || root.source.name || "") : ""

    property bool settled: false

    // ---------- Per-app volume (like the volume mixer on Windows) ----------
    // All program streams get bound (only then their properties exist). Only playback streams
    // (media.class "Stream/Output/Audio") of real apps are shown: background services, effect chains and short
    // system sounds are left out. Several streams of one app (e.g. several Firefox tabs) are one row.
    readonly property var streamNodes: Pipewire.nodes.values.filter(n => n && n.isStream && n.audio)
    readonly property var apps: {
        const groups = [];
        const byKey = {};
        const nodes = root.streamNodes.filter(n => root.isAppPlayback(n)).sort((a, b) => a.id - b.id);
        for (const n of nodes) {
            const p = n.properties;
            const bin = p["application.process.binary"] || "";
            const app = p["application.name"] || "";
            const key = bin + ":" + (app || n.name);
            let g = byKey[key];
            if (!g) {
                const e = DesktopEntries.heuristicLookup(app || bin) || (bin !== "" ? DesktopEntries.heuristicLookup(bin) : null);
                g = {
                    key: key,
                    name: e && e.name ? e.name : (app || bin || n.description || n.name),
                    // Like in the launcher: icon from the .desktop file, otherwise what the app reports itself
                    icon: e && e.icon ? e.icon : (p["application.icon-name"] || bin || app),
                    nodes: []
                };
                byKey[key] = g;
                groups.push(g);
            }
            g.nodes.push(n);
        }
        return groups;
    }
    readonly property var appKeys: root.apps.map(a => a.key)

    function isAppPlayback(n) {
        const p = n.properties;
        if (!n.ready || !p || p["media.class"] !== "Stream/Output/Audio")
            return false;
        // Short system sounds (notifications, clicks)
        const role = String(p["media.role"] || "").toLowerCase();
        if (role === "event" || role === "notification")
            return false;
        const ids = [p["application.name"], p["application.process.binary"], p["application.id"], p["node.name"], n.name].map(s => String(s || "").toLowerCase());
        const hidden = /^(speech-dispatcher.*|wireplumber|pipewire.*|pw-loopback.*|.*loopback.*|.*easyeffects.*|quickshell|qs|.*canberra.*)$/;
        return !ids.some(s => hidden.test(s));
    }

    function app(key) {
        return root.apps.find(a => a.key === key) || null;
    }

    function setAppVolume(key, v) {
        const a = root.app(key);
        if (!a)
            return;
        for (const n of a.nodes) {
            if (n.audio) {
                n.audio.muted = false;
                n.audio.volume = Math.max(0, Math.min(1, v));
            }
        }
    }

    function toggleAppMute(key) {
        const a = root.app(key);
        if (!a || a.nodes.length === 0 || !a.nodes[0].audio)
            return;
        const m = !a.nodes[0].audio.muted;
        for (const n of a.nodes) {
            if (n.audio)
                n.audio.muted = m;
        }
    }

    signal osdRequested

    function step() {
        return Math.max(1, Config.opts.volumeStep) / 100;
    }

    function setVolume(v) {
        if (!root.hasSink)
            return;
        root.sink.audio.muted = false;
        root.sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function up() {
        root.setVolume(root.volume + root.step());
    }

    function down() {
        root.setVolume(root.volume - root.step());
    }

    function toggleMute() {
        if (root.hasSink)
            root.sink.audio.muted = !root.sink.audio.muted;
    }

    function setMicVolume(v) {
        if (!root.hasSource)
            return;
        root.source.audio.muted = false;
        root.source.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMicMute() {
        if (root.hasSource)
            root.source.audio.muted = !root.source.audio.muted;
    }

    function icon() {
        if (root.muted || root.volume <= 0.001)
            return Icons.volOff;
        if (root.volume < 0.34)
            return Icons.volLow;
        if (root.volume < 0.67)
            return Icons.volMed;
        return Icons.volHigh;
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => !!n)
    }

    PwObjectTracker {
        objects: root.streamNodes
    }

    // Don't show the OSD on start and when the device changes
    onSinkChanged: {
        root.settled = false;
        settleTimer.restart();
    }

    Timer {
        id: settleTimer

        interval: 1200
        running: true
        onTriggered: root.settled = true
    }

    Connections {
        target: root.hasSink ? root.sink.audio : null

        function onVolumesChanged() {
            if (root.settled)
                root.osdRequested();
        }

        function onMutedChanged() {
            if (root.settled)
                root.osdRequested();
        }
    }
}
