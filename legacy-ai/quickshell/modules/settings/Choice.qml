import QtQuick
import qs.config
import qs.components

// Small choice menu (dropdown): field with the current choice, a click opens a short list below it.
// Built like the font picker (FontSelect), just without search: the list sits on menuParent (the settings
// card), fades in, the light marker glides from row to row under the mouse, the current choice has a checkmark.
// options: [{ value: "a", label: "A" }, ...]
Item {
    id: root

    property var options: []
    property string value: ""
    property Item menuParent: null
    property Item scrollArea: null
    property bool active: true
    // Marked row (mouse)
    property int sel: -1
    readonly property int rowHeight: 34
    readonly property string currentLabel: {
        for (const o of root.options) {
            if (o.value === root.value)
                return o.label;
        }
        return root.value;
    }

    signal picked(string value)

    implicitHeight: 34

    onActiveChanged: {
        if (!root.active)
            root.close();
    }
    onVisibleChanged: {
        if (!root.visible)
            root.close();
    }

    function openMenu() {
        if (!root.menuParent)
            return;
        root.place();
        root.sel = -1;
        menu.open = true;
    }

    function close() {
        menu.open = false;
    }

    function choose(v) {
        root.close();
        if (v !== root.value)
            root.picked(v);
    }

    // Below the field, same width (at least 220); if there is not enough room below, above it. Always whole pixels.
    function place() {
        const host = root.menuParent;
        const p = root.mapToItem(host, 0, 0);
        const h = Math.min(menu.fullHeight, host.height - 28);
        const below = p.y + root.height + 6;
        menu.height = h;
        menu.x = Math.round(Math.max(14, Math.min(p.x + root.width - menu.width, host.width - menu.width - 14)));
        menu.y = Math.round(below + h <= host.height - 14 ? below : Math.max(14, p.y - 6 - h));
    }

    Connections {
        target: root.scrollArea
        ignoreUnknownSignals: true

        function onContentYChanged() {
            root.close();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: fieldArea.pressed ? Theme.pressed : (menu.open || fieldArea.containsMouse ? Theme.fillStrong : Theme.fill)
        border.width: 1
        border.color: menu.open ? Theme.hairlineStrong : "transparent"

        Behavior on color {
            CAnim {}
        }
        Behavior on border.color {
            CAnim {}
        }

        Txt {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: chevron.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentLabel
            font.pixelSize: Theme.fontSm + 1
        }

        // Arrow turns upwards when open
        Glyph {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.down
            color: Theme.textDim
            font.pixelSize: Theme.iconSize - 2
            rotation: menu.open ? 180 : 0

            Behavior on rotation {
                Anim {
                    duration: Theme.ctlFast
                }
            }
        }

        MouseArea {
            id: fieldArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.open ? root.close() : root.openMenu()
        }
    }

    // A click outside closes the list (sits below the list, above the rest of the card)
    MouseArea {
        parent: root.menuParent ? root.menuParent : root
        anchors.fill: parent
        z: 99
        visible: menu.open
        acceptedButtons: Qt.AllButtons
        onPressed: root.close()
    }

    Rectangle {
        id: menu

        property bool open: false
        readonly property int fullHeight: Math.min(8, Math.max(1, root.options.length)) * root.rowHeight + 12

        parent: root.menuParent ? root.menuParent : root
        z: 100
        width: Math.max(root.width, 220)
        visible: opacity > 0
        enabled: menu.open
        opacity: menu.open ? 1 : 0
        radius: Theme.radius
        color: "#090909"
        border.width: 1
        border.color: Theme.hairlineStrong

        Behavior on opacity {
            Anim {
                duration: Theme.ctlFast
            }
        }

        // Don't let own clicks through to the area below
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onExited: root.sel = -1
        }

        ListView {
            id: list

            x: 6
            y: 6
            width: parent.width - 12
            height: parent.height - 12
            clip: true
            pixelAligned: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.options
            interactive: contentHeight > height

            // Marker for the row under the mouse: glides like the launcher selection, behind the rows (z = 1)
            Rectangle {
                id: selBox

                property bool down: false

                parent: list.contentItem
                x: 0
                y: Math.max(0, root.sel) * root.rowHeight
                z: 0
                width: list.width
                height: root.rowHeight
                radius: Theme.radiusSm
                color: selBox.down ? Theme.pressed : Theme.fill
                opacity: root.sel >= 0 && root.sel < list.count ? 1 : 0

                Behavior on y {
                    enabled: selBox.opacity > 0.01

                    SmoothedAnimation {
                        velocity: 400
                        duration: Theme.ctlFast
                    }
                }
                Behavior on opacity {
                    Anim {
                        duration: Theme.ctlFast
                    }
                }
                Behavior on color {
                    CAnim {}
                }
            }

            delegate: Item {
                id: item

                required property var modelData
                required property int index
                readonly property bool isValue: item.modelData.value === root.value

                width: list.width
                height: root.rowHeight

                Txt {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 44
                    text: item.modelData.label
                    color: item.isValue || item.index === root.sel ? Theme.fg : Theme.textDim
                    font.pixelSize: Theme.fontSm + 1
                }

                Glyph {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: item.isValue
                    text: Icons.check
                    color: Theme.accent
                    font.pixelSize: Theme.iconSize - 2
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressedChanged: selBox.down = pressed
                    onEntered: root.sel = item.index
                    onClicked: root.choose(item.modelData.value)
                }
            }
        }
    }
}
