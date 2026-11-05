import QtQuick
import qs.config
import qs.services

// Surface for panels. Catches clicks so that clicking inside the panel doesn't close it.
Rectangle {
    color: Glass.popupBg
    radius: Theme.radiusLg
    border.width: 1
    border.color: Theme.border

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }
}
