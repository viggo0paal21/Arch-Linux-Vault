import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Dashboard below the bar's clock/system box: big clock, calendar, system monitor.
OverlayPanel {
    id: panel

    readonly property int topOffset: Ui.barBottomTarget + Theme.gap
    readonly property var enLocale: Qt.locale("en_US")

    open: Ui.panel === "dashboard"
    screen: Ui.panelScreen
    ns: "qs-dashboard"
    animDuration: Theme.durSlow
    animGroup: "panel"
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

    // Slides out from under the bar, right-aligned below the clock/system box
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
            height: Math.min(dashContent.implicitHeight + 22 + 24, panel.height - panel.topOffset - Theme.gap)
            clip: true

            Row {
                id: dashContent

                x: 24
                y: 22
                spacing: 28

                // Left: clock + calendar
                Column {
                    id: leftCol

                    width: 290
                    spacing: 26

                    Column {
                        width: parent.width
                        spacing: 0

                        // Big clock, thin and with equal-width digits (does not jump when the minute changes)
                        FixedText {
                            x: -3
                            text: Qt.formatDateTime(clock.date, Config.opts.clock24h ? "HH:mm" : "h:mm AP")
                            font.pixelSize: 64
                            font.weight: Theme.uiWeightLight
                        }

                        Txt {
                            text: clock.date.toLocaleString(panel.enLocale, "dddd, MMMM d")
                            color: Theme.textDim
                        }
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

                // Right: system monitor, no boxes, groups only by spacing and small headings
                Column {
                    id: rightCol

                    width: card.width - 48 - leftCol.width - 2 * dashContent.spacing - 1
                    spacing: 24

                    Row {
                        width: parent.width
                        spacing: 24

                        StatCard {
                            width: Math.floor((rightCol.width - 24) / 2)
                            title: "CPU"
                            value: Math.round(SysInfo.cpu * 100) + "%"
                            subtitle: SysInfo.cpuTemp > 0 ? Math.round(SysInfo.cpuTemp) + " °C" : "Temperature unknown"
                            history: SysInfo.cpuHistory
                        }

                        StatCard {
                            width: Math.floor((rightCol.width - 24) / 2)
                            title: "GPU"
                            value: SysInfo.gpuAvailable ? Math.round(SysInfo.gpu * 100) + "%" : "–"
                            subtitle: SysInfo.gpuAvailable ? Math.round(SysInfo.gpuTemp) + " °C  ·  " + SysInfo.formatBytes(SysInfo.vramUsed) + " / " + SysInfo.formatBytes(SysInfo.vramTotal) : (Config.opts.gpuMonitor ? "nvidia-smi not found" : "Off (settings)")
                            history: SysInfo.gpuHistory
                        }
                    }

                    // Memory
                    Column {
                        width: parent.width
                        spacing: 8

                        Item {
                            width: parent.width
                            height: 20

                            Txt {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Memory"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSm
                                font.weight: Theme.uiWeightStrong
                            }

                            FixedText {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: SysInfo.formatBytes(SysInfo.memUsed) + " / " + SysInfo.formatBytes(SysInfo.memTotal)
                                color: Theme.textDim
                                font.pixelSize: Theme.fontSm + 1
                            }
                        }

                        Meter {
                            width: parent.width
                            height: 6
                            value: SysInfo.mem
                        }

                        FixedText {
                            visible: SysInfo.swapTotal > 0
                            text: "Swap " + SysInfo.formatBytes(SysInfo.swapUsed) + " / " + SysInfo.formatBytes(SysInfo.swapTotal)
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm - 1
                        }
                    }

                    // Drives
                    Column {
                        width: parent.width
                        spacing: 10

                        Txt {
                            text: "Disks"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.uiWeightStrong
                        }

                        Repeater {
                            model: SysInfo.disks

                            delegate: Column {
                                id: diskItem

                                required property var modelData

                                width: rightCol.width
                                spacing: 6

                                Item {
                                    width: parent.width
                                    height: 18

                                    Txt {
                                        anchors.left: parent.left
                                        anchors.right: diskSize.left
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: diskItem.modelData.mount
                                        font.pixelSize: Theme.fontSm + 1
                                    }

                                    FixedText {
                                        id: diskSize

                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: SysInfo.formatBytes(diskItem.modelData.used) + " / " + SysInfo.formatBytes(diskItem.modelData.size)
                                        color: Theme.textDim
                                        font.pixelSize: Theme.fontSm + 1
                                    }
                                }

                                Meter {
                                    width: parent.width
                                    height: 6
                                    value: diskItem.modelData.size > 0 ? diskItem.modelData.used / diskItem.modelData.size : 0
                                }
                            }
                        }

                        Txt {
                            visible: SysInfo.disks.length === 0
                            text: "Reading …"
                            color: Theme.textMuted
                        }
                    }

                    StatCard {
                        width: parent.width
                        title: "Network"
                        value: "↓ " + SysInfo.formatRate(SysInfo.rxRate)
                        subtitle: "↑ " + SysInfo.formatRate(SysInfo.txRate) + "  ·  " + (Net.connected ? Net.name : "disconnected")
                        history: SysInfo.rxHistory
                        historyMax: Math.max(1024 * 64, ...SysInfo.rxHistory)
                    }
                }
            }
        }
    }
}
