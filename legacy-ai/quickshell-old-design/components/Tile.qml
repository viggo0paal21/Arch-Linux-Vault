import QtQuick
import qs.config

// Quick settings tile (icon, title, subtitle). Active = white.
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    readonly property color fg: active ? Theme.accentFg : Theme.fg

    signal clicked
    signal rightClicked

    implicitHeight: 58
    implicitWidth: 160
    radius: Theme.radius
    color: active ? Theme.accent : (area.pressed ? Theme.pressed : (area.containsMouse ? Theme.hover : Theme.layer2))
    border.width: 1
    border.color: active ? Theme.accent : Theme.border

    Behavior on color {
        CAnim {}
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.fg
            font.pixelSize: Theme.iconSize + 2
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 40
            spacing: 1

            Txt {
                width: parent.width
                text: root.title
                color: root.fg
                font.weight: Theme.weightStrong
            }

            Txt {
                width: parent.width
                visible: root.subtitle !== ""
                text: root.subtitle
                color: root.active ? Theme.accentFg : Theme.fgDim
                opacity: root.active ? 0.7 : 1
                font.pixelSize: Theme.fontSm
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: ev => {
            if (ev.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }
}
