import QtQuick
import qs.config
import qs.components
import qs.services

// CPU / RAM / Temperatur kompakt. Sitzt zusammen mit der Uhr in einem Kaestchen der Leiste,
// "fg"/"fgDim" kommen von dort (weiss auf schwarz, schwarz auf weiss wenn aktiv).
Row {
    id: root

    property color fg: Theme.fg
    property color fgDim: Theme.fgDim

    spacing: 12

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.cpu
            color: root.fgDim
            font.pixelSize: Theme.barIconSize
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(SysInfo.cpu * 100) + "%"
            color: root.fg
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.ram
            color: root.fgDim
            font.pixelSize: Theme.barIconSize
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(SysInfo.mem * 100) + "%"
            color: root.fg
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        visible: SysInfo.cpuTemp > 0

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.temp
            color: root.fgDim
            font.pixelSize: Theme.barIconSize
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(SysInfo.cpuTemp) + "°"
            color: root.fg
        }
    }
}
