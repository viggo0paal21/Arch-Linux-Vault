import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Settings: tabs on the left in the launcher's style, options on the right with plenty of space.
// Everything applies immediately and is saved automatically.
// Keyboard: Tab / Shift+Tab or arrow up/down switch tabs, Esc closes.
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
            hint: "Notifications, OSD, volume",
            icon: Icons.cogOutline
        },
        {
            name: "Commands",
            hint: "Terminal and lock screen",
            icon: Icons.consoleLine
        },
        {
            name: "Animations",
            hint: "Curves and speed for everything",
            icon: Icons.play
        }
    ]

    // All animation values back to the defaults
    function resetAnimations() {
        const d = Config.defaults;
        const keys = ["animations", "animScale", "barDockDuration", "animBarCurve", "animPanelSpeed", "animPanelOpen", "animPanelClose", "animOverlaySpeed", "animOverlayOpen", "animOverlayClose", "animNotifSpeed", "animNotifCurve", "animOsdSpeed", "animWsSpeed", "animWsCurve", "animCtlSpeed", "animCtlCurve"];
        for (const k of keys)
            Config.opts[k] = d[k];
    }

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

    // Curve picker: left half = previous, right half = next
    component CurvePick: Rectangle {
        id: cp

        property string value: ""
        readonly property int idx: Math.max(0, Theme.curveKeys.indexOf(cp.value))

        signal picked(string v)

        width: 150
        height: 30
        radius: Theme.radiusSm
        color: cpArea.pressed ? Theme.pressed : (cpArea.containsMouse ? Theme.hover : Theme.layer3)
        border.width: 1
        border.color: Theme.border

        Glyph {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.left
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSm
        }

        Txt {
            anchors.centerIn: parent
            text: Theme.curveNames[cp.idx]
            font.pixelSize: Theme.fontSm
        }

        Glyph {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.right
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSm
        }

        MouseArea {
            id: cpArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                const n = Theme.curveKeys.length;
                const d = mouse.x < width / 2 ? -1 : 1;
                cp.picked(Theme.curveKeys[(cp.idx + d + n) % n]);
            }
        }
    }

    // One animation group: duration factor and up to two curves
    component AnimRow: SettingRow {
        id: ar

        property real speed: 1
        property string curveA: ""
        property string curveB: ""
        property string labelA: "Curve"
        property string labelB: ""

        signal speedEdited(real v)
        signal curveAPicked(string v)
        signal curveBPicked(string v)

        width: parent ? parent.width : 0
        controlWidth: 420
        implicitHeight: Math.max(64, arCol.height + 28)

        Column {
            id: arCol

            width: parent.width
            spacing: 8

            RangeControl {
                width: parent.width
                from: 0.25
                to: 3
                stepSize: 0.05
                decimals: 2
                value: ar.speed
                suffix: "×"
                onEdited: v => ar.speedEdited(v)
            }

            Row {
                visible: ar.curveA !== ""
                spacing: 8

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ar.labelA
                    color: Theme.fgMuted
                    font.pixelSize: Theme.fontSm
                }

                CurvePick {
                    value: ar.curveA
                    onPicked: v => ar.curveAPicked(v)
                }

                Txt {
                    visible: ar.curveB !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: ar.labelB
                    color: Theme.fgMuted
                    font.pixelSize: Theme.fontSm
                }

                CurvePick {
                    visible: ar.curveB !== ""
                    value: ar.curveB
                    onPicked: v => ar.curveBPicked(v)
                }
            }
        }
    }

    Card {
        id: card

        readonly property int tabHeight: 56

        // Only fade in + a short slide, always on whole pixels: text stays sharp in every frame
        x: Math.round((parent.width - width) / 2)
        y: Theme.px((parent.height - height) / 2 + 12 * (1 - panel.progress))
        width: Math.min(940, parent.width - 80)
        height: Math.min(700, parent.height - 140)
        opacity: panel.progress
        focus: true

        Keys.onTabPressed: panel.switchTab(1)
        Keys.onBacktabPressed: panel.switchTab(-1)
        Keys.onDownPressed: panel.switchTab(1)
        Keys.onUpPressed: panel.switchTab(-1)

        // ---------- Left: tabs ----------
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
                highlightMoveDuration: Theme.ctlFast
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
                                duration: Theme.ctlFast
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

            // Bottom: reset + storage location
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

        // ---------- Right: options of the tab ----------
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
                        y: Theme.px(pages.shift)
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
                            visible: Config.opts.transparency === "everywhere"
                            label: "Exclude kitty terminal"
                            description: "Kitty windows don't count for the bar, so it stays translucent while only kitty is open"

                            SwitchCtl {
                                checked: Config.opts.barExcludeKitty
                                onToggled: Config.opts.barExcludeKitty = !Config.opts.barExcludeKitty
                            }
                        }

                        SettingRow {
                            width: parent.width
                            visible: Config.opts.transparency !== "off"
                            label: "Opacity"
                            description: "How solid translucent surfaces are, 100 % = black"

                            RangeControl {
                                from: 25
                                to: 100
                                stepSize: 5
                                value: Config.opts.glassOpacity
                                suffix: " %"
                                onEdited: v => Config.opts.glassOpacity = v
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
                            description: Config.opts.barSolidOnlySingle ? "The bar is black with exactly 1 window, translucent with none or 2 and more (floating ones don't count)" : "The bar turns black as soon as 1 or more windows are open (floating ones don't count)"

                            Row {
                                anchors.right: parent.right
                                spacing: 10

                                // "Only 1": black only with exactly 1 window
                                Txt {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Only 1"
                                    color: Theme.fgMuted
                                    font.pixelSize: Theme.fontSm
                                    opacity: Config.opts.barSolidWithWindows ? 1 : 0.4
                                }

                                Toggle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30
                                    height: 18
                                    enabled: Config.opts.barSolidWithWindows
                                    opacity: Config.opts.barSolidWithWindows ? 1 : 0.4
                                    checked: Config.opts.barSolidOnlySingle
                                    onToggled: Config.opts.barSolidOnlySingle = !Config.opts.barSolidOnlySingle
                                }

                                Item {
                                    width: 8
                                    height: 1
                                }

                                Toggle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: Config.opts.barSolidWithWindows
                                    onToggled: Config.opts.barSolidWithWindows = !Config.opts.barSolidWithWindows
                                }
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Smooth text"
                            description: "Text and icons glide without pixel steps while moving (glyphs look a bit softer)"

                            SwitchCtl {
                                checked: Config.opts.smoothText
                                onToggled: Config.opts.smoothText = !Config.opts.smoothText
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

                        // Thickness docked (top, moves both) and floating (bottom, floating only). Reset = defaults
                        SettingRow {
                            id: heightRow

                            readonly property bool dynamic: Config.opts.barFloating && Config.opts.barFloatingDynamic
                            readonly property int labelWidth: 64
                            readonly property real sliderWidth: heightCol.width - heightRow.labelWidth - resetBtn.width - 20

                            width: parent.width
                            implicitHeight: Math.max(64, heightCol.height + 28)
                            label: "Bar height"
                            description: heightRow.dynamic ? "Docked moves both, Floating only the floating bar" : ""
                            controlWidth: 400

                            Column {
                                id: heightCol

                                width: parent.width
                                spacing: 10

                                Row {
                                    visible: heightRow.dynamic
                                    spacing: 10

                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: heightRow.labelWidth
                                        text: "Docked"
                                        color: Theme.fgMuted
                                        font.pixelSize: Theme.fontSm
                                    }

                                    RangeControl {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: heightRow.sliderWidth
                                        from: 28
                                        to: 48
                                        value: Config.opts.barDockedHeight
                                        suffix: " px"
                                        onEdited: v => {
                                            const d = v - Config.opts.barDockedHeight;
                                            Config.opts.barDockedHeight = v;
                                            Config.opts.barHeight = Math.max(28, Math.min(48, Config.opts.barHeight + d));
                                        }
                                    }

                                    Item {
                                        width: resetBtn.width
                                        height: 1
                                    }
                                }

                                Row {
                                    spacing: 10

                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: heightRow.labelWidth
                                        text: Config.opts.barFloating ? "Floating" : "Height"
                                        color: Theme.fgMuted
                                        font.pixelSize: Theme.fontSm
                                    }

                                    RangeControl {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: heightRow.sliderWidth
                                        from: 28
                                        to: 48
                                        value: Config.opts.barHeight
                                        suffix: " px"
                                        onEdited: v => Config.opts.barHeight = v
                                    }

                                    IconButton {
                                        id: resetBtn

                                        anchors.verticalCenter: parent.verticalCenter
                                        size: 30
                                        icon: String.fromCodePoint(0xF0450)
                                        iconSize: Theme.fontSm
                                        label: "Reset"
                                        idleColor: Theme.layer3
                                        onClicked: {
                                            Config.opts.barHeight = Config.defaults.barHeight;
                                            Config.opts.barDockedHeight = Config.defaults.barDockedHeight;
                                        }
                                    }
                                }
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
                            visible: Config.opts.barFloating
                            label: "Dynamic"
                            description: "Docks with exactly 1 tiled window, floats with none or 2 and more (floating windows never count)"

                            SwitchCtl {
                                checked: Config.opts.barFloatingDynamic
                                onToggled: Config.opts.barFloatingDynamic = !Config.opts.barFloatingDynamic
                            }
                        }

                        // On: stepless dock animation (between pixels, like Hyprland windows), content a touch softer
                        // while moving. Off: whole pixels, always crisp (previous behavior).
                        SettingRow {
                            width: parent.width
                            visible: Config.opts.barFloating
                            label: "Subpixel glide"
                            description: "Smoother dock animation that moves between pixels like Hyprland windows. Icons are a touch softer only while moving. Off = whole pixels, always crisp"

                            SwitchCtl {
                                checked: Config.opts.barGlide
                                onToggled: Config.opts.barGlide = !Config.opts.barGlide
                            }
                        }

                        // Height of the floating bar above the top edge, reset to the default
                        SettingRow {
                            width: parent.width
                            visible: Config.opts.barFloating
                            label: "Floating position"
                            description: "Distance of the floating bar from the top edge. Higher values also shrink the gap to the windows"
                            controlWidth: 400

                            Row {
                                spacing: 10

                                RangeControl {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - posResetBtn.width - 10
                                    from: 0
                                    to: 20
                                    value: Config.opts.barFloatOffset
                                    suffix: " px"
                                    onEdited: v => Config.opts.barFloatOffset = v
                                }

                                IconButton {
                                    id: posResetBtn

                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: String.fromCodePoint(0xF0450)
                                    iconSize: Theme.fontSm
                                    label: "Reset"
                                    idleColor: Theme.layer3
                                    onClicked: Config.opts.barFloatOffset = Config.defaults.barFloatOffset
                                }
                            }
                        }

                        // Side gap of the floating bar to the screen edge (where it ends left/right)
                        SettingRow {
                            width: parent.width
                            visible: Config.opts.barFloating
                            label: "Floating side gap"
                            description: "Where the floating bar ends on the left and right. Match it to your Hyprland gaps_out to line it up with the windows"
                            controlWidth: 400

                            Row {
                                spacing: 10

                                RangeControl {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - sideResetBtn.width - 10
                                    from: 0
                                    to: 40
                                    value: Config.opts.barFloatSide
                                    suffix: " px"
                                    onEdited: v => Config.opts.barFloatSide = v
                                }

                                IconButton {
                                    id: sideResetBtn

                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: String.fromCodePoint(0xF0450)
                                    iconSize: Theme.fontSm
                                    label: "Reset"
                                    idleColor: Theme.layer3
                                    onClicked: Config.opts.barFloatSide = Config.defaults.barFloatSide
                                }
                            }
                        }

                        // Launcher icon on the left of the bar: Arch or Tux, as big tiles showing the real icon
                        SettingRow {
                            width: parent.width
                            implicitHeight: 112
                            label: "Launcher icon"
                            description: "The icon in the top left corner of the bar"
                            controlWidth: 2 * 96 + 12

                            Row {
                                anchors.right: parent.right
                                spacing: 12

                                Repeater {
                                    model: [
                                        { key: "arch", glyph: Icons.arch, name: "Arch" },
                                        { key: "tux", glyph: Icons.tux, name: "Tux" }
                                    ]

                                    delegate: Rectangle {
                                        id: iconTile

                                        required property var modelData
                                        readonly property bool selected: Config.opts.launcherIcon === modelData.key

                                        width: 96
                                        height: 84
                                        radius: Theme.radius
                                        color: iconTile.selected ? Theme.accent : (iconTileArea.pressed ? Theme.pressed : (iconTileArea.containsMouse ? Theme.hover : Theme.layer3))
                                        border.width: 1
                                        border.color: iconTile.selected ? Theme.accent : (iconTileArea.containsMouse ? Theme.fgDim : Theme.borderStrong)
                                        scale: iconTileArea.pressed ? 0.96 : (iconTileArea.containsMouse && !iconTile.selected ? 1.04 : 1)

                                        Behavior on color {
                                            CAnim {}
                                        }
                                        Behavior on border.color {
                                            CAnim {}
                                        }
                                        Behavior on scale {
                                            Anim {
                                                duration: Theme.ctlFast
                                            }
                                        }

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Glyph {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: iconTile.modelData.glyph
                                                font.pixelSize: 34
                                                color: iconTile.selected ? Theme.accentFg : Theme.fg
                                            }

                                            Txt {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: iconTile.modelData.name
                                                font.pixelSize: Theme.fontSm
                                                color: iconTile.selected ? Theme.accentFg : Theme.fgDim
                                            }
                                        }

                                        // Check mark top right on the active tile
                                        Rectangle {
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            anchors.margins: 6
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: Theme.accentFg
                                            opacity: iconTile.selected ? 1 : 0
                                            scale: iconTile.selected ? 1 : 0.4

                                            Behavior on opacity {
                                                Anim {
                                                    duration: Theme.ctlFast
                                                }
                                            }
                                            Behavior on scale {
                                                Anim {
                                                    duration: Theme.ctlMed
                                                }
                                            }

                                            Txt {
                                                anchors.centerIn: parent
                                                text: "\u2713"
                                                font.pixelSize: 11
                                                color: Theme.accent
                                            }
                                        }

                                        MouseArea {
                                            id: iconTileArea

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Config.opts.launcherIcon = iconTile.modelData.key
                                        }
                                    }
                                }
                            }
                        }

                        // Size of the launcher icon on the left of the bar
                        SettingRow {
                            width: parent.width
                            label: "Launcher icon size"
                            description: "Size of the Arch / Tux icon in the bar"
                            controlWidth: 400

                            Row {
                                spacing: 10

                                RangeControl {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - logoSizeResetBtn.width - 10
                                    from: 10
                                    to: 26
                                    value: Config.opts.launcherIconSize
                                    suffix: " px"
                                    onEdited: v => Config.opts.launcherIconSize = v
                                }

                                IconButton {
                                    id: logoSizeResetBtn

                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: String.fromCodePoint(0xF0450)
                                    iconSize: Theme.fontSm
                                    label: "Reset"
                                    idleColor: Theme.layer3
                                    onClicked: Config.opts.launcherIconSize = Config.defaults.launcherIconSize
                                }
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Group boxes"
                            description: "Puts every group in the bar (launcher, workspaces, tray, system info, status, power) in its own box"

                            SwitchCtl {
                                checked: Config.opts.barBoxes
                                onToggled: Config.opts.barBoxes = !Config.opts.barBoxes
                            }
                        }

                        // Box color: clicking the color opens the color picker
                        Column {
                            id: boxColorBlock

                            property bool open: false

                            width: parent.width
                            visible: Config.opts.barBoxes
                            spacing: 10

                            SettingRow {
                                width: parent.width
                                label: "Box color"
                                description: "Click the color to open the picker"
                                controlWidth: 220

                                Row {
                                    anchors.right: parent.right
                                    spacing: 10

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 110
                                        height: 30
                                        radius: Theme.radiusSm
                                        color: Config.opts.barBoxColor
                                        border.width: 1
                                        border.color: boxColorArea.containsMouse || boxColorBlock.open ? Theme.fgDim : Theme.borderStrong

                                        Txt {
                                            anchors.centerIn: parent
                                            text: Config.opts.barBoxColor
                                            font.pixelSize: Theme.fontSm
                                            color: (parent.color.r * 0.3 + parent.color.g * 0.59 + parent.color.b * 0.11) * parent.color.a > 0.5 ? "#000000" : "#ffffff"
                                        }

                                        MouseArea {
                                            id: boxColorArea

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: boxColorBlock.open = !boxColorBlock.open
                                        }
                                    }

                                    IconButton {
                                        anchors.verticalCenter: parent.verticalCenter
                                        size: 30
                                        icon: String.fromCodePoint(0xF0450)
                                        iconSize: Theme.fontSm
                                        label: "Reset"
                                        idleColor: Theme.layer3
                                        onClicked: Config.opts.barBoxColor = Config.defaults.barBoxColor
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: boxPicker.implicitHeight + 36
                                visible: boxColorBlock.open
                                radius: Theme.radius
                                color: Theme.layer2
                                border.width: 1
                                border.color: Theme.border

                                ColorPicker {
                                    id: boxPicker

                                    anchors.top: parent.top
                                    anchors.topMargin: 18
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.min(440, parent.width - 36)
                                    color: Config.opts.barBoxColor
                                    onPicked: v => Config.opts.barBoxColor = v
                                }
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

                    // ----- Animations -----
                    Column {
                        id: pageAnimations

                        width: parent.width
                        spacing: 10
                        visible: panel.tab === 4

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
                            label: "Global duration"
                            description: "Applies to everything below except bar docking. Lower = faster"
                            controlWidth: 420

                            RangeControl {
                                from: 0.25
                                to: 2
                                stepSize: 0.05
                                decimals: 2
                                value: Config.opts.animScale
                                suffix: "×"
                                onEdited: v => Config.opts.animScale = v
                            }
                        }

                        SettingRow {
                            id: dockRow

                            width: parent.width
                            label: "Bar docking"
                            description: "Dynamic floating bar. Same curve as the windows in hyprland.lua keeps them in step"
                            controlWidth: 420
                            implicitHeight: Math.max(64, dockCol.height + 28)

                            Column {
                                id: dockCol

                                width: parent.width
                                spacing: 8

                                RangeControl {
                                    width: parent.width
                                    from: 150
                                    to: 700
                                    stepSize: 10
                                    value: Config.opts.barDockDuration
                                    suffix: " ms"
                                    onEdited: v => Config.opts.barDockDuration = v
                                }

                                Row {
                                    spacing: 8

                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Curve"
                                        color: Theme.fgMuted
                                        font.pixelSize: Theme.fontSm
                                    }

                                    CurvePick {
                                        value: Config.opts.animBarCurve
                                        onPicked: v => Config.opts.animBarCurve = v
                                    }
                                }
                            }
                        }

                        AnimRow {
                            label: "Dashboard & control center"
                            speed: Config.opts.animPanelSpeed
                            labelA: "Open"
                            curveA: Config.opts.animPanelOpen
                            labelB: "Close"
                            curveB: Config.opts.animPanelClose
                            onSpeedEdited: v => Config.opts.animPanelSpeed = v
                            onCurveAPicked: v => Config.opts.animPanelOpen = v
                            onCurveBPicked: v => Config.opts.animPanelClose = v
                        }

                        AnimRow {
                            label: "Launcher, settings & power menu"
                            speed: Config.opts.animOverlaySpeed
                            labelA: "Open"
                            curveA: Config.opts.animOverlayOpen
                            labelB: "Close"
                            curveB: Config.opts.animOverlayClose
                            onSpeedEdited: v => Config.opts.animOverlaySpeed = v
                            onCurveAPicked: v => Config.opts.animOverlayOpen = v
                            onCurveBPicked: v => Config.opts.animOverlayClose = v
                        }

                        AnimRow {
                            label: "Notifications"
                            speed: Config.opts.animNotifSpeed
                            labelA: "Slide in"
                            curveA: Config.opts.animNotifCurve
                            onSpeedEdited: v => Config.opts.animNotifSpeed = v
                            onCurveAPicked: v => Config.opts.animNotifCurve = v
                        }

                        AnimRow {
                            label: "Workspaces"
                            speed: Config.opts.animWsSpeed
                            curveA: Config.opts.animWsCurve
                            onSpeedEdited: v => Config.opts.animWsSpeed = v
                            onCurveAPicked: v => Config.opts.animWsCurve = v
                        }

                        AnimRow {
                            label: "Volume & brightness popup"
                            speed: Config.opts.animOsdSpeed
                            onSpeedEdited: v => Config.opts.animOsdSpeed = v
                        }

                        AnimRow {
                            label: "Buttons, switches & hover"
                            speed: Config.opts.animCtlSpeed
                            curveA: Config.opts.animCtlCurve
                            onSpeedEdited: v => Config.opts.animCtlSpeed = v
                            onCurveAPicked: v => Config.opts.animCtlCurve = v
                        }

                        SettingRow {
                            width: parent.width
                            label: "Reset all animations"
                            description: "Back to the defaults (the setup this tab was built with)"

                            IconButton {
                                anchors.right: parent.right
                                size: 30
                                icon: String.fromCodePoint(0xF0450)
                                iconSize: Theme.fontSm
                                label: "Reset"
                                idleColor: Theme.layer3
                                onClicked: panel.resetAnimations()
                            }
                        }
                    }
                }
            }

            // Thin scroll indicator, only when the tab is taller than the space
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

        // A new tab briefly slides in from below
        ParallelAnimation {
            id: tabIn

            NumberAnimation {
                target: pages
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.ctlMed
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: pages
                property: "shift"
                from: 10
                to: 0
                duration: Theme.ctlMed
                easing.type: Easing.OutCubic
            }
        }
    }
}
