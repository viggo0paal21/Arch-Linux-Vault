import QtQuick
import qs.config

// Duenner Fortschrittsbalken (0..1)
Rectangle {
    id: root

    property real value: 0

    implicitHeight: 4
    radius: height / 2
    color: Theme.layer3

    Rectangle {
        width: Math.max(root.height, root.width * Math.max(0, Math.min(1, root.value)))
        height: parent.height
        radius: parent.radius
        color: Theme.fg

        Behavior on width {
            Anim {}
        }
    }
}
