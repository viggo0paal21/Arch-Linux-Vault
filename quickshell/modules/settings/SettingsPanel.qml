import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Einstellungen. Alles wird sofort angewendet und automatisch gespeichert.
OverlayPanel {
    id: panel

    open: Ui.panel === "settings"
    screen: Ui.panelScreen
    dim: true
    dimOpacity: 0.45
    ns: "qs-settings"
    onDismissed: Ui.close()

    component Section: Txt {
        topPadding: 10
        bottomPadding: 2
        text: ""
        color: Theme.fgMuted
        font.pixelSize: Theme.fontSm
        font.weight: Theme.weightStrong
        font.letterSpacing: 1.2
    }

    component SwitchCtl: Toggle {
        anchors.right: parent ? parent.right : undefined
    }

    Card {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 12 * (1 - panel.progress)
        width: Math.min(700, parent.width - 40)
        height: Math.min(parent.height * 0.82, header.height + col.implicitHeight + 3 * Theme.pad)
        opacity: panel.progress
        scale: 0.97 + 0.03 * panel.progress

        Item {
            id: header

            x: Theme.pad + 6
            y: Theme.pad
            width: parent.width - 2 * Theme.pad - 12
            height: 40

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.tune
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Settings"
                    font.pixelSize: Theme.fontLg
                    font.weight: Theme.weightStrong
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                IconButton {
                    icon: Icons.restart
                    label: "Defaults"
                    idleColor: Theme.layer2
                    onClicked: Config.reset()
                }

                IconButton {
                    icon: Icons.close
                    idleColor: Theme.layer2
                    onClicked: Ui.close()
                }
            }
        }

        Flickable {
            id: flick

            anchors.top: header.bottom
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.pad
            x: Theme.pad + 6
            width: parent.width - 2 * Theme.pad - 12
            contentWidth: width
            contentHeight: col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: col

                width: flick.width

                Section {
                    text: "APPEARANCE"
                }

                SettingRow {
                    width: col.width
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
                    width: col.width
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
                    width: col.width
                    label: "Floating bar"
                    description: "Gap to the screen edge and rounded corners"

                    SwitchCtl {
                        checked: Config.opts.barFloating
                        onToggled: Config.opts.barFloating = !Config.opts.barFloating
                    }
                }

                SettingRow {
                    width: col.width
                    label: "Bar border line"

                    SwitchCtl {
                        checked: Config.opts.barBorder
                        onToggled: Config.opts.barBorder = !Config.opts.barBorder
                    }
                }

                SettingRow {
                    width: col.width
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
                    width: col.width
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
                    width: col.width
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
                    width: col.width
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
                    width: col.width
                    label: "Black & white app icons"
                    description: "Launcher, tray, notifications, album art"

                    SwitchCtl {
                        checked: Config.opts.monochromeIcons
                        onToggled: Config.opts.monochromeIcons = !Config.opts.monochromeIcons
                    }
                }

                SettingRow {
                    width: col.width
                    label: "OLED background"
                    description: "True black wallpaper (turn off swaybg/hyprpaper)"

                    SwitchCtl {
                        checked: Config.opts.oledBackground
                        onToggled: Config.opts.oledBackground = !Config.opts.oledBackground
                    }
                }

                SettingRow {
                    width: col.width
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
                    width: col.width
                    label: "Rounded screen corners"
                    description: "Black corners above windows (not above fullscreen)"

                    SwitchCtl {
                        checked: Config.opts.screenCorners
                        onToggled: Config.opts.screenCorners = !Config.opts.screenCorners
                    }
                }

                Section {
                    text: "BAR"
                }

                SettingRow {
                    width: col.width
                    label: "Transparent when empty"
                    description: "No windows on the workspace = see-through, 1 or more = black"

                    SwitchCtl {
                        checked: Config.opts.barAutoTransparent
                        onToggled: Config.opts.barAutoTransparent = !Config.opts.barAutoTransparent
                    }
                }

                SettingRow {
                    width: col.width
                    label: "Window title"

                    SwitchCtl {
                        checked: Config.opts.barShowTitle
                        onToggled: Config.opts.barShowTitle = !Config.opts.barShowTitle
                    }
                }

                SettingRow {
                    width: col.width
                    label: "CPU / RAM / temperature"

                    SwitchCtl {
                        checked: Config.opts.barShowSysmon
                        onToggled: Config.opts.barShowSysmon = !Config.opts.barShowSysmon
                    }
                }

                SettingRow {
                    width: col.width
                    label: "Date next to the clock"

                    SwitchCtl {
                        checked: Config.opts.barShowDate
                        onToggled: Config.opts.barShowDate = !Config.opts.barShowDate
                    }
                }

                SettingRow {
                    width: col.width
                    label: "Show seconds"

                    SwitchCtl {
                        checked: Config.opts.clockSeconds
                        onToggled: Config.opts.clockSeconds = !Config.opts.clockSeconds
                    }
                }

                SettingRow {
                    width: col.width
                    label: "24-hour clock"

                    SwitchCtl {
                        checked: Config.opts.clock24h
                        onToggled: Config.opts.clock24h = !Config.opts.clock24h
                    }
                }

                SettingRow {
                    width: col.width
                    label: "Workspaces"
                    description: "Always shown (occupied ones beyond that too)"

                    RangeControl {
                        from: 1
                        to: 10
                        value: Config.opts.workspaceCount
                        onEdited: v => Config.opts.workspaceCount = v
                    }
                }

                Section {
                    text: "BEHAVIOR"
                }

                SettingRow {
                    width: col.width
                    label: "Animations"

                    SwitchCtl {
                        checked: Config.opts.animations
                        onToggled: Config.opts.animations = !Config.opts.animations
                    }
                }

                SettingRow {
                    width: col.width
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
                    width: col.width
                    label: "Do not disturb"
                    description: "Only critical notifications pop up"

                    SwitchCtl {
                        checked: Config.opts.dnd
                        onToggled: Config.opts.dnd = !Config.opts.dnd
                    }
                }

                SettingRow {
                    width: col.width
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
                    width: col.width
                    label: "Volume OSD"

                    SwitchCtl {
                        checked: Config.opts.osdEnabled
                        onToggled: Config.opts.osdEnabled = !Config.opts.osdEnabled
                    }
                }

                SettingRow {
                    width: col.width
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
                    width: col.width
                    label: "GPU monitor (nvidia-smi)"
                    description: "Only runs while the dashboard is open"

                    SwitchCtl {
                        checked: Config.opts.gpuMonitor
                        onToggled: Config.opts.gpuMonitor = !Config.opts.gpuMonitor
                    }
                }

                SettingRow {
                    width: col.width
                    label: "FPS counter"
                    description: "Frame rate and longest frame gap, top right"

                    SwitchCtl {
                        checked: Config.opts.fpsCounter
                        onToggled: Config.opts.fpsCounter = !Config.opts.fpsCounter
                    }
                }

                Section {
                    text: "COMMANDS"
                }

                SettingRow {
                    width: col.width
                    label: "Terminal"

                    InputField {
                        width: parent.width
                        text: Config.opts.terminal
                        placeholder: "kitty"
                        onCommitted: value => Config.opts.terminal = value.trim() !== "" ? value.trim() : Config.defaults.terminal
                    }
                }

                SettingRow {
                    width: col.width
                    label: "Lock screen"

                    InputField {
                        width: parent.width
                        text: Config.opts.lockCommand
                        placeholder: "hyprlock"
                        onCommitted: value => Config.opts.lockCommand = value.trim() !== "" ? value.trim() : Config.defaults.lockCommand
                    }
                }

                Txt {
                    width: col.width
                    topPadding: 14
                    text: "Saved to " + Quickshell.statePath("settings.json")
                    color: Theme.fgMuted
                    font.pixelSize: Theme.fontSm
                }
            }
        }
    }
}
