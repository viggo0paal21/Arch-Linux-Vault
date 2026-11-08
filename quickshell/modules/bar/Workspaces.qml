import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Workspaces as pills: active = long + white, occupied = grey, empty = dark.
Item {
    id: root

    property var monitor: null
    property real wheelAccum: 0

    readonly property int activeId: (root.monitor && root.monitor.activeWorkspace) ? root.monitor.activeWorkspace.id : -1

    readonly property var occupied: {
        const map = {};
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id > 0 && ws.toplevels.values.length > 0)
                map[ws.id] = true;
        }
        return map;
    }

    readonly property int count: {
        let n = Math.max(1, Config.opts.workspaceCount);
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id > n && ws.id <= 30)
                n = ws.id;
        }
        return Math.max(n, root.activeId);
    }

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 28

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: ev => {
            root.wheelAccum += ev.angleDelta.y;
            if (Math.abs(root.wheelAccum) >= 120) {
                Hypr.workspace(root.wheelAccum > 0 ? "e-1" : "e+1");
                root.wheelAccum = 0;
            }
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.count

            delegate: Rectangle {
                id: pill

                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: wsId === root.activeId
                readonly property bool isOccupied: root.occupied[wsId] === true

                anchors.verticalCenter: parent.verticalCenter
                property real w: isActive ? 26 : 10

                width: Math.round(w)
                height: 10
                radius: 5
                color: isActive ? Theme.accent : (pillArea.containsMouse ? Theme.fgDim : (isOccupied ? Theme.fgMuted : Theme.layer3))

                Behavior on w {
                    Anim {
                        duration: Math.round(Theme.durMed * Config.opts.animWsSpeed)
                        easing.bezierCurve: Theme.curveOf(Config.opts.animWsCurve)
                    }
                }
                Behavior on color {
                    CAnim {}
                }

                MouseArea {
                    id: pillArea

                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hypr.workspace(pill.wsId)
                }
            }
        }
    }
}
