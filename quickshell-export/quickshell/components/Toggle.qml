import QtQuick
import qs.config

// Schalter. Setzt "checked" nicht selbst, sondern meldet toggled().
Item {
    id: root

    property bool checked: false

    signal toggled

    implicitWidth: 38
    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.layer3
        border.width: 1
        border.color: root.checked ? Theme.accent : Theme.borderStrong

        Behavior on color {
            CAnim {}
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 4 : 4
        width: root.height - 8
        height: width
        radius: width / 2
        color: root.checked ? Theme.accentFg : Theme.fgDim

        Behavior on x {
            Anim {
                duration: Theme.durFast
            }
        }
        Behavior on color {
            CAnim {}
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
