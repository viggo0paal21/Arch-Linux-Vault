import QtQuick
import qs.config
import qs.components

// Tile in the system monitor: icon, title, big value, subtitle, optional history.
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string value: ""
    property string subtitle: ""
    property var history: null
    property real historyMax: 1

    implicitHeight: 74 + (root.history !== null ? 46 : 0)
    radius: Theme.radius
    color: Theme.layer2
    border.width: 1
    border.color: Theme.border

    Row {
        x: 14
        y: 14
        spacing: 10

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: Theme.fgDim
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Theme.fgDim
        }
    }

    Txt {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 10
        text: root.value
        font.pixelSize: Theme.fontLg + 4
        font.weight: Theme.weightStrong
    }

    Txt {
        x: 14
        y: 44
        width: parent.width - 28
        text: root.subtitle
        color: Theme.fgMuted
        font.pixelSize: Theme.fontSm
    }

    Sparkline {
        x: 1
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        width: parent.width - 2
        height: 44
        visible: root.history !== null
        values: root.history || []
        max: root.historyMax
    }
}
