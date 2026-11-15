import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Current media player (MPRIS): cover, title, controls, progress below. No box of its own,
// same heading as "Sound" and "Notifications".
Rectangle {
    id: root

    readonly property var player: Media.player
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property real position: player && player.positionSupported ? player.position : 0

    height: content.implicitHeight
    color: "transparent"

    Timer {
        running: root.visible && root.player !== null && root.player.isPlaying
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Column {
        id: content

        width: parent.width
        spacing: 10

        Item {
            width: parent.width
            height: 20

            Txt {
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                text: "Now playing"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSm
                font.weight: Theme.uiWeightStrong
            }

            Txt {
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                text: root.player ? (root.player.identity || "") : ""
                color: Theme.textMuted
                font.pixelSize: Theme.fontSm
            }
        }

        Item {
            width: parent.width
            height: 52

            ClippingRectangle {
                id: art

                anchors.verticalCenter: parent.verticalCenter
                width: 52
                height: 52
                radius: Theme.radiusSm
                color: Theme.fill

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
                    color: Theme.textMuted
                    font.pixelSize: 22
                    visible: !root.player || !root.player.trackArtUrl
                }
            }

            Column {
                anchors.left: art.right
                anchors.leftMargin: 12
                anchors.right: controls.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Txt {
                    width: parent.width
                    text: root.player ? (root.player.trackTitle || root.player.identity || "Unknown") : ""
                }

                Txt {
                    width: parent.width
                    text: root.player ? (root.player.trackArtist || root.player.identity || "") : ""
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSm
                }
            }

            Row {
                id: controls

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 30
                    fg: Theme.textDim
                    icon: Icons.prev
                    opacity: root.player && root.player.canGoPrevious ? 1 : 0.35
                    onClicked: {
                        if (root.player && root.player.canGoPrevious)
                            root.player.previous();
                    }
                }

                // Play/pause: just the icon, bigger and white (no circle)
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 36
                    iconSize: Theme.iconSize + 6
                    icon: root.player && root.player.isPlaying ? Icons.pause : Icons.play
                    onClicked: {
                        if (root.player && root.player.canTogglePlaying)
                            root.player.togglePlaying();
                    }
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 30
                    fg: Theme.textDim
                    icon: Icons.next
                    opacity: root.player && root.player.canGoNext ? 1 : 0.35
                    onClicked: {
                        if (root.player && root.player.canGoNext)
                            root.player.next();
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 5
            visible: root.length > 0

            Meter {
                width: parent.width
                height: 5
                value: root.length > 0 ? root.position / root.length : 0
            }

            Item {
                width: parent.width
                height: 16

                FixedText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Media.fmt(root.position)
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontXs
                }

                FixedText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Media.fmt(root.length)
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontXs
                }
            }
        }
    }
}
