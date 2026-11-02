import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.config
import qs.components

// System-Tray. Links: aktivieren, Rechts: eigenes S/W-Menue, Mitte: Zweitaktion.
Row {
    id: root

    property var barWindow: null
    property int itemSize: 28

    spacing: 2
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayItem

            required property var modelData

            width: root.itemSize
            height: root.itemSize

            function openMenu() {
                menu.show(trayItem.modelData.menu, trayItem);
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSm
                color: area.pressed ? Theme.pressed : (area.containsMouse ? Theme.hover : "transparent")

                Behavior on color {
                    CAnim {}
                }
            }

            AppIcon {
                anchors.centerIn: parent
                width: 18
                height: 18
                source: trayItem.modelData.icon
                fallback: trayItem.modelData.title || trayItem.modelData.id || "?"
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: ev => {
                    const item = trayItem.modelData;
                    if (ev.button === Qt.MiddleButton) {
                        item.secondaryActivate();
                    } else if (ev.button === Qt.RightButton) {
                        if (item.hasMenu)
                            trayItem.openMenu();
                    } else if (item.onlyMenu && item.hasMenu) {
                        trayItem.openMenu();
                    } else {
                        item.activate();
                    }
                }
                onWheel: ev => trayItem.modelData.scroll(ev.angleDelta.y, false)
            }
        }
    }

    TrayMenu {
        id: menu

        barWindow: root.barWindow
    }
}
