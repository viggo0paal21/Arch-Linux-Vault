import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Einstellungen: Tabs links im Stil des Launchers, rechts die Optionen mit viel Luft.
// Alles wird sofort angewendet und automatisch gespeichert.
// Tastatur: Tab / Shift+Tab oder Pfeil hoch/runter wechseln den Tab, Esc schliesst.
OverlayPanel {
    id: panel

    property int tab: 0
    readonly property var tabs: [
        {
            name: "Appearance",
            hint: "Transparency, corners, fonts, icons",
            icon: Icons.palette
        },
        {
            name: "Bar",
            hint: "Size, look and what it shows",
            icon: Icons.dockTop
        },
        {
            name: "Behavior",
            hint: "Animations, notifications, volume",
            icon: Icons.cogOutline
        },
        {
            name: "Commands",
            hint: "Terminal and lock screen",
            icon: Icons.consoleLine
        }
    ]

    function switchTab(delta) {
        panel.tab = (panel.tab + delta + panel.tabs.length) % panel.tabs.length;
    }

    open: Ui.panel === "settings"
    screen: Ui.panelScreen
    dim: true
    dimOpacity: 0.45
    ns: "qs-settings"
    onDismissed: Ui.close()
    onTabChanged: {
        flick.contentY = 0;
        tabIn.restart();
    }

    component SwitchCtl: Toggle {
        anchors.right: parent ? parent.right : undefined
    }

    Card {
        id: card

        readonly property int tabHeight: 56

        // Nur Einblenden + kurzes Gleiten, immer auf ganze Pixel: Text bleibt in jedem Frame scharf
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2 + 12 * (1 - panel.progress))
        width: Math.min(940, parent.width - 80)
        height: Math.min(700, parent.height - 140)
        opacity: panel.progress
        focus: true

        Keys.onTabPressed: panel.switchTab(1)
        Keys.onBacktabPressed: panel.switchTab(-1)
        Keys.onDownPressed: panel.switchTab(1)
        Keys.onUpPressed: panel.switchTab(-1)

        // ---------- Links: Tabs ----------
        Item {
            id: sidebar

            x: 14
            y: 14
            width: 250
            height: parent.height - 28

            Row {
                id: sideHeader

                x: 14
                height: 48
                spacing: 12

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.tune
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Settings"
                    font.pixelSize: Theme.fontLg + 3
                    font.weight: Theme.weightStrong
                }
            }

            ListView {
                id: tabList

                anchors.top: sideHeader.bottom
                anchors.topMargin: 14
                width: parent.width
                height: count * card.tabHeight + (count - 1) * spacing
                spacing: 6
                interactive: false
                model: panel.tabs
                currentIndex: panel.tab
                highlightMoveDuration: Theme.durFast
                highlightFollowsCurrentItem: true

                highlight: Rectangle {
                    radius: Theme.radius
                    color: Theme.layer3
                    border.width: 1
                    border.color: Theme.borderStrong
                }

                delegate: Item {
                    id: tabRow

                    required property var modelData
                    required property int index
                    readonly property bool current: tabRow.index === panel.tab

                    width: tabList.width
                    height: card.tabHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius
                        color: Theme.hover
                        opacity: tabArea.containsMouse && !tabRow.current ? 1 : 0

                        Behavior on opacity {
                            Anim {
                                duration: Theme.durFast
                            }
                        }
                    }

                    Glyph {
                        id: tabIcon

                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        text: tabRow.modelData.icon
                        color: tabRow.current ? Theme.fg : Theme.fgDim
                    }

                    Column {
                        anchors.left: tabIcon.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Txt {
                            width: parent.width
                            text: tabRow.modelData.name
                            color: tabRow.current ? Theme.fg : Theme.fgDim
                            font.weight: tabRow.current ? Theme.weightStrong : Theme.weight
                        }

                        Txt {
                            width: parent.width
                            text: tabRow.modelData.hint
                            color: Theme.fgMuted
                            font.pixelSize: Theme.fontSm
                        }
                    }

                    MouseArea {
                        id: tabArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.tab = tabRow.index
                    }
                }
            }

            // Unten: Zuruecksetzen + Speicherort
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 12

                IconButton {
                    x: 4
                    size: 40
                    icon: Icons.restart
                    label: "Reset to defaults"
                    idleColor: Theme.layer2
                    onClicked: Config.reset()
                }

                Txt {
                    x: 8
                    width: parent.width - 16
                    text: "Saved automatically to " + Quickshell.statePath("settings.json")
                    color: Theme.fgMuted
                    font.pixelSize: Theme.fontSm
                    wrapMode: Text.WrapAnywhere
                }
            }
        }

        Rectangle {
            id: divider

            x: sidebar.x + sidebar.width + 14
            y: 14
            width: 1
            height: parent.height - 28
            color: Theme.border
        }

        // ---------- Rechts: Optionen des Tabs ----------
        Item {
            id: content

            x: divider.x + 1 + 22
            y: 14
            width: parent.width - x - 14
            height: parent.height - 28

            Item {
                id: contentHeader

                width: parent.width
                height: 48

                Txt {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.tabs[panel.tab].name
                    font.pixelSize: Theme.fontLg + 3
                    font.weight: Theme.weightStrong
                }

                IconButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    size: 40
                    icon: Icons.close
                    idleColor: Theme.layer2
                    onClicked: Ui.close()
                }
            }

            Flickable {
                id: flick

                anchors.top: contentHeader.bottom
                anchors.topMargin: 14
                anchors.bottom: parent.bottom
                width: parent.width - 14
                contentWidth: width
                contentHeight: pages.height
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Item {
                    id: pages

                    property real shift: 0

                    width: flick.width
                    height: [pageAppearance, pageBar, pageBehavior, pageCommands][panel.tab].implicitHeight

                    transform: Translate {
                        y: Math.round(pages.shift)
                    }

                    // ----- Appearance -----
                    Column {
                        id: pageAppearance

                        width: parent.width
                        spacing: 10
                        visible: panel.tab === 0

                        SettingRow {
                            width: parent.width
                            label: "Transparency"
                            description: "Translucent black with Hyprland blur"
                            controlWidth: 330

                            Segmented {
                                width: parent.width
                                options: [
                                    {
                                        value: "off",
                                        label: "Off"
                                    },
                                    {
                                        value: "popups",
                                        label: "Popups"
                                    },
                                    {
                                        value: "everywhere",
                                        label: "Everywhere"
                                    }
                                ]
                                value: Config.opts.transparency
                                onPicked: v => Config.opts.transparency = v
                            }
                        }

                        SettingRow {
                            width: parent.width
                            visible: Config.opts.transparency === "popups"
                            label: "Solid popups with windows"
                            description: "Popups turn black as soon as 1 or more windows are open (floating ones don't count)"

                            SwitchCtl {
                                checked: Config.opts.popupsSolidWithWindows
                                onToggled: Config.opts.popupsSolidWithWindows = !Config.opts.popupsSolidWithWindows
                            }
                        }

                        SettingRow {
                            width: parent.width
                            visible: Config.opts.transparency === "everywhere"
                            label: "Solid bar with windows"
                            description: "The bar turns black as soon as 1 or more windows are open (floating ones don't count)"

                            SwitchCtl {
                                checked: Config.opts.barSolidWithWindows
                                onToggled: Config.opts.barSolidWithWindows = !Config.opts.barSolidWithWindows
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Corner radius"
                            description: "0 = square, 8 = slightly rounded (default)"

                            RangeControl {
                                from: 0
                                to: 20
                                value: Config.opts.radius
                                suffix: " px"
                                onEdited: v => Config.opts.radius = v
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Font size"

                            RangeControl {
                                from: 11
                                to: 20
                                value: Config.opts.uiFontSize
                                suffix: " px"
                                onEdited: v => Config.opts.uiFontSize = v
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Font weight"
                            description: "400 = regular, 700 = bold (like Waybar)"

                            RangeControl {
                                from: 300
                                to: 900
                                stepSize: 100
                                value: Config.opts.uiFontWeight
                                onEdited: v => Config.opts.uiFontWeight = v
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Font"
                            description: "Must be installed (fc-list)"

                            InputField {
                                width: parent.width
                                text: Config.opts.uiFont
                                placeholder: "Inter"
                                onCommitted: value => Config.opts.uiFont = value.trim() !== "" ? value.trim() : Config.defaults.uiFont
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Icon font"
                            description: "A Nerd Font (Propo = proportional)"

                            InputField {
                                width: parent.width
                                text: Config.opts.uiIconFont
                                placeholder: "JetBrainsMono Nerd Font Propo"
                                onCommitted: value => Config.opts.uiIconFont = value.trim() !== "" ? value.trim() : Config.defaults.uiIconFont
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Black & white app icons"
                            description: "Launcher, tray, notifications, album art"

                            SwitchCtl {
                                checked: Config.opts.monochromeIcons
                                onToggled: Config.opts.monochromeIcons = !Config.opts.monochromeIcons
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "OLED background"
                            description: "True black wallpaper (turn off swaybg/hyprpaper)"

                            SwitchCtl {
                                checked: Config.opts.oledBackground
                                onToggled: Config.opts.oledBackground = !Config.opts.oledBackground
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Wallpaper image"
                            description: "Path to an image, empty = pure black"

                            InputField {
                                width: parent.width
                                text: Config.opts.wallpaper
                                placeholder: "~/Pictures/wall.png"
                                onCommitted: value => Config.opts.wallpaper = value.trim()
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Rounded screen corners"
                            description: "Black corners above windows (not above fullscreen)"

                            SwitchCtl {
                                checked: Config.opts.screenCorners
                                onToggled: Config.opts.screenCorners = !Config.opts.screenCorners
                            }
                        }
                    }

                    // ----- Bar -----
                    Column {
                        id: pageBar

                        width: parent.width
                        spacing: 10
                        visible: panel.tab === 1

                        SettingRow {
                            width: parent.width
                            label: "Bar height"

                            RangeControl {
                                from: 28
                                to: 48
                                value: Config.opts.barHeight
                                suffix: " px"
                                onEdited: v => Config.opts.barHeight = v
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Floating bar"
                            description: "Gap to the screen edge and rounded corners"

                            SwitchCtl {
                                checked: Config.opts.barFloating
                                onToggled: Config.opts.barFloating = !Config.opts.barFloating
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Bar border line"

                            SwitchCtl {
                                checked: Config.opts.barBorder
                                onToggled: Config.opts.barBorder = !Config.opts.barBorder
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Transparent when empty"
                            description: "No windows on the workspace = see-through, 1 or more = black"

                            SwitchCtl {
                                checked: Config.opts.barAutoTransparent
                                onToggled: Config.opts.barAutoTransparent = !Config.opts.barAutoTransparent
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Window title"

                            SwitchCtl {
                                checked: Config.opts.barShowTitle
                                onToggled: Config.opts.barShowTitle = !Config.opts.barShowTitle
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "CPU / RAM / temperature"
                            description: "Shown next to the clock"

                            SwitchCtl {
                                checked: Config.opts.barShowSysmon
                                onToggled: Config.opts.barShowSysmon = !Config.opts.barShowSysmon
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Date next to the clock"

                            SwitchCtl {
                                checked: Config.opts.barShowDate
                                onToggled: Config.opts.barShowDate = !Config.opts.barShowDate
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Show seconds"

                            SwitchCtl {
                                checked: Config.opts.clockSeconds
                                onToggled: Config.opts.clockSeconds = !Config.opts.clockSeconds
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "24-hour clock"

                            SwitchCtl {
                                checked: Config.opts.clock24h
                                onToggled: Config.opts.clock24h = !Config.opts.clock24h
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Workspaces"
                            description: "Always shown (occupied ones beyond that too)"

                            RangeControl {
                                from: 1
                                to: 10
                                value: Config.opts.workspaceCount
                                onEdited: v => Config.opts.workspaceCount = v
                            }
                        }
                    }

                    // ----- Behavior -----
                    Column {
                        id: pageBehavior

                        width: parent.width
                        spacing: 10
                        visible: panel.tab === 2

                        SettingRow {
                            width: parent.width
                            label: "Animations"

                            SwitchCtl {
                                checked: Config.opts.animations
                                onToggled: Config.opts.animations = !Config.opts.animations
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Animation duration"
                            description: "Lower = faster"

                            RangeControl {
                                from: 0.5
                                to: 2
                                stepSize: 0.1
                                decimals: 1
                                value: Config.opts.animScale
                                suffix: "×"
                                onEdited: v => Config.opts.animScale = v
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Do not disturb"
                            description: "Only critical notifications pop up"

                            SwitchCtl {
                                checked: Config.opts.dnd
                                onToggled: Config.opts.dnd = !Config.opts.dnd
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Popup duration"

                            RangeControl {
                                from: 2
                                to: 15
                                value: Config.opts.notifTimeout
                                suffix: " s"
                                onEdited: v => Config.opts.notifTimeout = v
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Volume OSD"

                            SwitchCtl {
                                checked: Config.opts.osdEnabled
                                onToggled: Config.opts.osdEnabled = !Config.opts.osdEnabled
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Volume step"
                            description: "Scroll wheel on the bar and IPC"

                            RangeControl {
                                from: 1
                                to: 10
                                value: Config.opts.volumeStep
                                suffix: " %"
                                onEdited: v => Config.opts.volumeStep = v
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "GPU monitor (nvidia-smi)"
                            description: "Only runs while the dashboard is open"

                            SwitchCtl {
                                checked: Config.opts.gpuMonitor
                                onToggled: Config.opts.gpuMonitor = !Config.opts.gpuMonitor
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "FPS counter"
                            description: "Frame rate and longest frame gap, top right"

                            SwitchCtl {
                                checked: Config.opts.fpsCounter
                                onToggled: Config.opts.fpsCounter = !Config.opts.fpsCounter
                            }
                        }
                    }

                    // ----- Commands -----
                    Column {
                        id: pageCommands

                        width: parent.width
                        spacing: 10
                        visible: panel.tab === 3

                        SettingRow {
                            width: parent.width
                            label: "Terminal"
                            description: "For terminal apps, nmtui and bluetoothctl"

                            InputField {
                                width: parent.width
                                text: Config.opts.terminal
                                placeholder: "kitty"
                                onCommitted: value => Config.opts.terminal = value.trim() !== "" ? value.trim() : Config.defaults.terminal
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Lock screen"
                            description: "Used by Lock in the power menu and control center"

                            InputField {
                                width: parent.width
                                text: Config.opts.lockCommand
                                placeholder: "hyprlock"
                                onCommitted: value => Config.opts.lockCommand = value.trim() !== "" ? value.trim() : Config.defaults.lockCommand
                            }
                        }
                    }
                }
            }

            // Schmale Scroll-Anzeige, nur wenn der Tab laenger als der Platz ist
            Rectangle {
                x: parent.width - 4
                y: flick.y + flick.visibleArea.yPosition * flick.height
                width: 3
                height: flick.visibleArea.heightRatio * flick.height
                radius: 1.5
                color: Theme.borderStrong
                visible: flick.contentHeight > flick.height + 1
            }
        }

        // Neuer Tab gleitet kurz von unten rein
        ParallelAnimation {
            id: tabIn

            NumberAnimation {
                target: pages
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.durMed
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: pages
                property: "shift"
                from: 10
                to: 0
                duration: Theme.durMed
                easing.type: Easing.OutCubic
            }
        }
    }
}
