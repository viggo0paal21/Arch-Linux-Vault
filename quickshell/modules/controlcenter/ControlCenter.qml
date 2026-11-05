import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.notifications

// Control center top right: quick settings, volume, media, notifications.
OverlayPanel {
    id: panel

    readonly property int topOffset: Ui.barBottomTarget + Theme.gap

    open: Ui.panel === "control"
    screen: Ui.panelScreen
    ns: "qs-control"
    animDuration: Theme.durSlow
    animGroup: "panel"
    onDismissed: Ui.close()

    // Slides out from under the bar
    DropdownSlot {
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
        width: 420
        contentHeight: card.height
        progress: panel.progress

        Card {
            id: card

            width: parent.width
            height: Math.min(col.implicitHeight + 2 * Theme.pad, panel.height - panel.topOffset - Theme.gap)
            clip: true

            Flickable {
                id: flick

                anchors.fill: parent
                anchors.margins: Theme.pad
                contentWidth: width
                contentHeight: col.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: col

                    width: flick.width
                    spacing: 14

                    // Header
                    Item {
                        width: col.width
                        height: 40

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Rectangle {
                                width: 36
                                height: 36
                                radius: Theme.radius
                                color: Theme.layer2
                                border.width: 1
                                border.color: Theme.border

                                Glyph {
                                    anchors.centerIn: parent
                                    text: Icons.account
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter

                                Txt {
                                    text: Quickshell.env("USER") || "User"
                                    font.weight: Theme.weightStrong
                                }

                                Txt {
                                    text: "Up " + SysInfo.formatUptime(SysInfo.uptime)
                                    color: Theme.fgMuted
                                    font.pixelSize: Theme.fontSm
                                }
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            IconButton {
                                icon: Icons.reload
                                idleColor: Theme.layer2
                                onClicked: Quickshell.reload(false)
                            }

                            IconButton {
                                icon: Icons.cog
                                idleColor: Theme.layer2
                                onClicked: Ui.open("settings", Ui.panelScreen)
                            }

                            IconButton {
                                icon: Icons.lock
                                idleColor: Theme.layer2
                                onClicked: {
                                    Ui.close();
                                    Quickshell.execDetached(["sh", "-c", Config.opts.lockCommand]);
                                }
                            }

                            IconButton {
                                icon: Icons.power
                                idleColor: Theme.layer2
                                onClicked: Ui.open("power", Ui.panelScreen)
                            }
                        }
                    }

                    // Quick settings
                    Grid {
                        width: col.width
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8

                        Tile {
                            width: (col.width - 8) / 2
                            icon: Net.icon()
                            title: Net.connected ? (Net.wifi ? "Wi-Fi" : "Ethernet") : "Network"
                            subtitle: Net.connected ? (Net.limited ? "Limited" : Net.name) : "Disconnected"
                            active: Net.connected
                            onClicked: {
                                Ui.close();
                                Quickshell.execDetached(["sh", "-c", "command -v nm-connection-editor >/dev/null && exec nm-connection-editor || exec " + Config.opts.terminal + " -e nmtui"]);
                            }
                        }

                        Tile {
                            width: (col.width - 8) / 2
                            icon: Bt.enabled ? Icons.bluetooth : Icons.bluetoothOff
                            title: "Bluetooth"
                            subtitle: !Bt.available ? "No adapter" : (!Bt.enabled ? "Off" : (Bt.connected.length > 0 ? Bt.connected[0].name : "On"))
                            active: Bt.enabled
                            onClicked: Bt.toggle()
                            onRightClicked: {
                                Ui.close();
                                Quickshell.execDetached(["sh", "-c", "command -v blueman-manager >/dev/null && exec blueman-manager || exec " + Config.opts.terminal + " -e bluetoothctl"]);
                            }
                        }

                        Tile {
                            width: (col.width - 8) / 2
                            icon: Notifs.dnd ? Icons.bellOff : Icons.bell
                            title: "Do not disturb"
                            subtitle: Notifs.dnd ? "On" : "Off"
                            active: Notifs.dnd
                            onClicked: Notifs.toggleDnd()
                        }

                        Tile {
                            width: (col.width - 8) / 2
                            icon: Ui.caffeine ? Icons.coffee : Icons.coffeeOutline
                            title: "Stay awake"
                            subtitle: Ui.caffeine ? "No sleep" : "Off"
                            active: Ui.caffeine
                            onClicked: Ui.caffeine = !Ui.caffeine
                        }

                        Tile {
                            width: (col.width - 8) / 2
                            icon: Icons.moon
                            title: "Night light"
                            subtitle: !NightLight.installed ? "hyprsunset missing" : (NightLight.active ? NightLight.temperature + " K" : "Off")
                            active: NightLight.active
                            opacity: NightLight.installed ? 1 : 0.5
                            onClicked: NightLight.toggle()
                        }

                        Tile {
                            width: (col.width - 8) / 2
                            icon: Audio.micMuted ? Icons.micOff : Icons.mic
                            title: "Microphone"
                            subtitle: !Audio.hasSource ? "No device" : (Audio.micMuted ? "Muted" : Math.round(Audio.micVolume * 100) + "%")
                            active: Audio.hasSource && !Audio.micMuted
                            onClicked: Audio.toggleMicMute()
                        }
                    }

                    // Volume
                    Rectangle {
                        width: col.width
                        height: audioCol.implicitHeight + 24
                        radius: Theme.radius
                        color: Theme.layer2
                        border.width: 1
                        border.color: Theme.border

                        Column {
                            id: audioCol

                            x: 12
                            y: 12
                            width: parent.width - 24
                            spacing: 10

                            Row {
                                width: audioCol.width
                                spacing: 10

                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: Audio.icon()
                                    onClicked: Audio.toggleMute()
                                }

                                SliderBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: audioCol.width - 30 - 52 - 20
                                    value: Audio.muted ? 0 : Audio.volume
                                    enabled: Audio.hasSink
                                    onMoved: v => Audio.setVolume(v)
                                }

                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 52
                                    horizontalAlignment: Text.AlignRight
                                    text: Math.round(Audio.volume * 100) + "%"
                                    color: Audio.muted ? Theme.fgMuted : Theme.fg
                                }
                            }

                            Row {
                                width: audioCol.width
                                spacing: 10
                                visible: Audio.hasSource

                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: Audio.micMuted ? Icons.micOff : Icons.mic
                                    onClicked: Audio.toggleMicMute()
                                }

                                SliderBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: audioCol.width - 30 - 52 - 20
                                    value: Audio.micMuted ? 0 : Audio.micVolume
                                    onMoved: v => Audio.setMicVolume(v)
                                }

                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 52
                                    horizontalAlignment: Text.AlignRight
                                    text: Math.round(Audio.micVolume * 100) + "%"
                                    color: Audio.micMuted ? Theme.fgMuted : Theme.fg
                                }
                            }

                            Txt {
                                width: audioCol.width
                                text: Audio.sinkName
                                color: Theme.fgMuted
                                font.pixelSize: Theme.fontSm
                            }
                        }
                    }

                    MediaCard {
                        width: col.width
                        visible: Media.player !== null
                    }

                    // Notifications
                    Item {
                        width: col.width
                        height: 30

                        Txt {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: Notifs.count > 0 ? "Notifications (" + Notifs.count + ")" : "Notifications"
                            font.weight: Theme.weightStrong
                        }

                        IconButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            size: 30
                            visible: Notifs.count > 0
                            icon: Icons.clearAll
                            label: "Clear all"
                            onClicked: Notifs.clearAll()
                        }
                    }

                    Column {
                        width: col.width
                        spacing: 8

                        Repeater {
                            model: Array.from(Notifs.list).reverse()

                            delegate: NotifCard {
                                required property var modelData

                                width: col.width
                                notif: modelData
                                compact: true
                            }
                        }
                    }

                    Item {
                        width: col.width
                        height: 80
                        visible: Notifs.count === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Glyph {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Icons.bellOutline
                                color: Theme.fgMuted
                                font.pixelSize: 26
                            }

                            Txt {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "All caught up"
                                color: Theme.fgMuted
                            }
                        }
                    }
                }
            }
        }
    }
}
