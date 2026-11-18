import QtQuick
import qs.config

// Quick settings tile (icon, title, subtitle), no background and no circle. Active = icon and title
// light up (icon in the accent color), off = both dimmed. chevron = small arrow on the right (opens a sub page).
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool chevron: false
    // Shared gliding hover box of the group (HoverGlide). Without it: own background as before.
    property Item glide: null
    readonly property bool glideDown: area.pressed

    signal clicked
    signal rightClicked

    implicitHeight: 58
    implicitWidth: 160
    radius: Theme.radius
    // Transparent on the blur like the terminals, a background only on hover
    color: root.glide ? "transparent" : (area.pressed ? Theme.pressed : (area.containsMouse ? Theme.fill : "transparent"))

    Behavior on color {
        CAnim {}
    }

    Item {
        id: chip

        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30

        Glyph {
            anchors.centerIn: parent
            text: root.icon
            color: root.active ? Theme.accent : Qt.rgba(1, 1, 1, 0.38)
            font.pixelSize: Theme.iconSize + 2

            Behavior on color {
                CAnim {}
            }
        }
    }

    Column {
        anchors.left: chip.right
        anchors.leftMargin: 11
        anchors.right: parent.right
        anchors.rightMargin: root.chevron ? 28 : 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Txt {
            width: parent.width
            text: root.title
            color: root.active ? Theme.fg : Theme.textMuted
            font.pixelSize: Theme.fontSm + 1

            Behavior on color {
                CAnim {}
            }
        }

        Txt {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            color: root.active ? Theme.textDim : Qt.rgba(1, 1, 1, 0.38)
            font.pixelSize: Theme.fontSm - 1

            Behavior on color {
                CAnim {}
            }
        }
    }

    Glyph {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: root.chevron
        text: Icons.right
        color: area.containsMouse ? Theme.textDim : Qt.rgba(1, 1, 1, 0.38)
        font.pixelSize: Theme.iconSize - 2

        Behavior on color {
            CAnim {}
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onContainsMouseChanged: {
            if (root.glide)
                containsMouse ? root.glide.enter(root) : root.glide.leave(root);
        }
        onClicked: ev => {
            if (ev.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }
}
