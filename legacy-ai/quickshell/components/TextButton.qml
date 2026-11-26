import QtQuick
import qs.config

// Plain text button (optionally with a small icon in front), background only on hover.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property color fg: Theme.textDim
    readonly property bool hovered: area.containsMouse

    signal clicked

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 26
    radius: Theme.radiusSm
    color: area.pressed ? Theme.fillStrong : (area.containsMouse ? Theme.fill : "transparent")
    opacity: enabled ? 1 : 0.4

    Behavior on color {
        CAnim {}
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            color: label.color
            font.pixelSize: Theme.fontSm + 2
        }

        Txt {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: area.containsMouse ? Theme.fg : root.fg
            font.pixelSize: Theme.fontSm
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
