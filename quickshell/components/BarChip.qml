import QtQuick
import qs.config

// Klickbarer Bereich in der Leiste. Kinder landen in einer Reihe; "fg" fuer ihre Farbe.
Item {
    id: root

    property bool active: false
    readonly property color fg: active ? Theme.accentFg : Theme.fg
    readonly property color fgDim: active ? Theme.accentFg : Theme.fgDim
    readonly property bool hovered: area.containsMouse
    property alias spacing: row.spacing
    default property alias content: row.data

    signal clicked
    signal rightClicked
    signal middleClicked
    signal scrolled(int delta)

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: root.active ? Theme.accent : (area.pressed ? Theme.pressed : (area.containsMouse ? Theme.hover : "transparent"))

        Behavior on color {
            CAnim {}
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 8
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
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
