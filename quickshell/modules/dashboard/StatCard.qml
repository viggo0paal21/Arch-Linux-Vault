import QtQuick
import qs.config
import qs.components

// Entry in the system monitor: small heading, value on the right, subtitle, optional history below.
// No box and no icon. "icon" stays as a property in case something still sets it.
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string value: ""
    property string subtitle: ""
    property var history: null
    property real historyMax: 1

    implicitHeight: 44 + (root.history !== null ? 50 : 0)

    Txt {
        anchors.left: parent.left
        anchors.right: valueText.left
        anchors.rightMargin: 10
        y: 2
        text: root.title
        color: Theme.textMuted
        font.pixelSize: Theme.fontSm
        font.weight: Theme.uiWeightStrong
    }

    FixedText {
        id: valueText

        anchors.right: parent.right
        y: -2
        text: root.value
        font.pixelSize: Theme.fontLg + 2
    }

    Txt {
        y: 26
        width: parent.width
        text: root.subtitle
        color: Theme.textMuted
        font.pixelSize: Theme.fontSm - 1
    }

    Sparkline {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 42
        visible: root.history !== null
        values: root.history || []
        max: root.historyMax
    }
}
