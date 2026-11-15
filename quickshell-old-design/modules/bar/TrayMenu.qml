import QtQuick
import Quickshell
import qs.config
import qs.components

// Tray context menu in the shell's own look (instead of Qt's default menu). Submenus by click.
PopupWindow {
    id: root

    property var barWindow: null
    property var anchorItem: null
    property var stack: []
    readonly property var current: root.stack.length > 0 ? root.stack[root.stack.length - 1] : null
    property real anchorX: 0

    function show(handle, item) {
        if (!handle || !root.barWindow)
            return;
        root.anchorItem = item;
        const p = item.mapToItem(null, item.width / 2, 0);
        root.anchorX = p.x;
        root.stack = [handle];
        root.visible = true;
    }

    function hide() {
        root.visible = false;
    }

    function clean(text) {
        return (text || "").replace(/__/g, "\u0001").replace(/_/g, "").replace(/\u0001/g, "_");
    }

    anchor.window: root.barWindow
    anchor.rect.x: Math.round(root.anchorX - root.width / 2)
    anchor.rect.y: root.barWindow ? (root.barWindow.visualBottom !== undefined ? root.barWindow.visualBottom : root.barWindow.height) + 6 : 0
    grabFocus: true
    color: "transparent"
    implicitWidth: 260
    implicitHeight: card.implicitHeight

    onVisibleChanged: {
        if (!visible)
            root.stack = [];
    }

    QsMenuOpener {
        id: opener

        menu: root.current
    }

    Card {
        id: card

        width: parent.width
        implicitHeight: col.implicitHeight + 12
        radius: Theme.radius

        Column {
            id: col

            x: 6
            y: 6
            width: parent.width - 12

            // Back out of a submenu
            Rectangle {
                width: col.width
                height: 30
                visible: root.stack.length > 1
                radius: Theme.radiusSm
                color: backArea.containsMouse ? Theme.hover : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.left
                        font.pixelSize: Theme.fontSize + 2
                        color: Theme.fgDim
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Back"
                        color: Theme.fgDim
                    }
                }

                MouseArea {
                    id: backArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.stack = root.stack.slice(0, root.stack.length - 1)
                }
            }

            Repeater {
                model: opener.children

                delegate: Item {
                    id: entry

                    required property var modelData
                    readonly property bool sep: modelData.isSeparator
                    readonly property bool checkable: modelData.buttonType !== QsMenuButtonType.None

                    width: col.width
                    height: sep ? 9 : 32

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        width: parent.width - 16
                        height: 1
                        visible: entry.sep
                        color: Theme.border
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: !entry.sep
                        radius: Theme.radiusSm
                        color: entryArea.containsMouse && entry.modelData.enabled ? Theme.hover : "transparent"

                        Behavior on color {
                            CAnim {}
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !entry.sep
                        spacing: 8
                        opacity: entry.modelData.enabled ? 1 : 0.4

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: entry.checkable
                            width: 14
                            text: entry.modelData.checkState === Qt.Checked ? Icons.check : ""
                            font.pixelSize: Theme.fontSize
                        }

                        AppIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: (entry.modelData.icon || "") !== ""
                            width: 16
                            height: 16
                            source: entry.modelData.icon || ""
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40
                            text: root.clean(entry.modelData.text)
                        }
                    }

                    Glyph {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !entry.sep && entry.modelData.hasChildren
                        text: Icons.right
                        font.pixelSize: Theme.fontSize + 2
                        color: Theme.fgDim
                    }

                    MouseArea {
                        id: entryArea

                        anchors.fill: parent
                        enabled: !entry.sep && entry.modelData.enabled
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (entry.modelData.hasChildren) {
                                root.stack = root.stack.concat([entry.modelData]);
                            } else {
                                entry.modelData.triggered();
                                root.hide();
                            }
                        }
                    }
                }
            }
        }
    }
}
