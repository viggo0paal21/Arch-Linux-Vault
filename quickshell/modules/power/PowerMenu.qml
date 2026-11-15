import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Power menu. Arrows/mouse select, Enter/click confirms.
// Log out, reboot and shut down need a second click.
OverlayPanel {
    id: panel

    property int current: 0
    property int armed: -1

    readonly property var actions: [
        {
            icon: Icons.lock,
            label: "Lock",
            confirm: false
        },
        {
            icon: Icons.sleep,
            label: "Suspend",
            confirm: false
        },
        {
            icon: Icons.logout,
            label: "Log out",
            confirm: true
        },
        {
            icon: Icons.restart,
            label: "Reboot",
            confirm: true
        },
        {
            icon: Icons.power,
            label: "Shut down",
            confirm: true
        }
    ]

    function run(index) {
        const a = panel.actions[index];
        if (!a)
            return;
        if (a.confirm && panel.armed !== index) {
            panel.armed = index;
            panel.current = index;
            return;
        }
        Ui.close();
        switch (index) {
        case 0:
            Quickshell.execDetached(["sh", "-c", Config.opts.lockCommand]);
            break;
        case 1:
            Quickshell.execDetached(["sh", "-c", "(" + Config.opts.lockCommand + ") & sleep 1; systemctl suspend"]);
            break;
        case 2:
            Hypr.exit();
            break;
        case 3:
            Quickshell.execDetached(["systemctl", "reboot"]);
            break;
        case 4:
            Quickshell.execDetached(["systemctl", "poweroff"]);
            break;
        }
    }

    open: Ui.panel === "power"
    screen: Ui.panelScreen
    dim: true
    dimOpacity: 0.7
    ns: "qs-power"
    onDismissed: Ui.close()
    onOpenChanged: {
        if (open) {
            panel.current = 0;
            panel.armed = -1;
            keys.forceActiveFocus();
        }
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onLeftPressed: {
            panel.current = (panel.current + panel.actions.length - 1) % panel.actions.length;
            panel.armed = -1;
        }
        Keys.onRightPressed: {
            panel.current = (panel.current + 1) % panel.actions.length;
            panel.armed = -1;
        }
        Keys.onTabPressed: {
            panel.current = (panel.current + 1) % panel.actions.length;
            panel.armed = -1;
        }
        Keys.onReturnPressed: panel.run(panel.current)
        Keys.onEnterPressed: panel.run(panel.current)
        Keys.onSpacePressed: panel.run(panel.current)
    }

    Column {
        // Fade in + short glide, subpixel like the bar: drawn as a texture while moving (text stays sharp),
        // at rest on whole pixels without a texture
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2) + 14 * (1 - panel.progress)
        spacing: 14
        opacity: panel.progress
        layer.enabled: panel.progress > 0 && panel.progress < 1
        layer.smooth: true

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18

            Repeater {
                model: panel.actions

                delegate: Item {
                    id: tile

                    required property var modelData
                    required property int index
                    readonly property bool selected: index === panel.current
                    readonly property bool isArmed: index === panel.armed

                    width: 92
                    height: 112

                    // Just the icon, no circle: selected = bright, otherwise dimmed, "Confirm" = accent color
                    Item {
                        id: circle

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 72
                        height: 72

                        Glyph {
                            anchors.centerIn: parent
                            text: tile.modelData.icon
                            color: tile.isArmed ? Theme.accent : (tile.selected ? Theme.fg : Qt.rgba(1, 1, 1, 0.38))
                            font.pixelSize: 40
                        }
                    }

                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: circle.bottom
                        anchors.topMargin: 12
                        text: tile.isArmed ? "Confirm" : tile.modelData.label
                        color: tile.selected ? Theme.fg : Qt.rgba(1, 1, 1, 0.38)
                        font.pixelSize: Theme.fontSm + 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            if (panel.current !== tile.index)
                                panel.armed = -1;
                            panel.current = tile.index;
                        }
                        onClicked: panel.run(tile.index)
                    }
                }
            }
        }

        // Hint only while confirming; the row always keeps its height so nothing jumps
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Click again or press Enter"
            color: Theme.textMuted
            font.pixelSize: Theme.fontSm
            opacity: panel.armed >= 0 ? 1 : 0
        }
    }
}
