import QtQuick
import qs.config

// Schieberegler 0..1. Setzt "value" nie selbst, sondern meldet moved(v).
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
        color: Theme.layer3

        Rectangle {
            width: knob.x + knob.width / 2
            height: parent.height
            radius: parent.radius
            color: Theme.fg
        }
    }

    Rectangle {
        id: knob

        anchors.verticalCenter: parent.verticalCenter
        property real kx: root.shown * (root.width - width)
        property real kw: area.containsMouse || area.pressed ? 16 : 12

        x: Math.round(kx)
        width: Math.round(kw / 2) * 2
        height: width
        radius: width / 2
        color: Theme.fg
        border.width: 3
        border.color: Theme.bg

        Behavior on kw {
            Anim {
                duration: Theme.ctlFast
            }
        }
        Behavior on kx {
            enabled: !root.dragging

            Anim {
                duration: Theme.ctlFast
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
