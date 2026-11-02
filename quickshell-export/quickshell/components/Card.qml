import QtQuick
import qs.config

// Flaeche fuer Panels. Faengt Klicks ab, damit Klicks im Panel es nicht schliessen.
Rectangle {
    color: Theme.layer1
    radius: Theme.radiusLg
    border.width: 1
    border.color: Theme.border

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }
}
