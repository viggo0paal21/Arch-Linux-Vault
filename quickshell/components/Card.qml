import QtQuick
import qs.config
import qs.services

// Flaeche fuer Panels. Faengt Klicks ab, damit Klicks im Panel es nicht schliessen.
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
