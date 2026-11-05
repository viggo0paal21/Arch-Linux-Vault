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
        // Only fade in + a short slide, always on whole pixels: text stays sharp in every frame
        x: Math.round((parent.width - width) / 2)
        y: Theme.px((parent.height - height) / 2 + 14 * (1 - panel.progress))
        spacing: 22
        opacity: panel.progress

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            Repeater {
                model: panel.actions

                delegate: Rectangle {
                    id: tile

                    required property var modelData
                    required property int index
                    readonly property bool selected: index === panel.current
                    readonly property bool isArmed: index === panel.armed

                    width: 124
                    height: 124
                    radius: Theme.radiusLg
                    color: isArmed ? Theme.accent : (selected ? Qt.tint(Glass.popupBg, Theme.layer3) : Glass.popupBg)
                    border.width: 1
                    border.color: selected ? Theme.fg : Theme.border

                    Behavior on color {
                        CAnim {}
                    }
                    Behavior on border.color {
                        CAnim {}
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        Glyph {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.icon
                            color: tile.isArmed ? Theme.accentFg : Theme.fg
                            font.pixelSize: 34
                        }

                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.isArmed ? "Sure?" : tile.modelData.label
                            color: tile.isArmed ? Theme.accentFg : Theme.fg
                            font.weight: Theme.weightStrong
                        }
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

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: panel.armed >= 0 ? "Click again or press Enter to confirm" : "Esc to close"
            color: Theme.fgMuted
        }
    }
}
