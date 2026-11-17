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

    // Width from the target widths (1 active pill 26, the others 10), not from the animated ones: so the group
    // (and its box with "Group boxes") keeps its width while switching workspaces instead of jittering by 1 px.
    readonly property int pillSpacing: 6
    implicitWidth: root.count * 10 + (root.activeId >= 1 ? 16 : 0) + (root.count - 1) * root.pillSpacing + 16
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

        // Ganze Pixel: links 8 px Rand, senkrecht mittig
        x: 8
        y: Math.round((root.height - row.height) / 2)
        spacing: root.pillSpacing

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

                // Round the growing (active) pill up and the shrinking one down: together the width stays the same
                width: isActive ? Math.ceil(w) : Math.floor(w)
                height: 10
                radius: 5
                color: isActive ? Theme.accentLive : (pillArea.containsMouse ? Theme.fgDim : (isOccupied ? Theme.fgMuted : Theme.layer3))

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
