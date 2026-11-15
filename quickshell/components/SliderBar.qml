import QtQuick
import qs.config

// Slider 0..1. Never sets "value" itself, it reports moved(v).
// No knob: the bright fill simply ends, with the same rounding as the left end.
Item {
    id: root

    property real value: 0
    property real step: 0.05
    readonly property bool dragging: area.pressed
    property real liveValue: 0
    readonly property real shown: dragging ? liveValue : Math.max(0, Math.min(1, value))

    signal moved(real v)

    implicitHeight: 22
    implicitWidth: 200
    opacity: enabled ? 1 : 0.4

    function valueAt(x) {
        return Math.max(0, Math.min(1, (x - knob.width / 2) / Math.max(1, root.width - knob.width)));
    }

    Rectangle {
        id: track

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Qt.rgba(1, 1, 1, 0.18)

        Rectangle {
            width: knob.x
            height: parent.height
            radius: parent.radius
            color: Theme.accent
        }
    }

    // Invisible marker for the end of the fill (width 0). The animation still runs through kx.
    Item {
        id: knob

        anchors.verticalCenter: parent.verticalCenter
        property real kx: root.shown * (root.width - width)

        // subpixel like the bar
        x: kx
        width: 0
        height: 0

        Behavior on kx {
            enabled: !root.dragging

            Anim {
                duration: Theme.ctlFast
                easing.bezierCurve: Theme.curveSmooth
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: ev => {
            root.liveValue = root.valueAt(ev.x);
            root.moved(root.liveValue);
        }
        onPositionChanged: ev => {
            if (pressed) {
                root.liveValue = root.valueAt(ev.x);
                root.moved(root.liveValue);
            }
        }
        onWheel: ev => {
            const dir = ev.angleDelta.y > 0 ? 1 : (ev.angleDelta.y < 0 ? -1 : 0);
            if (dir !== 0)
                root.moved(Math.max(0, Math.min(1, root.value + dir * root.step)));
        }
    }
}
