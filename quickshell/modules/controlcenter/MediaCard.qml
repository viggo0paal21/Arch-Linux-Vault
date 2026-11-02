import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Aktueller Mediaplayer (MPRIS): Cover, Titel, Fortschritt, Steuerung.
Rectangle {
    id: root

    readonly property var player: Media.player
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property real position: player && player.positionSupported ? player.position : 0

    height: 112
    radius: Theme.radius
    color: Theme.layer2
    border.width: 1
    border.color: Theme.border

    Timer {
        running: root.visible && root.player !== null && root.player.isPlaying
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    ClippingRectangle {
        id: art

        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 88
        height: 88
        radius: Theme.radiusSm
        color: Theme.layer3

        Image {
            anchors.fill: parent
            visible: status === Image.Ready
            source: root.player ? (root.player.trackArtUrl || "") : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 176
            sourceSize.height: 176
            layer.enabled: Config.opts.monochromeIcons
            layer.effect: MultiEffect {
                saturation: -1.0
            }
        }

        Glyph {
            anchors.centerIn: parent
            text: Icons.music
            color: Theme.fgMuted
            font.pixelSize: 30
            visible: !root.player || !root.player.trackArtUrl
        }
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Txt {
            width: parent.width
            text: root.player ? (root.player.trackTitle || root.player.identity || "Unknown") : ""
            font.weight: Theme.weightStrong
        }

        Txt {
            width: parent.width
            text: root.player ? (root.player.trackArtist || root.player.identity || "") : ""
            color: Theme.fgDim
            font.pixelSize: Theme.fontSm
        }

        Meter {
            width: parent.width
            visible: root.length > 0
            value: root.length > 0 ? root.position / root.length : 0
        }

        Item {
            width: parent.width
            height: 30

            Txt {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: root.length > 0
                text: Media.fmt(root.position) + " / " + Media.fmt(root.length)
                color: Theme.fgMuted
                font.pixelSize: Theme.fontSm
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                IconButton {
                    size: 30
                    icon: Icons.prev
                    opacity: root.player && root.player.canGoPrevious ? 1 : 0.35
                    onClicked: {
                        if (root.player && root.player.canGoPrevious)
                            root.player.previous();
                    }
                }

                IconButton {
                    size: 30
                    icon: root.player && root.player.isPlaying ? Icons.pause : Icons.play
                    active: true
                    onClicked: {
                        if (root.player && root.player.canTogglePlaying)
                            root.player.togglePlaying();
                    }
                }

                IconButton {
                    size: 30
                    icon: Icons.next
                    opacity: root.player && root.player.canGoNext ? 1 : 0.35
                    onClicked: {
                        if (root.player && root.player.canGoNext)
                            root.player.next();
                    }
                }
            }
        }
    }
}
