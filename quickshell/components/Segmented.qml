import QtQuick
import qs.config

// Auswahl aus wenigen Optionen nebeneinander, die aktive ist weiss gefuellt.
// options: [{ value: "off", label: "Off" }, ...]
Row {
    id: root

    property var options: []
    property string value: ""

    signal picked(string value)

    spacing: 4

    Repeater {
        model: root.options

        delegate: Rectangle {
            id: seg

            required property var modelData
            readonly property bool active: seg.modelData.value === root.value

            width: Math.floor((root.width - root.spacing * (root.options.length - 1)) / root.options.length)
            height: 34
            radius: Theme.radiusSm
            color: seg.active ? Theme.accent : (segArea.pressed ? Theme.pressed : (segArea.containsMouse ? Theme.hover : Theme.layer3))
            border.width: 1
            border.color: seg.active ? Theme.accent : Theme.border

            Behavior on color {
                CAnim {}
            }

            Txt {
                anchors.centerIn: parent
                text: seg.modelData.label
                color: seg.active ? Theme.accentFg : Theme.fg
                font.weight: seg.active ? Theme.weightStrong : Theme.weight
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
