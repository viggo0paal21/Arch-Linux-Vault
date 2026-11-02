import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Dashboard unter dem Uhr-/System-Kaestchen der Leiste: grosse Uhr, Kalender, Systemmonitor.
OverlayPanel {
    id: panel

    readonly property int topOffset: Ui.barBottomTarget + Theme.gap
    readonly property var enLocale: Qt.locale("en_US")

    open: Ui.panel === "dashboard"
    screen: Ui.panelScreen
    ns: "qs-dashboard"
    animDuration: Theme.durSlow
    onDismissed: Ui.close()
    onOpenChanged: {
        if (open)
            calendar.reset();
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
        enabled: panel.mapped
    }

    // Gleitet unter der Leiste hervor, rechtsbuendig unter dem Uhr-/System-Kaestchen
    DropdownSlot {
        id: slot

        readonly property var chipRight: Ui.infoChipRight[Ui.panelScreen ? Ui.panelScreen.name : ""]

        x: slot.chipRight === undefined ? Math.round((panel.width - slot.width) / 2) : Math.max(Theme.gap, Math.min(panel.width - slot.width - Theme.gap, Math.round(slot.chipRight - slot.width)))
        width: Math.min(800, panel.width - 2 * Theme.gap)
        contentHeight: card.height
        progress: panel.progress

        Card {
            id: card

            width: parent.width
            height: Math.min(dashContent.implicitHeight + 2 * 18, panel.height - panel.topOffset - Theme.gap)
            clip: true

            Row {
                id: dashContent

                x: 18
                y: 18
                spacing: 18

                // Links: Uhr + Kalender
                Column {
                    id: leftCol

                    width: 300
                    spacing: 16

                    Column {
                        width: parent.width
                        spacing: 2

                        Txt {
                            text: Qt.formatDateTime(clock.date, Config.opts.clock24h ? "HH:mm" : "h:mm AP")
                            font.pixelSize: 56
                            font.weight: Theme.weight
                        }

                        Txt {
                            text: clock.date.toLocaleString(panel.enLocale, "dddd, MMMM d, yyyy")
                            color: Theme.fgDim
                        }
                    }

                    Sep {
                        width: parent.width
                    }

                    CalendarView {
                        id: calendar

                        width: parent.width
                    }
                }

                Sep {
                    vertical: true
                    height: Math.max(leftCol.implicitHeight, rightCol.implicitHeight)
                }

                // Rechts: Systemmonitor
                Column {
                    id: rightCol

                    width: card.width - 36 - leftCol.width - 2 * dashContent.spacing - 1
                    spacing: 10

                    Grid {
                        width: parent.width
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 10

                        StatCard {
                            width: (rightCol.width - 10) / 2
                            icon: Icons.cpu
                            title: "CPU"
                            value: Math.round(SysInfo.cpu * 100) + "%"
                            subtitle: SysInfo.cpuTemp > 0 ? Math.round(SysInfo.cpuTemp) + " °C" : "Temperature unknown"
                            history: SysInfo.cpuHistory
                        }

                        StatCard {
                            width: (rightCol.width - 10) / 2
                            icon: Icons.gpu
                            title: "GPU"
                            value: SysInfo.gpuAvailable ? Math.round(SysInfo.gpu * 100) + "%" : "–"
                            subtitle: SysInfo.gpuAvailable ? Math.round(SysInfo.gpuTemp) + " °C  ·  " + SysInfo.formatBytes(SysInfo.vramUsed) + " / " + SysInfo.formatBytes(SysInfo.vramTotal) : (Config.opts.gpuMonitor ? "nvidia-smi not found" : "Off (settings)")
                            history: SysInfo.gpuHistory
                        }
                    }

                    // Arbeitsspeicher
                    Rectangle {
                        width: parent.width
                        height: memCol.implicitHeight + 28
                        radius: Theme.radius
                        color: Theme.layer2
                        border.width: 1
                        border.color: Theme.border

                        Column {
                            id: memCol

                            x: 14
                            y: 14
                            width: parent.width - 28
                            spacing: 8

                            Item {
                                width: parent.width
                                height: 20

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10

                                    Glyph {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Icons.ram
                                        color: Theme.fgDim
                                    }

                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Memory"
                                        color: Theme.fgDim
                                    }
                                }

                                Txt {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SysInfo.formatBytes(SysInfo.memUsed) + " / " + SysInfo.formatBytes(SysInfo.memTotal)
                                }
                            }

                            Meter {
                                width: parent.width
                                value: SysInfo.mem
                            }

                            Txt {
                                visible: SysInfo.swapTotal > 0
                                text: "Swap " + SysInfo.formatBytes(SysInfo.swapUsed) + " / " + SysInfo.formatBytes(SysInfo.swapTotal)
                                color: Theme.fgMuted
                                font.pixelSize: Theme.fontSm
                            }
                        }
                    }

                    // Laufwerke
                    Rectangle {
                        width: parent.width
                        height: diskCol.implicitHeight + 28
                        radius: Theme.radius
                        color: Theme.layer2
                        border.width: 1
                        border.color: Theme.border

                        Column {
                            id: diskCol

                            x: 14
                            y: 14
                            width: parent.width - 28
                            spacing: 10

                            Row {
                                spacing: 10

                                Glyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Icons.disk
                                    color: Theme.fgDim
                                }

                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Disks"
                                    color: Theme.fgDim
                                }
                            }

                            Repeater {
                                model: SysInfo.disks

                                delegate: Column {
                                    id: diskItem

                                    required property var modelData

                                    width: diskCol.width
                                    spacing: 6

                                    Item {
                                        width: parent.width
                                        height: 18

                                        Txt {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: diskItem.modelData.mount
                                        }

                                        Txt {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: SysInfo.formatBytes(diskItem.modelData.used) + " / " + SysInfo.formatBytes(diskItem.modelData.size)
                                            color: Theme.fgDim
                                        }
                                    }

                                    Meter {
                                        width: parent.width
                                        value: diskItem.modelData.size > 0 ? diskItem.modelData.used / diskItem.modelData.size : 0
                                    }
                                }
                            }

                            Txt {
                                visible: SysInfo.disks.length === 0
                                text: "Reading …"
                                color: Theme.fgMuted
                            }
                        }
                    }

                    StatCard {
                        width: parent.width
                        icon: Icons.arrowDown
                        title: "Network"
                        value: "↓ " + SysInfo.formatRate(SysInfo.rxRate)
                        subtitle: "↑ " + SysInfo.formatRate(SysInfo.txRate) + "  ·  " + (Net.connected ? Net.name : "disconnected") + "  ·  up " + SysInfo.formatUptime(SysInfo.uptime)
                        history: SysInfo.rxHistory
                        historyMax: Math.max(1024 * 64, ...SysInfo.rxHistory)
                    }
                }
            }
        }
    }
}
