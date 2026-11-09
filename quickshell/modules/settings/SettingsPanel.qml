import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
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
            name: "Wallpaper",
            hint: "Pick your wallpaper, with previews",
            icon: Icons.image
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
    // Glass blur: read the values from Hyprland (Settings > Bar > Glass blur values > From Hyprland)
    readonly property var glassBlurKeys: ["glassBlurSize", "glassBlurPasses", "glassBlurContrast", "glassBlurBrightness", "glassBlurVibrancy", "glassBlurVibrancyDarkness", "glassBlurNoise"]

    function applyHyprBlurLine(line) {
        const i = line.indexOf(" ");
        if (i < 0)
            return;
        const name = line.slice(0, i);
        let j;
        try {
            j = JSON.parse(line.slice(i + 1));
        } catch (e) {
            return;
        }
        const v = j.int !== undefined ? j.int : (j.float !== undefined ? j.float : j.value);
        if (typeof v !== "number")
            return;
        const keys = {
            size: ["glassBlurSize", 0, 100],
            passes: ["glassBlurPasses", 1, 8],
            contrast: ["glassBlurContrast", 0, 2],
            brightness: ["glassBlurBrightness", 0, 2],
            vibrancy: ["glassBlurVibrancy", 0, 1],
            vibrancy_darkness: ["glassBlurVibrancyDarkness", 0, 1],
            noise: ["glassBlurNoise", 0, 1]
        };
        const k = keys[name];
        if (k)
            Config.opts[k[0]] = Math.max(k[1], Math.min(k[2], v));
    }

    Process {
        id: hyprBlurReader

        command: ["sh", "-c", "for o in size passes contrast brightness vibrancy vibrancy_darkness noise; do printf '%s ' \"$o\"; hyprctl -j getoption decoration:blur:$o | tr -d '\\n'; echo; done"]
        stdout: SplitParser {
            onRead: line => panel.applyHyprBlurLine(line)
        }
    }

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

        // Fade in + short glide, subpixel like the bar: drawn as a texture while moving (text stays sharp),
        // at rest on whole pixels without a texture
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2) + 12 * (1 - panel.progress)
        width: Math.min(940, parent.width - 80)
        height: Math.min(700, parent.height - 140)
        opacity: panel.progress
        layer.enabled: panel.progress > 0 && panel.progress < 1
        layer.smooth: true
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
                    height: [pageAppearance, pageWallpaper, pageBar, pageBehavior, pageCommands, pageAnimations][panel.tab].implicitHeight

                    // Tab switch: glides subpixel, as a texture meanwhile (text sharp)
                    layer.enabled: tabIn.running
                    layer.smooth: true

                    transform: Translate {
                        y: pages.shift
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
                            label: "Wallpaper colors"
                            description: "Buttons, switches, sliders and highlights take the colors of your wallpaper, like Caelestia. Black & white wallpapers stay black & white"

                            SwitchCtl {
                                checked: Config.opts.wallColors
                                onToggled: Config.opts.wallColors = !Config.opts.wallColors
                            }
                        }

                        SettingRow {
                            width: parent.width
                            visible: Config.opts.wallColors
                            label: "Black & white with 1 window"
                            description: "Same rule as the dynamic bar: exactly 1 tiled window = normal black & white. No windows, 2 or more, or only floating ones = wallpaper colors"

                            SwitchCtl {
                                checked: Config.opts.wallColorsDynamic
                                onToggled: Config.opts.wallColorsDynamic = !Config.opts.wallColorsDynamic
                            }
                        }

                        SettingRow {
                            width: parent.width
                            visible: Config.opts.wallColors
                            label: "Color style"
                            description: "Tonal: calm, like Material You. Vibrant: strong. Exact: as colorful as the wallpaper itself"
                            controlWidth: 330

                            Segmented {
                                width: parent.width
                                options: [
                                    {
                                        value: "tonal",
                                        label: "Tonal"
                                    },
                                    {
                                        value: "vibrant",
                                        label: "Vibrant"
                                    },
                                    {
                                        value: "exact",
                                        label: "Exact"
                                    }
                                ]
                                value: Config.opts.wallColorStyle
                                onPicked: v => Config.opts.wallColorStyle = v
                            }
                        }

                        // Preview: the accent (with text on it) and the 16 colors of the image
                        SettingRow {
                            width: parent.width
                            visible: Config.opts.wallColors
                            label: "Palette"
                            description: WallColors.file !== "" ? WallColors.file.replace(/^.*\//, "") : "No wallpaper found (waypaper / awww)"
                            controlWidth: 360

                            Row {
                                anchors.right: parent.right
                                spacing: 6

                                // Accent with the text color on it
                                Rectangle {
                                    width: 44
                                    height: 22
                                    radius: Theme.radiusSm
                                    color: Theme.accent

                                    Glyph {
                                        anchors.centerIn: parent
                                        text: Icons.check
                                        color: Theme.accentFg
                                        font.pixelSize: 14
                                    }
                                }

                                Item {
                                    width: 4
                                    height: 1
                                }

                                Row {
                                    spacing: 2

                                    Repeater {
                                        model: WallColors.sourceColors

                                        Rectangle {
                                            required property color modelData

                                            width: 8
                                            height: 22
                                            radius: 2
                                            color: modelData
                                        }
                                    }
                                }
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

                    // ----- Wallpaper -----
                    // The current image large at the top, below it search, sorting, random and all images from the
                    // waypaper folder as tiles. A click sets the image (waypaper/awww, see services/Walls.qml).
                    // Tiles and thumbnails only exist while the tab is open.
                    Column {
                        id: pageWallpaper

                        readonly property bool live: panel.tab === 1 && panel.progress > 0

                        width: parent.width
                        spacing: 12
                        visible: panel.tab === 1

                        onLiveChanged: Walls.wanted = live

                        // Large preview of the current image, changes with a fade
                        ClippingRectangle {
                            id: hero

                            readonly property string file: Walls.current
                            readonly property string thumb: {
                                if (hero.file === "")
                                    return "";
                                const i = Walls.model.indexOf("file://" + hero.file);
                                return Walls.thumbFor(hero.file, i >= 0 ? Walls.model.get(i, "fileModified") : 0, 1280);
                            }
                            property int front: 0

                            // Real crossfade: the new image is on top and fades in over the old one, the old one stays
                            // fully visible below it (two opposite fades would let the background
                            // show through). Duration and curve like the awww fade, ends together with it.
                            property Item incoming: null

                            function show() {
                                const inc = hero.front === 0 ? heroB : heroA;
                                const old = inc === heroA ? heroB : heroA;
                                heroFade.stop();
                                inc.opacity = 0;
                                inc.z = 1;
                                old.z = 0;
                                hero.incoming = inc;
                                inc.source = "";
                                inc.source = "file://" + hero.thumb;
                            }

                            function fadeIn(img) {
                                heroFade.target = img;
                                heroFade.duration = Config.opts.animations ? Math.max(400, WallColors.wallFadeMs - (Date.now() - WallColors.changedAt)) : 0;
                                heroFade.start();
                                hero.front = img === heroA ? 0 : 1;
                            }

                            function request() {
                                if (hero.thumb === "" || !pageWallpaper.live)
                                    return;
                                if (Walls.isReady(hero.thumb))
                                    hero.show();
                                else
                                    Walls.ensure([[hero.file, hero.thumb]], 1280, 720);
                            }

                            width: parent.width
                            height: Math.round(width * 0.42)
                            radius: Theme.radiusLg
                            color: Theme.layer2
                            onThumbChanged: hero.request()

                            Connections {
                                target: pageWallpaper

                                function onLiveChanged() {
                                    hero.request();
                                }
                            }

                            Connections {
                                target: Walls

                                function onThumbReady(t) {
                                    if (t === hero.thumb)
                                        hero.show();
                                }
                            }

                            NumberAnimation {
                                id: heroFade

                                property: "opacity"
                                from: 0
                                to: 1
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: WallColors.wallFadeCurve
                            }

                            Image {
                                id: heroA

                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                onStatusChanged: {
                                    if (status === Image.Ready && hero.incoming === heroA)
                                        hero.fadeIn(heroA);
                                }
                            }

                            Image {
                                id: heroB

                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                opacity: 0
                                onStatusChanged: {
                                    if (status === Image.Ready && hero.incoming === heroB)
                                        hero.fadeIn(heroB);
                                }
                            }

                            // Dark gradient at the bottom with the name and (with Wallpaper colors) the accent color
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 96
                                z: 2
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0
                                        color: "transparent"
                                    }
                                    GradientStop {
                                        position: 1
                                        color: Qt.rgba(0, 0, 0, 0.8)
                                    }
                                }
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.right: heroPalette.left
                                anchors.rightMargin: 16
                                z: 2
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 14
                                spacing: 2

                                Txt {
                                    text: "CURRENT WALLPAPER"
                                    color: Theme.fgDim
                                    font.pixelSize: Theme.fontSm - 1
                                    font.letterSpacing: 1.2
                                }

                                Txt {
                                    width: parent.width
                                    text: hero.file !== "" ? Walls.fileName(hero.file) : "No wallpaper set"
                                    font.pixelSize: Theme.fontLg
                                    font.weight: Theme.weightStrong
                                    elide: Text.ElideMiddle
                                }
                            }

                            Row {
                                id: heroPalette

                                z: 2

                                anchors.right: parent.right
                                anchors.rightMargin: 18
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 18
                                spacing: 6
                                visible: Config.opts.wallColors

                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: Theme.accent
                                    border.width: 1
                                    border.color: Qt.rgba(0, 0, 0, 0.4)
                                }
                            }
                        }

                        // Search, sorting, random
                        Item {
                            width: parent.width
                            height: 38

                            InputField {
                                id: wallSearch

                                anchors.left: parent.left
                                anchors.right: wallSort.left
                                anchors.rightMargin: 10
                                height: parent.height
                                placeholder: "Search " + Walls.model.count + " wallpapers"
                            }

                            Segmented {
                                id: wallSort

                                anchors.right: wallShuffle.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 190
                                options: [
                                    {
                                        value: "time",
                                        label: "Newest"
                                    },
                                    {
                                        value: "name",
                                        label: "Name"
                                    }
                                ]
                                value: Walls.sortBy
                                onPicked: v => Walls.sortBy = v
                            }

                            IconButton {
                                id: wallShuffle

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                size: 38
                                icon: Icons.shuffle
                                idleColor: Theme.layer2
                                onClicked: Walls.random()
                            }
                        }

                        Grid {
                            id: wallGrid

                            readonly property real cellW: Math.floor((width - spacing * (columns - 1)) / columns)
                            readonly property string query: wallSearch.input.text.trim().toLowerCase()

                            width: parent.width
                            columns: 3
                            spacing: 10

                            Repeater {
                                model: pageWallpaper.live ? Walls.model : null

                                delegate: Item {
                                    id: tile

                                    required property string filePath
                                    required property string fileName
                                    required property var fileModified
                                    readonly property string thumb: Walls.thumbFor(filePath, fileModified, Walls.tileW)
                                    readonly property bool current: filePath === Walls.current
                                    readonly property bool busy: filePath === Walls.pending

                                    function load() {
                                        img.source = "";
                                        img.source = "file://" + tile.thumb;
                                    }

                                    visible: wallGrid.query === "" || fileName.toLowerCase().indexOf(wallGrid.query) >= 0
                                    width: wallGrid.cellW
                                    height: Math.round(width * 9 / 16)
                                    Component.onCompleted: {
                                        if (Walls.isReady(tile.thumb))
                                            tile.load();
                                    }

                                    Connections {
                                        target: Walls

                                        function onThumbReady(t) {
                                            if (t === tile.thumb)
                                                tile.load();
                                        }
                                    }

                                    ClippingRectangle {
                                        anchors.fill: parent
                                        radius: Theme.radius
                                        color: Theme.layer3

                                        Image {
                                            id: img

                                            width: parent.width
                                            height: parent.height
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: false
                                            scale: tileArea.containsMouse ? 1.06 : 1
                                            opacity: status === Image.Ready ? 1 : 0

                                            Behavior on opacity {
                                                Anim {
                                                    duration: Theme.durMed
                                                }
                                            }

                                            Behavior on scale {
                                                Anim {
                                                    duration: Theme.durMed
                                                    easing.bezierCurve: Theme.curveSmooth
                                                }
                                            }
                                        }

                                        // Name on hover
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 46
                                            opacity: tileArea.containsMouse ? 1 : 0
                                            gradient: Gradient {
                                                GradientStop {
                                                    position: 0
                                                    color: "transparent"
                                                }
                                                GradientStop {
                                                    position: 1
                                                    color: Qt.rgba(0, 0, 0, 0.8)
                                                }
                                            }

                                            Behavior on opacity {
                                                Anim {
                                                    duration: Theme.ctlFast
                                                }
                                            }

                                            Txt {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 10
                                                anchors.right: parent.right
                                                anchors.rightMargin: 10
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 7
                                                text: tile.fileName.replace(/\.[^.]+$/, "")
                                                font.pixelSize: Theme.fontSm
                                                elide: Text.ElideRight
                                            }
                                        }

                                        // Being set right now
                                        Rectangle {
                                            anchors.fill: parent
                                            color: Qt.rgba(0, 0, 0, 0.45)
                                            opacity: tile.busy ? 1 : 0

                                            Behavior on opacity {
                                                Anim {
                                                    duration: Theme.ctlFast
                                                }
                                            }

                                            Glyph {
                                                anchors.centerIn: parent
                                                text: Icons.refresh
                                                color: Theme.fg

                                                RotationAnimation on rotation {
                                                    running: tile.busy
                                                    loops: Animation.Infinite
                                                    from: 0
                                                    to: 360
                                                    duration: 900
                                                }
                                            }
                                        }
                                    }

                                    // Border: current image in the accent color, brighter on hover
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.radius
                                        color: "transparent"
                                        border.width: tile.current ? 2 : 1
                                        border.color: tile.current ? Theme.accent : (tileArea.containsMouse ? Theme.fgMuted : Theme.border)

                                        Behavior on border.color {
                                            CAnim {}
                                        }
                                    }

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: Theme.accent
                                        scale: tile.current ? 1 : 0.5
                                        opacity: tile.current ? 1 : 0

                                        Behavior on opacity {
                                            Anim {
                                                duration: Theme.ctlFast
                                            }
                                        }

                                        Behavior on scale {
                                            Anim {
                                                duration: Theme.ctlMed
                                                easing.bezierCurve: Theme.curveSmooth
                                            }
                                        }

                                        Glyph {
                                            anchors.centerIn: parent
                                            text: Icons.check
                                            color: Theme.accentFg
                                            font.pixelSize: 14
                                        }
                                    }

                                    MouseArea {
                                        id: tileArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Walls.set(tile.filePath)
                                    }
                                }
                            }
                        }

                        Txt {
                            width: parent.width
                            text: Walls.model.count === 0 ? "No images in " + Walls.folder + " (folder from waypaper)" : Walls.model.count + " wallpapers in " + Walls.folder.replace(Quickshell.env("HOME"), "~") + " · set with " + "waypaper / awww"
                            color: Theme.fgMuted
                            font.pixelSize: Theme.fontSm
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: 4
                            bottomPadding: 8
                        }
                    }

                    // ----- Bar -----
                    Column {
                        id: pageBar

                        width: parent.width
                        spacing: 10
                        visible: panel.tab === 2

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

                        // On: Hyprland with smart gaps, smart borders and a square single window, rounding 10, top gap 19 px.
                        // Off: all of that gone (the bar handles 1 window), rounding 5, top gap 10 px.
                        // hyprland.lua reads "hyprDynamic" when it loads, so "hyprctl reload" after switching.
                        SettingRow {
                            width: parent.width
                            label: "Dynamic Hyprland integration"
                            description: Config.opts.hyprDynamic ? "Hyprland's smart gaps and borders: a single window fills the screen without border and rounding. Rounding 10, top gap 19" : "Hyprland skips smart gaps, smart borders and square single windows, the bar handles 1 window. Rounding 5, top gap 10"

                            SwitchCtl {
                                checked: Config.opts.hyprDynamic
                                onToggled: {
                                    Config.opts.hyprDynamic = !Config.opts.hyprDynamic;
                                    // Wait briefly until the setting is saved, then reload Hyprland
                                    Quickshell.execDetached(["sh", "-c", "sleep 0.5; hyprctl reload >/dev/null 2>&1"]);
                                }
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

                        // Who blurs the bar's glass: the bar itself (shell glass, wallpaper file, pixel-exact like kitty)
                        // or Hyprland (layer blur with xray: any wallpaper program, animated ones too). Switching recreates the
                        // bar, because Hyprland's rules depend on the layer name.
                        SettingRow {
                            width: parent.width
                            label: "Glass blur"
                            description: "Own: the bar blurs the wallpaper itself, pixel-exact like kitty (static wallpaper from waypaper / awww, needs the qsglass-bar rule in hyprland.lua). Hyprland: Hyprland blurs the background behind the bar like behind kitty (any wallpaper program, animated wallpapers too)"
                            controlWidth: 330

                            Segmented {
                                width: parent.width
                                options: [
                                    {
                                        value: "own",
                                        label: "Own"
                                    },
                                    {
                                        value: "hyprland",
                                        label: "Hyprland"
                                    }
                                ]
                                value: Config.opts.barShellGlass ? "own" : "hyprland"
                                onPicked: v => Config.opts.barShellGlass = v === "own"
                            }
                        }

                        // Glass blur like Hyprland (decoration:blur). Same values as in hyprland.lua = same look as kitty.
                        SettingRow {
                            width: parent.width
                            visible: Config.opts.barShellGlass
                            label: "Glass blur values"
                            description: "Same as decoration:blur in hyprland.lua. Use the same values there and here and the bar looks exactly like a blurred window. Read them from Hyprland or reset to Hyprland's defaults"
                            controlWidth: 400

                            Row {
                                anchors.right: parent.right
                                spacing: 10

                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: String.fromCodePoint(0xF04E6)
                                    iconSize: Theme.fontSm
                                    label: "From Hyprland"
                                    idleColor: Theme.layer3
                                    onClicked: hyprBlurReader.running = true
                                }

                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: String.fromCodePoint(0xF0450)
                                    iconSize: Theme.fontSm
                                    label: "Defaults"
                                    idleColor: Theme.layer3
                                    onClicked: {
                                        for (const k of panel.glassBlurKeys)
                                            Config.opts[k] = Config.defaults[k];
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: [
                                { key: "glassBlurSize", label: "Glass blur size", desc: "decoration:blur:size, how far the blur reaches", from: 0, to: 100, step: 1, dec: 0 },
                                { key: "glassBlurPasses", label: "Glass blur passes", desc: "decoration:blur:passes. Hyprland uses 1 to 8", from: 1, to: 8, step: 1, dec: 0 },
                                { key: "glassBlurContrast", label: "Glass contrast", desc: "decoration:blur:contrast", from: 0, to: 2, step: 0.0001, dec: 4 },
                                { key: "glassBlurBrightness", label: "Glass brightness", desc: "decoration:blur:brightness", from: 0, to: 2, step: 0.0001, dec: 4 },
                                { key: "glassBlurVibrancy", label: "Glass vibrancy", desc: "decoration:blur:vibrancy, makes the colors more saturated", from: 0, to: 1, step: 0.0001, dec: 4 },
                                { key: "glassBlurVibrancyDarkness", label: "Glass vibrancy darkness", desc: "decoration:blur:vibrancy_darkness, vibrancy on dark colors", from: 0, to: 1, step: 0.0001, dec: 4 },
                                { key: "glassBlurNoise", label: "Glass noise", desc: "decoration:blur:noise", from: 0, to: 1, step: 0.0001, dec: 4 }
                            ]

                            delegate: SettingRow {
                                id: blurRow

                                required property var modelData

                                width: parent ? parent.width : 0
                                visible: Config.opts.barShellGlass
                                label: blurRow.modelData.label
                                description: blurRow.modelData.desc
                                controlWidth: 400

                                Row {
                                    spacing: 10

                                    RangeControl {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 400 - blurReset.width - 10
                                        from: blurRow.modelData.from
                                        to: blurRow.modelData.to
                                        stepSize: blurRow.modelData.step
                                        decimals: blurRow.modelData.dec
                                        value: Config.opts[blurRow.modelData.key]
                                        onEdited: v => Config.opts[blurRow.modelData.key] = v
                                    }

                                    IconButton {
                                        id: blurReset

                                        anchors.verticalCenter: parent.verticalCenter
                                        size: 30
                                        icon: String.fromCodePoint(0xF0450)
                                        iconSize: Theme.fontSm
                                        label: "Reset"
                                        idleColor: Theme.layer3
                                        onClicked: Config.opts[blurRow.modelData.key] = Config.defaults[blurRow.modelData.key]
                                    }
                                }
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
                        visible: panel.tab === 3

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

                        // Vulkan or OpenGL. Can only be chosen at startup: switching saves the choice and
                        // restarts Quickshell (~/.local/bin/qs-restart, which reads it via ~/.config/quickshell/render-env.sh).
                        SettingRow {
                            readonly property string running: Quickshell.env("QSG_RHI_BACKEND") === "opengl" ? "OpenGL" : "Vulkan"

                            width: parent.width
                            label: "Renderer"
                            description: "Switching restarts the shell · running: " + running
                            controlWidth: 220

                            Segmented {
                                width: parent.width
                                options: [
                                    {
                                        value: "vulkan",
                                        label: "Vulkan"
                                    },
                                    {
                                        value: "opengl",
                                        label: "OpenGL"
                                    }
                                ]
                                value: Config.opts.renderBackend
                                onPicked: v => {
                                    if (v === Config.opts.renderBackend)
                                        return;
                                    Config.opts.renderBackend = v;
                                    // Wait briefly until the setting is saved, then restart
                                    Quickshell.execDetached(["sh", "-c", "sleep 0.6; r=\"$HOME/.local/bin/qs-restart\"; [ -x \"$r\" ] && exec \"$r\"; pkill -x quickshell; sleep 1; setsid -f \"$HOME/.local/bin/qs-start\" >/dev/null 2>&1 </dev/null"]);
                                }
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
                        visible: panel.tab === 4

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
                        visible: panel.tab === 5

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
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveSmooth
            }

            NumberAnimation {
                target: pages
                property: "shift"
                from: 10
                to: 0
                duration: Theme.ctlMed
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveSmooth
            }
        }
    }
}
