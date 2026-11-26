import QtQuick
import qs.config
import qs.components

// Header of a sub page in the control center: back arrow, title with subtitle, the switch on the right.
// Same font as the header of the main page (name + uptime).
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool toggleVisible: true

    signal back
    signal toggled

    height: 38

    IconButton {
        id: backBtn

        anchors.left: parent.left
        anchors.leftMargin: -4
        anchors.verticalCenter: parent.verticalCenter
        size: 34
        iconSize: Theme.iconSize + 2
        fg: Theme.textDim
        icon: Icons.left
        onClicked: root.back()
    }

    Column {
        anchors.left: backBtn.right
        anchors.leftMargin: 4
        anchors.right: toggle.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Txt {
            width: parent.width
            text: root.title
            font.pixelSize: Theme.fontSize + 1
            font.weight: Theme.uiWeightStrong
        }

        Txt {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            color: Theme.textMuted
            font.pixelSize: Theme.fontSm
        }
    }

    Toggle {
        id: toggle

        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        visible: root.toggleVisible
        checked: root.checked
        onToggled: root.toggled()
    }
}
