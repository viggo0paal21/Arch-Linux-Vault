import QtQuick
import qs.config
import qs.components

// Eine Zeile im Einstellungs-Panel: Text links, Bedienelement rechts.
Item {
    id: root

    property string label: ""
    property string description: ""
    property int controlWidth: 240
    default property alias control: slot.data

    implicitHeight: Math.max(46, texts.implicitHeight + 16)

    Column {
        id: texts

        anchors.left: parent.left
        anchors.right: slot.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

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
        anchors.verticalCenter: parent.verticalCenter
        width: root.controlWidth
        height: childrenRect.height
    }
}
