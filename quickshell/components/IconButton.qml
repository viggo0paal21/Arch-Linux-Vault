import QtQuick
import qs.config

// Round icon button with optional text. Active = filled white.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool active: false
    property int size: 32
    property int iconSize: Theme.iconSize
    property int radius: Theme.radiusSm
    property color idleColor: "transparent"
    property color fg: active ? Theme.accentFg : Theme.fg
    readonly property bool hovered: area.containsMouse
    // Shared gliding hover box of the group (HoverGlide). Without it: own background as before.
    property Item glide: null
    readonly property bool glideDown: area.pressed

    signal clicked
    signal rightClicked
    signal middleClicked
    signal scrolled(int delta)

    implicitWidth: label === "" ? size : row.implicitWidth + 22
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.active ? Theme.accent : (root.glide ? root.idleColor : (area.pressed ? Theme.pressed : (area.containsMouse ? Theme.hover : root.idleColor)))

        Behavior on color {
            CAnim {}
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 7

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            color: root.fg
            font.pixelSize: root.iconSize
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            color: root.fg
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onContainsMouseChanged: {
            if (root.glide)
                containsMouse ? root.glide.enter(root) : root.glide.leave(root);
        }
        onClicked: ev => {
            if (ev.button === Qt.RightButton)
                root.rightClicked();
            else if (ev.button === Qt.MiddleButton)
                root.middleClicked();
            else
                root.clicked();
        }
        onWheel: ev => root.scrolled(ev.angleDelta.y)
    }
}
