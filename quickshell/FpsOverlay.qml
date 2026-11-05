import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services

// Debug: real frame rate of this window. Counts frames that were actually
// drawn and submitted (frameSwapped), against the real clock.
// The line at the bottom moves constantly: it shows whether motion is even.
// On/off: Settings > FPS counter or qs ipc call fps toggle
PanelWindow {
    id: root

    // on/off via Settings > FPS counter (saved)
    readonly property bool shown: Config.opts.fpsCounter
    property int frames: 0
    property real prev: 0
    property real worst: 0
    property real last: Date.now()

    visible: root.shown
    color: "transparent"
    implicitWidth: 190
    implicitHeight: 32

    anchors {
        top: true
        right: true
    }

    margins {
        top: Ui.barBottomTarget + Theme.gap
        right: Theme.gap
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-fps"

    // Clicks go through the box
    mask: Region {}

    Rectangle {
        id: box

        anchors.fill: parent
        color: Theme.bg
        border.width: 1
        border.color: Theme.borderStrong
        radius: Theme.radiusSm
        clip: true

        Text {
            id: label

            anchors.centerIn: parent
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.weight: Theme.weight
            text: "– fps"
        }

        // moves back and forth constantly -> forces a new image every frame
        Rectangle {
            id: sweep

            y: box.height - 3
            width: 12
            height: 2
            color: Theme.fg

            NumberAnimation on x {
                running: root.shown
                from: 0
                to: box.width - sweep.width
                duration: 1000
                loops: Animation.Infinite
            }
        }
    }

    // counts every frame of this window that was really submitted
    Connections {
        target: label.Window.window

        function onFrameSwapped() {
            const t = Date.now();
            if (root.prev > 0)
                root.worst = Math.max(root.worst, t - root.prev);
            root.prev = t;
            root.frames++;
        }
    }

    // settles up every second against the real clock
    Timer {
        interval: 1000
        running: root.shown
        repeat: true
        onTriggered: {
            const now = Date.now();
            const dt = now - root.last;
            // longest gap between two frames in this second (170 Hz = ~6 ms)
            label.text = Math.round(root.frames * 1000 / dt) + " fps  ·  max " + Math.round(root.worst) + " ms";
            root.frames = 0;
            root.worst = 0;
            root.last = now;
        }
    }

    onShownChanged: {
        root.frames = 0;
        root.worst = 0;
        root.prev = 0;
        root.last = Date.now();
        label.text = "– fps";
    }

    IpcHandler {
        target: "fps"

        function toggle(): void {
            Config.opts.fpsCounter = !Config.opts.fpsCounter;
        }
    }
}
