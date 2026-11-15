import QtQuick
import qs.config

// Pick one of a few options side by side: one shared track, the active option gets a lighter background.
// options: [{ value: "off", label: "Off" }, ...]
Item {
    id: root

    property var options: []
    property string value: ""
    property int spacing: 2

    signal picked(string value)

    implicitWidth: row.implicitWidth + 6
    implicitHeight: 34

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm + 2
        color: Theme.fill
    }

    Row {
        id: row

        x: 3
        y: 3
        spacing: root.spacing

        Repeater {
            model: root.options

            delegate: Rectangle {
                id: seg

                required property var modelData
                readonly property bool active: seg.modelData.value === root.value

                width: Math.floor((root.width - 6 - root.spacing * (root.options.length - 1)) / root.options.length)
                height: root.height - 6
                radius: Theme.radiusSm
                color: seg.active ? Theme.fillStrong : (segArea.pressed ? Theme.fill : (segArea.containsMouse ? Theme.fill : "transparent"))

                Behavior on color {
                    CAnim {}
                }

                Txt {
                    anchors.centerIn: parent
                    text: seg.modelData.label
                    color: seg.active ? Theme.fg : Theme.textDim
                    font.pixelSize: Theme.fontSm + 1
                    font.weight: seg.active ? Theme.uiWeightStrong : Theme.uiWeight
                }

                MouseArea {
                    id: segArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(seg.modelData.value)
                }
            }
        }
    }
}
