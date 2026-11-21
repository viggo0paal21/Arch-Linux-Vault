import QtQuick
import qs.config
import qs.services

// Surface for panels. Catches clicks so that clicking inside the panel doesn't close it.
Rectangle {
    color: Glass.popupBg
    radius: Theme.radiusLg
    // Hairline instead of a grey border: just the edge, no more boxes inside
    border.width: 1
    border.color: Theme.hairline

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }
}
