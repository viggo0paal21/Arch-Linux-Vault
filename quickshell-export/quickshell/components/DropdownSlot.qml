import QtQuick
import qs.config

// Bereich direkt unter der Leiste. Beim Oeffnen faehrt das ganze Panel unter der
// Leiste hervor nach unten, beim Schliessen wieder hoch. Der Bereich schneidet an der
// Leisten-Unterkante ab, dadurch sieht es aus, als kaeme es hinter der Leiste heraus.
Item {
    id: root

    property real progress: 0
    property real contentHeight: 0
    default property alias content: inner.data

    readonly property real fullHeight: root.contentHeight + Theme.gap + 2

    y: Theme.barBottom
    height: root.fullHeight
    clip: true

    Item {
        id: inner

        // zu: komplett oberhalb (hinter der Leiste), offen: knapp unter der Leiste
        y: Theme.gap - root.fullHeight * (1 - root.progress)
        width: parent.width
        height: root.contentHeight
    }
}
