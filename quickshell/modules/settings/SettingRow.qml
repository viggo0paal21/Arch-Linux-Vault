import QtQuick
import qs.config
import qs.components

// Eine Zeile im Einstellungs-Panel: eigene Flaeche wie die Suchzeile im Launcher,
// Text links, Bedienelement rechts, viel Luft drumherum.
Item {
    id: root

    property string label: ""
    property string description: ""
    property int controlWidth: 260
    default property alias control: slot.data

    implicitHeight: Math.max(64, texts.implicitHeight + 28)

    HoverHandler {
        id: hover
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.layer2
        border.width: 1
        border.color: hover.hovered ? Theme.borderStrong : Theme.border

        Behavior on border.color {
            CAnim {}
        }
    }

    Column {
        id: texts

        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: slot.left
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Txt {
            width: parent.width
            text: root.label
        }

        Txt {
            width: parent.width
            visible: root.description !== ""
            text: root.description
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSm
            wrapMode: Text.Wrap
        }
    }

    Item {
        id: slot

        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: root.controlWidth
        height: childrenRect.height
    }
}
