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
