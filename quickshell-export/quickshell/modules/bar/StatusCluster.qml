import QtQuick
import qs.config
import qs.components
import qs.services

// Netz, Bluetooth, Lautstaerke, Mikro, Benachrichtigungen. Klick = Kontrollzentrum.
// Mausrad = Lautstaerke, Mittelklick = stumm.
BarChip {
    id: root

    spacing: 12
    onScrolled: delta => {
        if (delta > 0)
            Audio.up();
        else if (delta < 0)
            Audio.down();
    }
    onMiddleClicked: Audio.toggleMute()

    Glyph {
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: Theme.barIconSize
        text: Net.icon()
        color: Net.connected ? root.fg : root.fgDim
    }

    Glyph {
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: Theme.barIconSize
        visible: Bt.enabled
        text: Bt.connected.length > 0 ? Icons.bluetoothOn : Icons.bluetooth
        color: root.fg
    }

    Glyph {
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: Theme.barIconSize
        visible: Audio.hasSource && Audio.micMuted
        text: Icons.micOff
        color: root.fgDim
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Theme.barIconSize
            text: Audio.icon()
            color: root.fg
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%"
            color: Audio.muted ? root.fgDim : root.fg
        }
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: bell.implicitWidth
        height: bell.implicitHeight

        Glyph {
            id: bell

            font.pixelSize: Theme.barIconSize
            text: Notifs.dnd ? Icons.bellOff : (Notifs.count > 0 ? Icons.bellBadge : Icons.bellOutline)
            color: root.fg
        }
    }
}
