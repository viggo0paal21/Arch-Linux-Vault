import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Settings: the top tabs (Quickshell, Hyprland, Apps, System) at the top, their pages on the left styled like the
// launcher, the options on the right with lots of room. Everything applies right away and saves automatically.
// Keyboard: Tab / Shift+Tab or arrow up/down go through all pages, Esc closes.
OverlayPanel {
    id: panel

    // Top tab (index in sections) and the page in it (index in sections[..].pages)
    property int section: 0
    property int tab: 0
    // Last open page per top tab
    property var lastTabs: [0, 0, 0, 0]

    // Apps > Opacity: writes the opacity through ~/.local/bin/qs-glass-apply into kitty, Nautilus, GTK3 dialogs,
    // Vesktop and Firefox (every app with its own value, -1 = like "All apps"). Started through python3 (needs no
    // exec permission). The script reads the values from settings.json itself, queues itself (flock) and always takes
    // most recently saved state. Debounced. Tidal (SONE) is set by services/Hypr.qml (Hyprland rule).
    property Timer appGlassDebounce: Timer {
        interval: 300
        onTriggered: panel.runAppGlass()
    }
    function runAppGlass() {
        Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.local/bin/qs-glass-apply"]);
    }
    readonly property var sections: [
        {
            name: "Quickshell",
            icon: Icons.qsShell,
            pages: ["appearance", "bar", "notifications", "animations", "performance", "commands"]
        },
        {
            name: "Hyprland",
            icon: Icons.hyprland,
            pages: ["hyprWindows", "hyprLayout"]
        },
        {
            name: "Apps",
            icon: Icons.apps,
            pages: ["appsOpacity", "appsKitty"]
        },
        {
            name: "System",
            icon: Icons.desktopTower,
            pages: Config.opts.systemFontMenu ? ["profile", "wallpaper", "gaming", "systemFont"] : ["profile", "wallpaper", "gaming"]
        }
    ]
    readonly property var pageInfo: ({
            appearance: { name: "Appearance", icon: Icons.palette },
            bar: { name: "Bar", icon: Icons.dockTop },
            notifications: { name: "Notifications & OSD", icon: Icons.bellOutline },
            animations: { name: "Animations", icon: Icons.play },
            performance: { name: "Performance", icon: Icons.speedometer },
            commands: { name: "Commands", icon: Icons.consoleLine },
            hyprWindows: { name: "Windows", icon: Icons.roundedCorner },
            hyprLayout: { name: "Layout & rendering", icon: Icons.viewQuilt },
            appsOpacity: { name: "Opacity", icon: Icons.opacityDrop },
            appsKitty: { name: "kitty", icon: Icons.terminal },
            profile: { name: "Profile", icon: Icons.account },
            wallpaper: { name: "Wallpaper", icon: Icons.image },
            gaming: { name: "Gaming", icon: Icons.gamepad },
            systemFont: { name: "Font", icon: Icons.formatFont }
        })
    readonly property var tabs: panel.sections[panel.section].pages
    readonly property string page: panel.tabs[Math.max(0, Math.min(panel.tab, panel.tabs.length - 1))]

    // ---------- Apps > Opacity ----------
    // Value of an app: its own value or (-1) the one from "All apps"
    function appOp(key) {
        const v = Config.opts[key];
        return v >= 0 ? v : Config.opts.appOpacity;
    }
    // On/off of an app: its own value or (-1) like the old "App glass"
    function appOn(key) {
        const v = Config.opts[key];
        return v >= 0 ? v === 1 : Config.opts.appGlass;
    }
    readonly property var appOpacityKeys: ["appOpacityKitty", "appOpacityTidal", "appOpacityNautilus", "appOpacityDialogs", "appOpacityVesktop", "appOpacityFirefox"]
    function setAllApps(v) {
        Config.opts.appOpacity = v;
        for (const k of panel.appOpacityKeys)
            Config.opts[k] = -1;
        panel.appGlassDebounce.restart();
    }
    function setApp(key, v) {
        Config.opts[key] = v;
        panel.appGlassDebounce.restart();
    }
    function toggleApp(key) {
        Config.opts[key] = panel.appOn(key) ? 0 : 1;
        panel.appGlassDebounce.restart();
    }
    // Icon of an app from its desktop entry (first match), otherwise the name itself as the icon name
    function appIconFor(names) {
        for (const n of names) {
            const e = DesktopEntries.heuristicLookup(n);
            if (e && e.icon)
                return e.icon;
        }
        return names[0];
    }

    // ---------- Hyprland ----------
    // Current values from Hyprland (hyprctl getoption), for rows without their own value (-1 = hyprland.lua applies).
    // Read when a Hyprland tab opens and after a reset.
    property var hyprLive: ({})
    function hyprVal(key, option, fallback) {
        const v = Config.opts[key];
        if (v >= 0)
            return v;
        const l = panel.hyprLive[option];
        return l !== undefined ? l : fallback;
    }
    // Remove the own value: services/Hypr.qml reloads Hyprland (then hyprland.lua applies), read again afterwards
    function hyprReset(key) {
        Config.opts[key] = -1;
        hyprLiveDelay.restart();
    }

    Process {
        id: hyprLiveReader

        command: ["sh", "-c", "for o in decoration:rounding decoration:shadow:enabled decoration:blur:size decoration:blur:passes render:direct_scanout misc:vrr; do printf '%s ' \"$o\"; hyprctl -j getoption \"$o\" | tr -d '\\n'; echo; done"]
        stdout: SplitParser {
            onRead: line => {
                const i = line.indexOf(" ");
                if (i < 0)
                    return;
                let j;
                try {
                    j = JSON.parse(line.slice(i + 1));
                } catch (e) {
                    return;
                }
                const v = j.int !== undefined ? j.int : (j.float !== undefined ? j.float : (j.bool !== undefined ? (j.bool ? 1 : 0) : undefined));
                if (typeof v !== "number")
                    return;
                const m = Object.assign({}, panel.hyprLive);
                m[line.slice(0, i)] = v;
                panel.hyprLive = m;
            }
        }
    }

    Timer {
        id: hyprLiveDelay

        interval: 700
        onTriggered: hyprLiveReader.running = true
    }

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

    // ---------- System > Gaming ----------
    // Hyprland's VRR modes (misc:vrr)
    function vrrText(v) {
        if (v === 0)
            return "Off: the screen always runs at its fixed refresh rate";
        if (v === 1)
            return "Always: G-Sync / FreeSync everywhere, some screens flicker slightly on grey areas";
        if (v === 3)
            return "Games: only fullscreen apps that report themselves as a game or video";
        return "Fullscreen: only fullscreen apps (games, videos in fullscreen)";
    }
    // MangoHud: new game config (row with name field open/closed) and what the HUD can show
    property bool mhAdding: false
    property bool mhAddError: false
    readonly property var mhItems: [
        { key: "fps", label: "FPS" },
        { key: "frametime", label: "Frame time" },
        { key: "frame_timing", label: "Frame time graph" },
        { key: "show_fps_limit", label: "FPS limit" },
        { key: "present_mode", label: "Present mode" },
        { key: "cpu_stats", label: "CPU" },
        { key: "cpu_temp", label: "CPU temp" },
        { key: "gpu_stats", label: "GPU" },
        { key: "gpu_temp", label: "GPU temp" },
        { key: "ram", label: "RAM" },
        { key: "vram", label: "VRAM" }
    ]
    function createGameConfig(name) {
        if (MangoHud.addGame(name)) {
            panel.mhAdding = false;
            panel.mhAddError = false;
        } else {
            panel.mhAddError = true;
        }
    }

    // ---------- System > Profile ----------
    // Picture picker: folders (Pictures, Downloads, Wallpapers, Home), subfolders and pictures in them (the newest picMax).
    // Square thumbnails through the same cache as the wallpapers (Walls.ensure). The folders are only read and
    // watched while the page is open (Loader), otherwise nothing.
    property string picPlace: "pictures"
    readonly property string picRoot: {
        if (panel.picPlace === "downloads")
            return User.downloadsDir;
        if (panel.picPlace === "wallpapers")
            return Walls.folder;
        if (panel.picPlace === "home")
            return Quickshell.env("HOME");
        return User.picturesDir;
    }
    // Subfolder that was clicked ("" = the top folder itself)
    property string picSub: ""
    readonly property string picDir: panel.picSub !== "" ? panel.picSub : panel.picRoot
    readonly property bool picLive: panel.open && panel.page === "profile"
    readonly property int picMax: 120
    readonly property int picThumb: 264
    // [{ dir, path, name, thumb }], folders first
    property var picItems: []
    property int picTotal: 0
    property bool picReady: false
    onPicPlaceChanged: panel.picSub = ""
    // New folder: the grid fades out until the new list is ready
    onPicDirChanged: panel.picReady = false

    function picUp() {
        const up = panel.picDir.replace(/\/[^\/]*\/?$/, "");
        panel.picSub = up.length > panel.picRoot.length ? up : "";
    }

    property Loader picLoader: Loader {
        active: panel.picLive && panel.picDir !== ""
        onActiveChanged: {
            if (!active)
                panel.picReady = false;
        }

        sourceComponent: Component {
            Item {
                id: picScan

                function rebuild() {
                    // Still reading: wait. Folder missing (status Null): empty.
                    if (dirModel.status === FolderListModel.Loading || fileModel.status === FolderListModel.Loading)
                        return;
                    const items = [];
                    for (let i = 0; i < Math.min(dirModel.count, 60); i++)
                        items.push({
                            dir: true,
                            path: dirModel.get(i, "filePath"),
                            name: dirModel.get(i, "fileName"),
                            thumb: ""
                        });
                    const missing = [];
                    const n = Math.min(fileModel.count, panel.picMax);
                    for (let i = 0; i < n; i++) {
                        const p = fileModel.get(i, "filePath");
                        const t = Walls.thumbFor(p, fileModel.get(i, "fileModified"), "sq" + panel.picThumb);
                        items.push({
                            dir: false,
                            path: p,
                            name: fileModel.get(i, "fileName"),
                            thumb: t
                        });
                        if (!Walls.isReady(t))
                            missing.push([p, t]);
                    }
                    panel.picTotal = fileModel.count;
                    panel.picItems = items;
                    panel.picReady = true;
                    Walls.ensure(missing, panel.picThumb, panel.picThumb);
                }

                FolderListModel {
                    id: dirModel

                    folder: "file://" + panel.picDir
                    showFiles: false
                    showDirs: true
                    showDotAndDotDot: false
                    showHidden: false
                    sortField: FolderListModel.Name
                    sortCaseSensitive: false
                    onStatusChanged: picRebuild.restart()
                    onCountChanged: picRebuild.restart()
                }

                FolderListModel {
                    id: fileModel

                    folder: "file://" + panel.picDir
                    showDirs: false
                    showHidden: false
                    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.bmp", "*.jxl", "*.avif"]
                    caseSensitive: false
                    sortField: FolderListModel.Time
                    onStatusChanged: picRebuild.restart()
                    onCountChanged: picRebuild.restart()
                }

                Timer {
                    id: picRebuild

                    interval: 60
                    onTriggered: picScan.rebuild()
                }
            }
        }
    }

    // Open a page directly (profile picture in the corner, control center)
    function openPage(name) {
        for (let s = 0; s < panel.sections.length; s++) {
            const t = panel.sections[s].pages.indexOf(name);
            if (t >= 0) {
                if (s !== panel.section)
                    panel.rememberTab();
                panel.section = s;
                panel.tab = t;
                return;
            }
        }
    }

    Connections {
        target: Ui

        function onSettingsPageChanged() {
            if (Ui.settingsPage === "")
                return;
            panel.openPage(Ui.settingsPage);
            Ui.settingsPage = "";
        }
    }

    // System font: font for all apps (GTK 3/4, Qt through fontconfig, Firefox, Electron) and the shell.
    // The current value comes from gtk-3.0/settings.ini (so the real system state), read when opening.
    // Applying is done by ~/.local/bin/qs-font-apply (it saves the old state the first time, qs-font-revert restores
    // it again). The shell itself follows right away through uiFont.
    property string systemFont: ""

    function applySystemFont(family) {
        const prev = Config.opts.uiFont;
        panel.systemFont = family;
        Config.opts.uiFont = family;
        Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.local/bin/qs-font-apply", family, prev]);
    }

    Process {
        id: systemFontReader

        command: ["sh", "-c", "sed -n 's/^gtk-font-name=//p' \"${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini\" 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "Noto Sans  10" -> "Noto Sans"
                const t = this.text.trim().replace(/\s+[0-9]+(\.[0-9]+)?$/, "").trim();
                if (t !== "")
                    panel.systemFont = t;
            }
        }
    }

    onOpenChanged: {
        if (!panel.open)
            cropDialog.open = false;
        if (panel.open) {
            systemFontReader.running = true;
            if (panel.section === 1 || panel.page === "gaming")
                hyprLiveReader.running = true;
            if (panel.page === "gaming")
                MangoHud.refresh();
        }
    }

    // Durch alle Seiten aller Ober-Tabs (Tab / Pfeiltasten)
    function switchTab(delta) {
        const flat = [];
        for (let s = 0; s < panel.sections.length; s++) {
            for (let t = 0; t < panel.sections[s].pages.length; t++)
                flat.push([s, t]);
        }
        let i = 0;
        while (i < flat.length && !(flat[i][0] === panel.section && flat[i][1] === panel.tab))
            i++;
        const n = flat[((i < flat.length ? i : 0) + delta + flat.length) % flat.length];
        if (n[0] !== panel.section)
            panel.rememberTab();
        panel.section = n[0];
        panel.tab = n[1];
    }

    // Switch top tab: continue where you left off (first page the first time)
    function openSection(s) {
        if (s === panel.section)
            return;
        panel.rememberTab();
        const t = Math.min(panel.lastTabs[s] || 0, panel.sections[s].pages.length - 1);
        panel.section = s;
        panel.tab = t;
    }

    // Hover and selection box share one layer that is drawn as a whole with the opacity of the
    // selection box. Inside it the selection box is fully opaque, the hover box proportionally: where both
    // overlap while gliding, the white doesn't add up (otherwise a brighter stripe with a visible edge),
    // the brighter one simply wins. Without glass (opaque colors) boxAlpha is 1 and everything is as before.
    readonly property real boxAlpha: Theme.fillStrong.a
    function boxColor(c) {
        return Qt.rgba(c.r, c.g, c.b, Math.min(1, c.a / panel.boxAlpha));
    }

    // Remember the current top tab's page before leaving it
    function rememberTab() {
        const l = panel.lastTabs.slice();
        l[panel.section] = panel.tab;
        panel.lastTabs = l;
    }

    open: Ui.panel === "settings"
    screen: Ui.panelScreen
    dim: true
    dimOpacity: 0.45
    ns: "qs-settings"
    onDismissed: Ui.close()
    onPageChanged: {
        cropDialog.open = false;
        flick.contentY = 0;
        tabIn.restart();
        if ((panel.section === 1 || panel.page === "gaming") && panel.open)
            hyprLiveReader.running = true;
        if (panel.page === "gaming" && panel.open)
            MangoHud.refresh();
    }
    // New top tab: the page list on the left fades in again (the highlight jumps along with it)
    onSectionChanged: sideIn.restart()

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
        color: cpArea.pressed ? Theme.pressed : (cpArea.containsMouse ? Theme.fillStrong : Theme.fill)

        Behavior on color {
            CAnim {}
        }

        Glyph {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.left
            color: Theme.textMuted
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
            color: Theme.textMuted
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
        controlWidth: 390
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
                    color: Theme.textMuted
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
                    color: Theme.textMuted
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

        readonly property int tabHeight: 40

        // Fade in + short glide, subpixel like the bar: drawn as a texture while moving (text stays sharp),
        // at rest on whole pixels without a texture
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2) + 12 * (1 - panel.progress)
        // Bigger than before (940 x 700): more room for texts and previews, font and buttons keep their size
        width: Math.min(1240, parent.width - 120)
        height: Math.min(900, parent.height - 140)
        opacity: panel.progress
        layer.enabled: panel.progress > 0 && panel.progress < 1
        layer.smooth: true
        focus: true

        // Esc first closes the crop dialog, then the settings
        Keys.onEscapePressed: ev => {
            if (cropDialog.open)
                cropDialog.cancel();
            else
                ev.accepted = false;
        }
        Keys.onTabPressed: panel.switchTab(1)
        Keys.onBacktabPressed: panel.switchTab(-1)
        Keys.onDownPressed: panel.switchTab(1)
        Keys.onUpPressed: panel.switchTab(-1)

        // ---------- Oben: Titel, Ober-Tabs, Schliessen ----------
        Item {
            id: topBar

            x: 14
            y: 14
            width: parent.width - 28
            height: 48

            Txt {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "Settings"
                font.pixelSize: Theme.fontLg + 3
                font.weight: Theme.uiWeightStrong
            }

            // Hover and selection box as one layer (see boxAlpha): no brighter stripe where they overlap
            Item {
                anchors.fill: parent
                opacity: panel.boxAlpha
                layer.enabled: panel.boxAlpha < 1

                // Hover: slightly dimmer box that glides under the mouse from top tab to top tab (like in the launcher).
                // Appears right under the mouse (fades in), only glides along after that.
                Rectangle {
                    id: secHover

                    property int idx: 0
                    readonly property Item it: secRepeater.count > idx ? secRepeater.itemAt(idx) : null

                    x: sectionRow.x + (it ? it.x : 0)
                    y: sectionRow.y
                    width: it ? it.width : 0
                    height: card.tabHeight
                    radius: Theme.radius
                    color: panel.boxColor(secHoverArea.pressed ? Theme.pressed : Theme.hover)
                    opacity: secHoverArea.containsMouse ? 1 : 0

                    Behavior on x {
                        enabled: secHover.opacity > 0.01

                        SmoothedAnimation {
                            velocity: 400
                            duration: Theme.ctlFast
                        }
                    }
                    Behavior on width {
                        enabled: secHover.opacity > 0.01

                        SmoothedAnimation {
                            velocity: 400
                            duration: Theme.ctlFast
                        }
                    }
                    Behavior on opacity {
                        Anim {
                            duration: Theme.ctlFast
                        }
                    }
                    Behavior on color {
                        CAnim {}
                    }
                }

                // Bright highlight of the current top tab: glides like the selection in the launcher
                Rectangle {
                    id: secHighlight

                    readonly property Item cur: secRepeater.count > panel.section ? secRepeater.itemAt(panel.section) : null

                    x: sectionRow.x + (cur ? cur.x : 0)
                    y: sectionRow.y
                    width: cur ? cur.width : 0
                    height: card.tabHeight
                    radius: Theme.radius
                    color: panel.boxColor(Theme.fillStrong)

                    Behavior on x {
                        SmoothedAnimation {
                            velocity: 400
                            duration: Theme.ctlFast
                        }
                    }
                    Behavior on width {
                        SmoothedAnimation {
                            velocity: 400
                            duration: Theme.ctlFast
                        }
                    }
                }
            }

            // Top tabs, aligned with the options column
            Row {
                id: sectionRow

                x: content.x - topBar.x - 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    id: secRepeater

                    model: panel.sections

                    delegate: Item {
                        id: secItem

                        required property var modelData
                        required property int index
                        readonly property bool current: secItem.index === panel.section

                        width: Math.ceil(secRow.implicitWidth) + 28
                        height: card.tabHeight

                        Row {
                            id: secRow

                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                text: secItem.modelData.icon
                                color: secItem.current ? Theme.fg : Theme.textMuted
                                font.pixelSize: Theme.iconSize - 2

                                Behavior on color {
                                    CAnim {}
                                }
                            }

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                text: secItem.modelData.name
                                color: secItem.current ? Theme.fg : Theme.textDim

                                Behavior on color {
                                    CAnim {}
                                }
                            }
                        }
                    }
                }
            }

            // One mouse area over all top tabs (including the gaps between them): the hover box glides without flickering
            MouseArea {
                id: secHoverArea

                function indexAt(mx) {
                    for (let i = 0; i < secRepeater.count; i++) {
                        const it = secRepeater.itemAt(i);
                        if (it && mx < it.x + it.width + sectionRow.spacing / 2)
                            return i;
                    }
                    return Math.max(0, secRepeater.count - 1);
                }

                x: sectionRow.x
                y: sectionRow.y
                width: sectionRow.width
                height: sectionRow.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: secHover.idx = indexAt(mouseX)
                onPositionChanged: mouse => secHover.idx = indexAt(mouse.x)
                onClicked: mouse => panel.openSection(indexAt(mouse.x))
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                size: 36
                icon: Icons.close
                fg: Theme.textDim
                onClicked: Ui.close()
            }
        }

        // Line below the header
        Rectangle {
            id: topLine

            x: 14
            y: topBar.y + topBar.height + 10
            width: parent.width - 28
            height: 1
            color: Theme.hairline
        }

        // ---------- Links: Seiten des Ober-Tabs ----------
        Item {
            id: sidebar

            x: 14
            y: topLine.y + 1 + 14
            width: 250
            height: parent.height - y - 14

            Item {
                id: tabList

                property real shift: 0

                width: parent.width
                height: tabCol.height
                // New top tab: briefly fade in as a texture (text stays sharp)
                layer.enabled: sideIn.running
                layer.smooth: true

                transform: Translate {
                    y: tabList.shift
                }

                // Hover and selection box as one layer (see boxAlpha): no brighter stripe where they overlap
                Item {
                    width: parent.width
                    height: parent.height
                    opacity: panel.boxAlpha
                    layer.enabled: panel.boxAlpha < 1

                    // Hover: slightly dimmer box that glides under the mouse from page to page (like in the launcher).
                    // Appears right under the mouse (fades in), only glides along after that.
                    Rectangle {
                        id: tabHover

                        property int idx: 0

                        width: parent.width
                        height: card.tabHeight
                        y: Math.max(0, Math.min(tabHover.idx, panel.tabs.length - 1)) * (card.tabHeight + tabCol.spacing)
                        radius: Theme.radius
                        color: panel.boxColor(tabHoverArea.pressed ? Theme.pressed : Theme.hover)
                        opacity: tabHoverArea.containsMouse ? 1 : 0

                        Behavior on y {
                            enabled: tabHover.opacity > 0.01

                            SmoothedAnimation {
                                velocity: 400
                                duration: Theme.ctlFast
                            }
                        }
                        Behavior on opacity {
                            Anim {
                                duration: Theme.ctlFast
                            }
                        }
                        Behavior on color {
                            CAnim {}
                        }
                    }

                    // Bright highlight of the current page: glides like the selection in the launcher. When the
                    // top tab changes it jumps (the whole list fades in again then).
                    Rectangle {
                        width: parent.width
                        height: card.tabHeight
                        y: Math.max(0, Math.min(panel.tab, panel.tabs.length - 1)) * (card.tabHeight + tabCol.spacing)
                        radius: Theme.radius
                        color: panel.boxColor(Theme.fillStrong)

                        Behavior on y {
                            enabled: !sideIn.running

                            SmoothedAnimation {
                                velocity: 400
                                duration: Theme.ctlFast
                            }
                        }
                    }
                }

                Column {
                    id: tabCol

                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: panel.tabs

                        delegate: Item {
                            id: tabRow

                            required property var modelData
                            required property int index
                            readonly property bool current: tabRow.index === panel.tab
                            readonly property var info: panel.pageInfo[tabRow.modelData] || ({
                                    name: tabRow.modelData,
                                    icon: ""
                                })

                            width: tabCol.width
                            height: card.tabHeight

                            Glyph {
                                id: tabIcon

                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22
                                text: tabRow.info.icon
                                color: tabRow.current ? Theme.fg : Theme.textMuted
                                font.pixelSize: Theme.iconSize - 2

                                Behavior on color {
                                    CAnim {}
                                }
                            }

                            Txt {
                                anchors.left: tabIcon.right
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: tabRow.info.name
                                color: tabRow.current ? Theme.fg : Theme.textDim

                                Behavior on color {
                                    CAnim {}
                                }
                            }
                        }
                    }
                }

                // One mouse area over the whole list (including the gaps between rows): no flickering
                MouseArea {
                    id: tabHoverArea

                    function indexAt(my) {
                        return Math.max(0, Math.min(panel.tabs.length - 1, Math.floor(my / (card.tabHeight + tabCol.spacing))));
                    }

                    anchors.fill: tabCol
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: tabHover.idx = indexAt(mouseY)
                    onPositionChanged: mouse => tabHover.idx = indexAt(mouse.y)
                    onClicked: mouse => panel.tab = indexAt(mouse.y)
                }
            }

            // Bottom: profile (picture + name, click opens System > Profile), reset
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 12

                Item {
                    id: sideProfile

                    width: parent.width
                    height: 56

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius
                        color: sideProfileArea.pressed ? Theme.pressed : (sideProfileArea.containsMouse ? Theme.hover : Qt.rgba(1, 1, 1, 0))

                        Behavior on color {
                            CAnim {}
                        }
                    }

                    Avatar {
                        id: sideAvatar

                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        size: 40
                        hovered: sideProfileArea.containsMouse
                    }

                    Column {
                        anchors.left: sideAvatar.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Txt {
                            width: parent.width
                            text: User.name
                            font.weight: Theme.uiWeightStrong
                            elide: Text.ElideRight
                        }

                        Txt {
                            width: parent.width
                            text: User.login + (User.host !== "" ? "@" + User.host : "")
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: sideProfileArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.openPage("profile")
                    }
                }

                Txt {
                    x: 14
                    width: parent.width - 28
                    text: "Changes save automatically"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSm
                }

                IconButton {
                    x: 4
                    size: 36
                    icon: Icons.restart
                    iconSize: Theme.iconSize - 2
                    label: "Reset to defaults"
                    fg: Theme.textDim
                    onClicked: Config.reset()
                }
            }
        }

        Rectangle {
            id: divider

            x: sidebar.x + sidebar.width + 14
            y: sidebar.y
            width: 1
            height: sidebar.height
            color: Theme.hairline
        }

        // ---------- Right: options of the page ----------
        Item {
            id: content

            x: divider.x + 1 + 22
            y: sidebar.y
            width: parent.width - x - 14
            height: sidebar.height

            Item {
                id: contentHeader

                width: parent.width
                height: card.tabHeight

                Txt {
                    id: pageTitle

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: (panel.pageInfo[panel.page] || {}).name || ""
                    font.pixelSize: Theme.fontLg + 3
                    font.weight: Theme.uiWeightStrong
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
                    height: (({
                                appearance: pageAppearance,
                                bar: pageBar,
                                notifications: pageNotifications,
                                animations: pageAnimations,
                                performance: pagePerformance,
                                commands: pageCommands,
                                hyprWindows: pageHyprWindows,
                                hyprLayout: pageHyprLayout,
                                appsOpacity: pageAppsOpacity,
                                appsKitty: pageAppsKitty,
                                profile: pageProfile,
                                wallpaper: pageWallpaper,
                                gaming: pageGaming,
                                systemFont: pageSystemFont
                            })[panel.page] || pageAppearance).implicitHeight

                    // Page change: glides smoothly, drawn as a texture meanwhile (sharp text)
                    layer.enabled: tabIn.running
                    layer.smooth: true

                    transform: Translate {
                        y: pages.shift
                    }

                    // ----- Quickshell > Appearance -----
                    Column {
                        id: pageAppearance

                        width: parent.width
                        spacing: 10
                        visible: panel.page === "appearance"

                        // Rows that appear fade in, the ones below glide smoothly after (instant on a page switch,
                        // the whole page glides then)
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: tabIn.running ? 0 : Theme.ctlMed
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveSmooth
                            }
                        }
                        // With "Subpixel glide" every row glides between pixels: drawn as an image while moving
                        // (text sharp), without it again at the target
                        move: Transition {
                            SequentialAnimation {
                                PropertyAction {
                                    property: "layer.smooth"
                                    value: true
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: Config.opts.barGlide && !tabIn.running
                                }
                                NumberAnimation {
                                    property: "y"
                                    duration: tabIn.running ? 0 : Theme.ctlMed
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveSmooth
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: false
                                }
                            }
                        }

                        // Section title
                        Txt {
                            readonly property bool isHeader: true

                            width: parent.width
                            topPadding: 0
                            text: "Glass"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.uiWeightStrong
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.8
                        }

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

                        // Section title
                        Txt {
                            readonly property bool isHeader: true

                            width: parent.width
                            topPadding: 18
                            text: "Shape & text"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.uiWeightStrong
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.8
                        }

                        SettingRow {
                            width: parent.width
                            label: "Corner radius"
                            description: "Corners of panels, cards and the floating bar in real pixels, same as rounding in hyprland.lua (10 = exactly like the windows). Buttons and boxes inside are a bit less round. 0 = square"

                            RangeControl {
                                from: 0
                                to: 28
                                value: Config.opts.cornerRadius
                                suffix: " px"
                                onEdited: v => Config.opts.cornerRadius = v
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
                            label: "Shell font"
                            description: "Only Quickshell. System > Font sets it too"

                            FontSelect {
                                width: parent.width
                                value: Config.opts.uiFont
                                menuParent: card
                                scrollArea: flick
                                active: panel.open && panel.page === "appearance"
                                onPicked: family => Config.opts.uiFont = family
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

                        // Section title
                        Txt {
                            readonly property bool isHeader: true

                            width: parent.width
                            topPadding: 18
                            text: "Colors & icons"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.uiWeightStrong
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.8
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
                            label: "Rounded screen corners"
                            description: "Black corners above windows (not above fullscreen)"

                            SwitchCtl {
                                checked: Config.opts.screenCorners
                                onToggled: Config.opts.screenCorners = !Config.opts.screenCorners
                            }
                        }
                    }

                    // ----- Quickshell > Bar -----
                    Column {
                        id: pageBar

                        width: parent.width
                        spacing: 10
                        visible: panel.page === "bar"

                        // Rows that appear fade in, the ones below glide smoothly after (instant on a page switch,
                        // the whole page glides then)
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: tabIn.running ? 0 : Theme.ctlMed
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveSmooth
                            }
                        }
                        // With "Subpixel glide" every row glides between pixels: drawn as an image while moving
                        // (text sharp), without it again at the target
                        move: Transition {
                            SequentialAnimation {
                                PropertyAction {
                                    property: "layer.smooth"
                                    value: true
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: Config.opts.barGlide && !tabIn.running
                                }
                                NumberAnimation {
                                    property: "y"
                                    duration: tabIn.running ? 0 : Theme.ctlMed
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveSmooth
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: false
                                }
                            }
                        }

                        // Section title
                        Txt {
                            readonly property bool isHeader: true

                            width: parent.width
                            topPadding: 0
                            text: "Size & position"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.uiWeightStrong
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.8
                        }

                        // Thickness docked (top, moves both) and floating (bottom, floating only). Reset = defaults
                        SettingRow {
                            id: heightRow

                            readonly property bool dynamic: Config.opts.barFloating && Config.opts.barFloatingDynamic
                            readonly property int labelWidth: 64
                            readonly property real sliderWidth: heightCol.width - heightRow.labelWidth - resetBtn.width - 20

                            width: parent.width
                            implicitHeight: Math.max(64, heightCol.height + 28, heightRow.textsHeight + 26)
                            label: "Bar height"
                            description: heightRow.dynamic ? "Docked moves both, Floating only the floating bar. Docked is 2 px taller on purpose: with one window the bar covers the top 2 px of that window, so no gap or flickering line shows between them (also while docking), and the icons sit exactly in the middle" : ""
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
                                        color: Theme.textMuted
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
                                        color: Theme.textMuted
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
                                        idleColor: Theme.fill
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

                        // On: smooth dock animation (between pixels, like Hyprland windows), plus panels sliding out
                        // (dashboard, control center, launcher) and in the menus expanding lists and
                        // rows sliding into place. Content is minimally softer while moving.
                        // Off: whole pixels there, always crisp (previous behavior). Panels, selection boxes, sliders
                        // and switches always glide smoothly anyway.
                        SettingRow {
                            width: parent.width
                            label: "Subpixel glide"
                            description: "Animations move between pixels like Hyprland windows: the bar's dock animation, panels sliding in (dashboard, control center, launcher), and in menus expanding lists and rows sliding into place. Text and icons are a touch softer only while moving. Off = these move in whole pixels, always crisp"

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
                                    idleColor: Theme.fill
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
                                    idleColor: Theme.fill
                                    onClicked: Config.opts.barFloatSide = Config.defaults.barFloatSide
                                }
                            }
                        }

                        // Section title
                        Txt {
                            readonly property bool isHeader: true

                            width: parent.width
                            topPadding: 18
                            text: "Background"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.uiWeightStrong
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.8
                        }

                        // Bar black instead of glass as soon as windows are open (before: two switches "Solid bar with windows" + "Only 1").
                        // Only with Transparency "Everywhere", otherwise the bar is black anyway.
                        SettingRow {
                            width: parent.width
                            visible: Config.opts.transparency === "everywhere"
                            label: "Black with windows"
                            description: "Never: always glass. 1 window: black with exactly 1 tiled window, glass with none or 2 and more. Any: black as soon as a window is open. Floating windows never count"
                            controlWidth: 330

                            Segmented {
                                width: parent.width
                                options: [
                                    {
                                        value: "never",
                                        label: "Never"
                                    },
                                    {
                                        value: "single",
                                        label: "1 window"
                                    },
                                    {
                                        value: "any",
                                        label: "Any"
                                    }
                                ]
                                value: !Config.opts.barSolidWithWindows ? "never" : (Config.opts.barSolidOnlySingle ? "single" : "any")
                                onPicked: v => {
                                    Config.opts.barSolidWithWindows = v !== "never";
                                    if (v !== "never")
                                        Config.opts.barSolidOnlySingle = v === "single";
                                }
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
                            label: "Transparent when empty"
                            description: Config.opts.barBoxes ? "Always on with Group boxes (only the boxes show while the workspace is empty)" : "No windows on the workspace = see-through, 1 or more = black"
                            locked: Config.opts.barBoxes

                            SwitchCtl {
                                checked: Config.opts.barAutoTransparent || Config.opts.barBoxes
                                onToggled: Config.opts.barAutoTransparent = !Config.opts.barAutoTransparent
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
                            label: "Group boxes"
                            description: "Puts every group in the bar (launcher, workspaces, tray, system info, status, power) in its own box. Turns on Transparent when empty"

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
                                        border.color: boxColorArea.containsMouse || boxColorBlock.open ? Theme.textDim : Theme.hairlineStrong

                                        Behavior on border.color {
                                            CAnim {}
                                        }

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
                                        idleColor: Theme.fill
                                        onClicked: Config.opts.barBoxColor = Config.defaults.barBoxColor
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: boxPicker.implicitHeight + 36
                                visible: boxColorBlock.open
                                radius: Theme.radius
                                color: Theme.fill

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

                        // Who blurs the bar's glass: the bar itself (shell glass, wallpaper file, pixel-exact like kitty)
                        // or Hyprland (layer blur with xray: any wallpaper program, animated ones too). Switching recreates the
                        // bar, because Hyprland's rules depend on the layer name.
                        SettingRow {
                            width: parent.width
                            label: "Glass blur"
                            description: Config.opts.barShellGlass ? "Own (experimental): the bar blurs the wallpaper itself, pixel-exact like kitty. Only static wallpapers from waypaper / awww, needs the qsglass-bar rule in hyprland.lua. Only use it if Hyprland's blur gives you problems" : "Hyprland (default): Hyprland blurs the background behind the bar like behind kitty, with any wallpaper program and animated wallpapers too. Own is experimental, only for problems with this"
                            controlWidth: 360

                            Segmented {
                                width: parent.width
                                options: [
                                    {
                                        value: "hyprland",
                                        label: "Hyprland"
                                    },
                                    {
                                        value: "own",
                                        label: "Own (experimental)"
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
                                    idleColor: Theme.fill
                                    onClicked: hyprBlurReader.running = true
                                }

                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: String.fromCodePoint(0xF0450)
                                    iconSize: Theme.fontSm
                                    label: "Defaults"
                                    idleColor: Theme.fill
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
                                        idleColor: Theme.fill
                                        onClicked: Config.opts[blurRow.modelData.key] = Config.defaults[blurRow.modelData.key]
                                    }
                                }
                            }
                        }

                        // Section title
                        Txt {
                            readonly property bool isHeader: true

                            width: parent.width
                            topPadding: 18
                            text: "Content"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.uiWeightStrong
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.8
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
                                        color: iconTile.selected ? Theme.accent : (iconTileArea.pressed ? Theme.pressed : (iconTileArea.containsMouse ? Theme.hover : Theme.fillStrong))
                                        border.width: 1
                                        border.color: iconTile.selected ? Theme.accent : (iconTileArea.containsMouse ? Theme.textDim : Theme.hairlineStrong)
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
                                                color: iconTile.selected ? Theme.accentFg : Theme.textDim
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
                                    idleColor: Theme.fill
                                    onClicked: Config.opts.launcherIconSize = Config.defaults.launcherIconSize
                                }
                            }
                        }

                        // Where the app launcher opens: exactly in the middle of the screen, or it slides out of the launcher logo
                        // from under the bar like the dashboard and control center (their speed and curves)
                        SettingRow {
                            width: parent.width
                            label: "Launcher position"
                            description: Config.opts.launcherPosition === "logo" ? "From the logo: slides down out of the launcher icon like the dashboard and control center, with their animation speed and curves" : "Center (default): opens exactly in the middle of the screen and fades in. From the logo slides it down out of the launcher icon like the dashboards"
                            controlWidth: 360

                            Segmented {
                                width: parent.width
                                options: [
                                    {
                                        value: "center",
                                        label: "Center"
                                    },
                                    {
                                        value: "logo",
                                        label: "From the logo"
                                    }
                                ]
                                value: Config.opts.launcherPosition
                                onPicked: v => Config.opts.launcherPosition = v
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
                    }

                    // ----- Quickshell > Notifications & OSD -----
                    Column {
                        id: pageNotifications

                        width: parent.width
                        spacing: 10
                        visible: panel.page === "notifications"

                        // Rows that appear fade in, the ones below glide smoothly after (instant on a page switch,
                        // the whole page glides then)
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: tabIn.running ? 0 : Theme.ctlMed
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveSmooth
                            }
                        }
                        // With "Subpixel glide" every row glides between pixels: drawn as an image while moving
                        // (text sharp), without it again at the target
                        move: Transition {
                            SequentialAnimation {
                                PropertyAction {
                                    property: "layer.smooth"
                                    value: true
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: Config.opts.barGlide && !tabIn.running
                                }
                                NumberAnimation {
                                    property: "y"
                                    duration: tabIn.running ? 0 : Theme.ctlMed
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveSmooth
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: false
                                }
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
                    }

                    // ----- Quickshell > Animations -----
                    Column {
                        id: pageAnimations

                        width: parent.width
                        spacing: 10
                        visible: panel.page === "animations"

                        // Rows that appear fade in, the ones below glide smoothly after (instant on a page switch,
                        // the whole page glides then)
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: tabIn.running ? 0 : Theme.ctlMed
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveSmooth
                            }
                        }
                        // With "Subpixel glide" every row glides between pixels: drawn as an image while moving
                        // (text sharp), without it again at the target
                        move: Transition {
                            SequentialAnimation {
                                PropertyAction {
                                    property: "layer.smooth"
                                    value: true
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: Config.opts.barGlide && !tabIn.running
                                }
                                NumberAnimation {
                                    property: "y"
                                    duration: tabIn.running ? 0 : Theme.ctlMed
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveSmooth
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: false
                                }
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Animations"

                            SwitchCtl {
                                checked: Config.opts.animations
                                onToggled: Config.opts.animations = !Config.opts.animations
                            }
                        }

                        // Same switch as under Bar (both change barGlide)
                        SettingRow {
                            width: parent.width
                            label: "Subpixel glide"
                            description: "Animations move between pixels like Hyprland windows: the bar's dock animation, panels sliding in (dashboard, control center, launcher), and in menus expanding lists and rows sliding into place. Text and icons are a touch softer only while moving. Off = these move in whole pixels, always crisp"

                            SwitchCtl {
                                checked: Config.opts.barGlide
                                onToggled: Config.opts.barGlide = !Config.opts.barGlide
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
                                        color: Theme.textMuted
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
                                idleColor: Theme.fill
                                onClicked: panel.resetAnimations()
                            }
                        }
                    }

                    // ----- Quickshell > Performance -----
                    Column {
                        id: pagePerformance

                        width: parent.width
                        spacing: 10
                        visible: panel.page === "performance"

                        // Rows that appear fade in, the ones below glide smoothly after (instant on a page switch,
                        // the whole page glides then)
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: tabIn.running ? 0 : Theme.ctlMed
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveSmooth
                            }
                        }
                        // With "Subpixel glide" every row glides between pixels: drawn as an image while moving
                        // (text sharp), without it again at the target
                        move: Transition {
                            SequentialAnimation {
                                PropertyAction {
                                    property: "layer.smooth"
                                    value: true
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: Config.opts.barGlide && !tabIn.running
                                }
                                NumberAnimation {
                                    property: "y"
                                    duration: tabIn.running ? 0 : Theme.ctlMed
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveSmooth
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: false
                                }
                            }
                        }

                        // Vulkan or OpenGL. Can only be chosen at startup: switching saves the choice and
                        // restarts Quickshell (~/.local/bin/qs-restart, which reads it via ~/.config/quickshell/render-env.sh).
                        SettingRow {
                            readonly property string running: Quickshell.env("QSG_RHI_BACKEND") === "opengl" ? "OpenGL" : "Vulkan"

                            width: parent.width
                            label: "Renderer"
                            description: "OpenGL is the default. Switching restarts the shell · running: " + running
                            controlWidth: 220

                            Segmented {
                                width: parent.width
                                options: [
                                    {
                                        value: "opengl",
                                        label: "OpenGL"
                                    },
                                    {
                                        value: "vulkan",
                                        label: "Vulkan"
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
                            label: "Smooth text"
                            description: "Text and icons glide without pixel steps while moving (glyphs look a bit softer)"

                            SwitchCtl {
                                checked: Config.opts.smoothText
                                onToggled: Config.opts.smoothText = !Config.opts.smoothText
                            }
                        }
                    }

                    // ----- Quickshell > Commands -----
                    Column {
                        id: pageCommands

                        width: parent.width
                        spacing: 10
                        visible: panel.page === "commands"

                        // Rows that appear fade in, the ones below glide smoothly after (instant on a page switch,
                        // the whole page glides then)
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: tabIn.running ? 0 : Theme.ctlMed
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveSmooth
                            }
                        }
                        // With "Subpixel glide" every row glides between pixels: drawn as an image while moving
                        // (text sharp), without it again at the target
                        move: Transition {
                            SequentialAnimation {
                                PropertyAction {
                                    property: "layer.smooth"
                                    value: true
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: Config.opts.barGlide && !tabIn.running
                                }
                                NumberAnimation {
                                    property: "y"
                                    duration: tabIn.running ? 0 : Theme.ctlMed
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveSmooth
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: false
                                }
                            }
                        }

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

                    // ----- Hyprland > Windows -----
                    Column {
                        id: pageHyprWindows

                        width: parent.width
                        spacing: 10
                        visible: panel.page === "hyprWindows"

                        // Rows that appear fade in, the ones below glide smoothly after (instant on a page switch,
                        // the whole page glides then)
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: tabIn.running ? 0 : Theme.ctlMed
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveSmooth
                            }
                        }
                        // With "Subpixel glide" every row glides between pixels: drawn as an image while moving
                        // (text sharp), without it again at the target
                        move: Transition {
                            SequentialAnimation {
                                PropertyAction {
                                    property: "layer.smooth"
                                    value: true
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: Config.opts.barGlide && !tabIn.running
                                }
                                NumberAnimation {
                                    property: "y"
                                    duration: tabIn.running ? 0 : Theme.ctlMed
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveSmooth
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: false
                                }
                            }
                        }

                        // Note at the top, counts as a section title (no separator line below)
                        Txt {
                            readonly property bool isHeader: true

                            width: parent.width
                            text: "Applied live on top of hyprland.lua, the file itself stays unchanged. Reset = back to the value from hyprland.lua (Hyprland reloads once)"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            wrapMode: Text.Wrap
                            bottomPadding: 6
                        }

                        SettingRow {
                            width: parent.width
                            label: "Corner rounding"
                            description: "Rounded window corners (decoration:rounding). A single window with Dynamic Hyprland integration stays square" + (Config.opts.hyprRounding >= 0 ? " · set here" : " · from hyprland.lua")
                            controlWidth: 400

                            Row {
                                spacing: 10

                                RangeControl {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - reset_hyprRounding.width - 10
                                    from: 0
                                    to: 20
                                    value: panel.hyprVal("hyprRounding", "decoration:rounding", 10)
                                    suffix: " px"
                                    onEdited: v => {
                                        Config.opts.hyprRounding = v;
                                    }
                                }

                                IconButton {
                                    id: reset_hyprRounding

                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: String.fromCodePoint(0xF0450)
                                    iconSize: Theme.fontSm
                                    label: "Reset"
                                    idleColor: Theme.fill
                                    enabled: Config.opts.hyprRounding >= 0
                                    opacity: enabled ? 1 : 0.35
                                    onClicked: panel.hyprReset("hyprRounding")
                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.ctlFast
                                        }
                                    }
                                }
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Shadows"
                            description: "Drop shadows under windows (decoration:shadow:enabled)" + (Config.opts.hyprShadow >= 0 ? " · set here" : " · from hyprland.lua")
                            controlWidth: 400

                            Row {
                                anchors.right: parent.right
                                spacing: 14

                                Toggle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: panel.hyprVal("hyprShadow", "decoration:shadow:enabled", 0) > 0
                                    onToggled: Config.opts.hyprShadow = panel.hyprVal("hyprShadow", "decoration:shadow:enabled", 0) > 0 ? 0 : 1
                                }

                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: String.fromCodePoint(0xF0450)
                                    iconSize: Theme.fontSm
                                    label: "Reset"
                                    idleColor: Theme.fill
                                    enabled: Config.opts.hyprShadow >= 0
                                    opacity: enabled ? 1 : 0.35
                                    onClicked: panel.hyprReset("hyprShadow")
                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.ctlFast
                                        }
                                    }
                                }
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Blur size"
                            description: "Blur behind all windows, panels and popups (decoration:blur:size)" + (Config.opts.hyprBlurSize >= 0 ? " · set here" : " · from hyprland.lua")
                            controlWidth: 400

                            Row {
                                spacing: 10

                                RangeControl {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - reset_hyprBlurSize.width - 10
                                    from: 1
                                    to: 30
                                    value: panel.hyprVal("hyprBlurSize", "decoration:blur:size", 10)
                                    suffix: ""
                                    onEdited: v => {
                                        Config.opts.hyprBlurSize = v;
                                        Config.opts.glassBlurSize = v;
                                    }
                                }

                                IconButton {
                                    id: reset_hyprBlurSize

                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: String.fromCodePoint(0xF0450)
                                    iconSize: Theme.fontSm
                                    label: "Reset"
                                    idleColor: Theme.fill
                                    enabled: Config.opts.hyprBlurSize >= 0
                                    opacity: enabled ? 1 : 0.35
                                    onClicked: panel.hyprReset("hyprBlurSize")
                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.ctlFast
                                        }
                                    }
                                }
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Blur passes"
                            description: "decoration:blur:passes, more passes = softer blur but more GPU work" + (Config.opts.hyprBlurPasses >= 0 ? " · set here" : " · from hyprland.lua")
                            controlWidth: 400

                            Row {
                                spacing: 10

                                RangeControl {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - reset_hyprBlurPasses.width - 10
                                    from: 1
                                    to: 8
                                    value: panel.hyprVal("hyprBlurPasses", "decoration:blur:passes", 3)
                                    suffix: ""
                                    onEdited: v => {
                                        Config.opts.hyprBlurPasses = v;
                                        Config.opts.glassBlurPasses = v;
                                    }
                                }

                                IconButton {
                                    id: reset_hyprBlurPasses

                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: String.fromCodePoint(0xF0450)
                                    iconSize: Theme.fontSm
                                    label: "Reset"
                                    idleColor: Theme.fill
                                    enabled: Config.opts.hyprBlurPasses >= 0
                                    opacity: enabled ? 1 : 0.35
                                    onClicked: panel.hyprReset("hyprBlurPasses")
                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.ctlFast
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ----- Hyprland > Layout & rendering -----
                    Column {
                        id: pageHyprLayout

                        width: parent.width
                        spacing: 10
                        visible: panel.page === "hyprLayout"

                        // Rows that appear fade in, the ones below glide smoothly after (instant on a page switch,
                        // the whole page glides then)
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: tabIn.running ? 0 : Theme.ctlMed
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveSmooth
                            }
                        }
                        // With "Subpixel glide" every row glides between pixels: drawn as an image while moving
                        // (text sharp), without it again at the target
                        move: Transition {
                            SequentialAnimation {
                                PropertyAction {
                                    property: "layer.smooth"
                                    value: true
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: Config.opts.barGlide && !tabIn.running
                                }
                                NumberAnimation {
                                    property: "y"
                                    duration: tabIn.running ? 0 : Theme.ctlMed
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveSmooth
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: false
                                }
                            }
                        }

                        // On: Hyprland with smart gaps, smart borders and a square single window, top 19 px.
                        // Off: all of that gone (the bar handles 1 window), top 10 px.
                        // hyprland.lua reads "hyprDynamic" when it loads, so "hyprctl reload" after switching.
                        SettingRow {
                            width: parent.width
                            label: "Dynamic Hyprland integration"
                            description: Config.opts.hyprDynamic ? "Smart gaps and borders: a single window fills the screen without gaps, border and rounding, the docked bar sits right on it. Top gap 19 px for the floating bar" : "No smart gaps, smart borders or square single windows, the bar handles 1 window alone. Top gap 10 px"

                            SwitchCtl {
                                checked: Config.opts.hyprDynamic
                                onToggled: {
                                    Config.opts.hyprDynamic = !Config.opts.hyprDynamic;
                                    // Wait briefly until the setting is saved, then reload Hyprland
                                    Quickshell.execDetached(["sh", "-c", "sleep 0.5; hyprctl reload >/dev/null 2>&1"]);
                                }
                            }
                        }

                        // Direct scanout: fullscreen apps go straight to the screen, skipping the compositor (less latency).
                        // render:direct_scanout 0 = off, 1 = on, 2 = auto (only apps that report themselves as a game)
                        SettingRow {
                            width: parent.width
                            label: "Direct scanout"
                            description: "Fullscreen apps go straight to the screen, skipping the compositor (less latency). Games: only apps that report themselves as a game" + (Config.opts.hyprDirectScanout >= 0 ? " · set here" : " · from hyprland.lua")
                            controlWidth: 400

                            Row {
                                anchors.right: parent.right
                                spacing: 10

                                Segmented {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - reset_hyprDirectScanout.width - 10
                                    options: [
                                        {
                                            value: "0",
                                            label: "Off"
                                        },
                                        {
                                            value: "2",
                                            label: "Games"
                                        },
                                        {
                                            value: "1",
                                            label: "On"
                                        }
                                    ]
                                    value: String(panel.hyprVal("hyprDirectScanout", "render:direct_scanout", 0))
                                    onPicked: v => Config.opts.hyprDirectScanout = Number(v)
                                }

                                IconButton {
                                    id: reset_hyprDirectScanout

                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: String.fromCodePoint(0xF0450)
                                    iconSize: Theme.fontSm
                                    label: "Reset"
                                    idleColor: Theme.fill
                                    enabled: Config.opts.hyprDirectScanout >= 0
                                    opacity: enabled ? 1 : 0.35
                                    onClicked: panel.hyprReset("hyprDirectScanout")
                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.ctlFast
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ----- Apps > Opacity -----
                    Column {
                        id: pageAppsOpacity

                        width: parent.width
                        spacing: 10
                        visible: panel.page === "appsOpacity"

                        // Rows that appear fade in, the ones below glide smoothly after (instant on a page switch,
                        // the whole page glides then)
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: tabIn.running ? 0 : Theme.ctlMed
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveSmooth
                            }
                        }
                        // With "Subpixel glide" every row glides between pixels: drawn as an image while moving
                        // (text sharp), without it again at the target
                        move: Transition {
                            SequentialAnimation {
                                PropertyAction {
                                    property: "layer.smooth"
                                    value: true
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: Config.opts.barGlide && !tabIn.running
                                }
                                NumberAnimation {
                                    property: "y"
                                    duration: tabIn.running ? 0 : Theme.ctlMed
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveSmooth
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: false
                                }
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "All apps"
                            description: "Sets every app below to the same value. 100 % = solid"
                            controlWidth: 400

                            Row {
                                anchors.right: parent.right
                                spacing: 14

                                Item {
                                    width: 38
                                    height: 1
                                }

                                RangeControl {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - 38 - 14
                                    from: 25
                                    to: 100
                                    stepSize: 5
                                    value: Config.opts.appOpacity
                                    suffix: " %"
                                    onEdited: v => panel.setAllApps(v)
                                }
                            }
                        }

                        // Section title
                        Txt {
                            readonly property bool isHeader: true

                            width: parent.width
                            topPadding: 18
                            text: "Apps"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.uiWeightStrong
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.8
                        }

                        SettingRow {
                            width: parent.width
                            appIcon: panel.appIconFor(["kitty"])
                            label: "kitty"
                            description: "Terminal background, text stays solid. Live"
                            controlWidth: 400

                            Row {
                                anchors.right: parent.right
                                spacing: 14

                                Item {
                                    width: 38
                                    height: 1
                                }

                                RangeControl {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - 38 - 14
                                    enabled: true
                                    opacity: enabled ? 1 : 0.4
                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.ctlFast
                                        }
                                    }
                                    from: 25
                                    to: 100
                                    stepSize: 5
                                    value: panel.appOp("appOpacityKitty")
                                    suffix: " %"
                                    onEdited: v => panel.setApp("appOpacityKitty", v)
                                }
                            }
                        }

                        SettingRow {
                            width: parent.width
                            appIcon: panel.appIconFor(["io.github.lullabyx.sone", "sone", "tidal"])
                            label: "Tidal (SONE)"
                            description: "The whole window fades, text too (Hyprland rule). Live"
                            controlWidth: 400

                            Row {
                                anchors.right: parent.right
                                spacing: 14

                                Item {
                                    width: 38
                                    height: 1
                                }

                                RangeControl {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - 38 - 14
                                    enabled: true
                                    opacity: enabled ? 1 : 0.4
                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.ctlFast
                                        }
                                    }
                                    from: 25
                                    to: 100
                                    stepSize: 5
                                    value: panel.appOp("appOpacityTidal")
                                    suffix: " %"
                                    onEdited: v => panel.setApp("appOpacityTidal", v)
                                }
                            }
                        }

                        SettingRow {
                            width: parent.width
                            appIcon: panel.appIconFor(["org.gnome.Nautilus", "nautilus"])
                            label: "Files (Nautilus)"
                            description: "Off = as before. Next window (Nautilus restarts in the background if no window is open)"
                            controlWidth: 400

                            Row {
                                anchors.right: parent.right
                                spacing: 14

                                Toggle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: panel.appOn("appGlassNautilus")
                                    onToggled: panel.toggleApp("appGlassNautilus")
                                }

                                RangeControl {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - 38 - 14
                                    enabled: panel.appOn("appGlassNautilus")
                                    opacity: enabled ? 1 : 0.4
                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.ctlFast
                                        }
                                    }
                                    from: 25
                                    to: 100
                                    stepSize: 5
                                    value: panel.appOp("appOpacityNautilus")
                                    suffix: " %"
                                    onEdited: v => panel.setApp("appOpacityNautilus", v)
                                }
                            }
                        }

                        SettingRow {
                            width: parent.width
                            appIcon: panel.appIconFor(["document-open", "folder-open", "folder"])
                            label: "File dialogs"
                            description: "Open / Save dialogs, Thunar and other GTK3 apps. Off = as before. Next dialog"
                            controlWidth: 400

                            Row {
                                anchors.right: parent.right
                                spacing: 14

                                Toggle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: panel.appOn("appGlassDialogs")
                                    onToggled: panel.toggleApp("appGlassDialogs")
                                }

                                RangeControl {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - 38 - 14
                                    enabled: panel.appOn("appGlassDialogs")
                                    opacity: enabled ? 1 : 0.4
                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.ctlFast
                                        }
                                    }
                                    from: 25
                                    to: 100
                                    stepSize: 5
                                    value: panel.appOp("appOpacityDialogs")
                                    suffix: " %"
                                    onEdited: v => panel.setApp("appOpacityDialogs", v)
                                }
                            }
                        }

                        SettingRow {
                            width: parent.width
                            appIcon: panel.appIconFor(["vesktop", "dev.vencord.Vesktop", "discord"])
                            label: "Vesktop"
                            description: "Off = as before. Live, menus stay a bit denser"
                            controlWidth: 400

                            Row {
                                anchors.right: parent.right
                                spacing: 14

                                Toggle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: panel.appOn("appGlassVesktop")
                                    onToggled: panel.toggleApp("appGlassVesktop")
                                }

                                RangeControl {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - 38 - 14
                                    enabled: panel.appOn("appGlassVesktop")
                                    opacity: enabled ? 1 : 0.4
                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.ctlFast
                                        }
                                    }
                                    from: 25
                                    to: 100
                                    stepSize: 5
                                    value: panel.appOp("appOpacityVesktop")
                                    suffix: " %"
                                    onEdited: v => panel.setApp("appOpacityVesktop", v)
                                }
                            }
                        }

                        SettingRow {
                            width: parent.width
                            appIcon: panel.appIconFor(["firefox", "org.mozilla.firefox"])
                            label: "Firefox"
                            description: "New tab and empty pages, the toolbars too. Off = as before. After a Firefox restart"
                            controlWidth: 400

                            Row {
                                anchors.right: parent.right
                                spacing: 14

                                Toggle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: panel.appOn("appGlassFirefox")
                                    onToggled: panel.toggleApp("appGlassFirefox")
                                }

                                RangeControl {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - 38 - 14
                                    enabled: panel.appOn("appGlassFirefox")
                                    opacity: enabled ? 1 : 0.4
                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.ctlFast
                                        }
                                    }
                                    from: 25
                                    to: 100
                                    stepSize: 5
                                    value: panel.appOp("appOpacityFirefox")
                                    suffix: " %"
                                    onEdited: v => panel.setApp("appOpacityFirefox", v)
                                }
                            }
                        }
                    }

                    // ----- Apps > kitty -----
                    Column {
                        id: pageAppsKitty

                        width: parent.width
                        spacing: 10
                        visible: panel.page === "appsKitty"

                        // Rows that appear fade in, the ones below glide smoothly after (instant on a page switch,
                        // the whole page glides then)
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: tabIn.running ? 0 : Theme.ctlMed
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveSmooth
                            }
                        }
                        // With "Subpixel glide" every row glides between pixels: drawn as an image while moving
                        // (text sharp), without it again at the target
                        move: Transition {
                            SequentialAnimation {
                                PropertyAction {
                                    property: "layer.smooth"
                                    value: true
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: Config.opts.barGlide && !tabIn.running
                                }
                                NumberAnimation {
                                    property: "y"
                                    duration: tabIn.running ? 0 : Theme.ctlMed
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveSmooth
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: false
                                }
                            }
                        }

                        // kitty starts through ~/.local/bin/kitty-shell/zsh (kitty.conf: shell ...), which reads the value
                        // for every new window. So it applies right away to the next kitty, no restart needed.
                        SettingRow {
                            width: parent.width
                            label: "Fastfetch in kitty"
                            description: "Show fastfetch every time a new kitty window opens"

                            SwitchCtl {
                                checked: Config.opts.kittyFastfetch
                                onToggled: Config.opts.kittyFastfetch = !Config.opts.kittyFastfetch
                            }
                        }

                        // Images for fastfetch: 4 slots, one per new kitty in this order
                        // (~/.local/bin/fastfetch-logo reads fastfetchLogo1..4). Clicking a slot opens the picker below it
                        // (images from ~/.config/fastfetch/logos and ~/Pictures), right-click clears it.
                        Column {
                            id: ffLogos

                            // Slot currently being picked for (0..3), -1 = picker closed
                            property int picking: -1
                            readonly property var slots: [Config.opts.fastfetchLogo1, Config.opts.fastfetchLogo2, Config.opts.fastfetchLogo3, Config.opts.fastfetchLogo4]
                            readonly property string logosDir: Quickshell.env("HOME") + "/.config/fastfetch/logos"
                            readonly property string picturesDir: Quickshell.env("HOME") + "/Pictures"
                            // All selectable images, first the logos folder, then ~/Pictures
                            readonly property var choices: {
                                const l = [];
                                for (let i = 0; i < ffLogosModel.count; i++)
                                    l.push(ffLogosModel.get(i, "filePath"));
                                for (let i = 0; i < ffPicturesModel.count; i++)
                                    l.push(ffPicturesModel.get(i, "filePath"));
                                return l;
                            }

                            function setSlot(i, path) {
                                if (i === 0)
                                    Config.opts.fastfetchLogo1 = path;
                                else if (i === 1)
                                    Config.opts.fastfetchLogo2 = path;
                                else if (i === 2)
                                    Config.opts.fastfetchLogo3 = path;
                                else if (i === 3)
                                    Config.opts.fastfetchLogo4 = path;
                                // Prepare it for fastfetch right away (huge images take a few seconds),
                                // so the next kitty doesn't have to wait for it
                                if (path !== "")
                                    Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/fastfetch-logo", "prepare", path]);
                            }

                            // Path as a URL (spaces, # etc. in the file name)
                            function url(path) {
                                return path !== "" ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "";
                            }

                            width: parent.width
                            spacing: 10

                            FolderListModel {
                                id: ffLogosModel

                                folder: "file://" + ffLogos.logosDir
                                nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
                                caseSensitive: false
                                showDirs: false
                                sortField: FolderListModel.Name
                            }

                            FolderListModel {
                                id: ffPicturesModel

                                folder: "file://" + ffLogos.picturesDir
                                nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
                                caseSensitive: false
                                showDirs: false
                                sortField: FolderListModel.Name
                            }

                            SettingRow {
                                width: parent.width
                                label: "Fastfetch images"
                                description: "One per new kitty window, in this order. Click a slot to pick, right-click to clear. All empty = every image in ~/.config/fastfetch/logos"
                                controlWidth: 4 * 60 + 3 * 8

                                Row {
                                    spacing: 8

                                    Repeater {
                                        model: 4

                                        delegate: Item {
                                            id: ffSlot

                                            required property int index
                                            readonly property string path: ffLogos.slots[index] || ""
                                            readonly property bool picking: ffLogos.picking === index

                                            width: 60
                                            height: 60

                                            ClippingRectangle {
                                                anchors.fill: parent
                                                radius: Theme.radius
                                                color: Theme.fillStrong

                                                Image {
                                                    anchors.fill: parent
                                                    anchors.margins: 4
                                                    source: ffLogos.url(ffSlot.path)
                                                    sourceSize.width: 112
                                                    sourceSize.height: 112
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                    smooth: true
                                                }

                                                Glyph {
                                                    anchors.centerIn: parent
                                                    visible: ffSlot.path === ""
                                                    text: Icons.plus
                                                    color: Theme.textMuted
                                                }
                                            }

                                            Txt {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.leftMargin: 5
                                                anchors.topMargin: 2
                                                text: String(ffSlot.index + 1)
                                                color: Theme.textDim
                                                font.pixelSize: Theme.fontSm - 1
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: Theme.radius
                                                color: "transparent"
                                                border.width: ffSlot.picking ? 2 : 1
                                                border.color: ffSlot.picking ? Theme.accent : (ffSlotArea.containsMouse ? Theme.textMuted : Theme.hairline)

                                                Behavior on border.color {
                                                    CAnim {}
                                                }
                                            }

                                            MouseArea {
                                                id: ffSlotArea

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                onClicked: mouse => {
                                                    if (mouse.button === Qt.RightButton) {
                                                        ffLogos.setSlot(ffSlot.index, "");
                                                        return;
                                                    }
                                                    ffLogos.picking = ffSlot.picking ? -1 : ffSlot.index;
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Picker for the clicked slot
                            Rectangle {
                                width: parent.width
                                visible: ffLogos.picking >= 0
                                height: visible ? ffPick.implicitHeight + 24 : 0
                                radius: Theme.radius
                                color: Theme.fill

                                Column {
                                    id: ffPick

                                    x: 12
                                    y: 12
                                    width: parent.width - 24
                                    spacing: 10

                                    Item {
                                        width: parent.width
                                        height: 28

                                        Txt {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Image " + (ffLogos.picking + 1) + " · from ~/.config/fastfetch/logos and ~/Pictures"
                                            color: Theme.textMuted
                                            font.pixelSize: Theme.fontSm
                                        }

                                        IconButton {
                                            anchors.right: ffPickClose.left
                                            anchors.rightMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            size: 28
                                            icon: Icons.image
                                            idleColor: Theme.fill
                                            // Open the folder in the file manager to put images into it
                                            onClicked: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && exec xdg-open \"$1\"", "sh", ffLogos.logosDir])
                                        }

                                        IconButton {
                                            id: ffPickClose

                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            size: 28
                                            icon: Icons.close
                                            idleColor: Theme.fill
                                            onClicked: ffLogos.picking = -1
                                        }
                                    }

                                    Flow {
                                        width: parent.width
                                        spacing: 8

                                        Repeater {
                                            model: ffLogos.picking >= 0 ? ffLogos.choices : []

                                            delegate: Item {
                                                id: ffChoice

                                                required property string modelData
                                                readonly property bool chosen: ffLogos.slots[ffLogos.picking] === modelData

                                                width: 72
                                                height: 72

                                                ClippingRectangle {
                                                    anchors.fill: parent
                                                    radius: Theme.radius
                                                    color: Theme.fillStrong

                                                    Image {
                                                        anchors.fill: parent
                                                        anchors.margins: 4
                                                        source: ffLogos.url(ffChoice.modelData)
                                                        sourceSize.width: 136
                                                        sourceSize.height: 136
                                                        fillMode: Image.PreserveAspectFit
                                                        asynchronous: true
                                                        smooth: true
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: Theme.radius
                                                    color: "transparent"
                                                    border.width: ffChoice.chosen ? 2 : 1
                                                    border.color: ffChoice.chosen ? Theme.accent : (ffChoiceArea.containsMouse ? Theme.textMuted : Theme.hairline)

                                                    Behavior on border.color {
                                                        CAnim {}
                                                    }
                                                }

                                                MouseArea {
                                                    id: ffChoiceArea

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        ffLogos.setSlot(ffLogos.picking, ffChoice.modelData);
                                                        ffLogos.picking = -1;
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Txt {
                                        width: parent.width
                                        visible: ffLogos.choices.length === 0
                                        text: "No images yet. Put some into ~/.config/fastfetch/logos or ~/Pictures."
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.fontSm
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }

                    // ----- System > Profile -----
                    // Picture and name big at the top, below them your own display name and the picture picker. The picture is the
                    // account picture (AccountsService) that KDE Plasma, SDDM, hyprlock and the shell share
                    // (services/User.qml). The name only applies to the shell and hyprlock.
                    Column {
                        id: pageProfile

                        width: parent.width
                        spacing: 10
                        visible: panel.page === "profile"

                        // Rows that appear fade in, the ones below glide smoothly after (instant on a page switch,
                        // the whole page glides then)
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: tabIn.running ? 0 : Theme.ctlMed
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveSmooth
                            }
                        }
                        // With "Subpixel glide" every row glides between pixels: drawn as an image while moving
                        // (text sharp), without it again at the target
                        move: Transition {
                            SequentialAnimation {
                                PropertyAction {
                                    property: "layer.smooth"
                                    value: true
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: Config.opts.barGlide && !tabIn.running
                                }
                                NumberAnimation {
                                    property: "y"
                                    duration: tabIn.running ? 0 : Theme.ctlMed
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveSmooth
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: false
                                }
                            }
                        }

                        // Big card: picture, name, login@host
                        Rectangle {
                            width: parent.width
                            height: 136
                            radius: Theme.radiusLg
                            color: Theme.fill

                            Avatar {
                                id: heroAvatar

                                x: 20
                                anchors.verticalCenter: parent.verticalCenter
                                size: 96
                                radius: Theme.radiusLg
                            }

                            Column {
                                anchors.left: heroAvatar.right
                                anchors.leftMargin: 22
                                anchors.right: parent.right
                                anchors.rightMargin: 20
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Txt {
                                    width: parent.width
                                    text: User.name
                                    font.pixelSize: Theme.fontLg + 7
                                    font.weight: Theme.uiWeightStrong
                                    elide: Text.ElideRight
                                }

                                Txt {
                                    width: parent.width
                                    text: User.login + (User.host !== "" ? "@" + User.host : "")
                                    color: Theme.textDim
                                    elide: Text.ElideRight
                                }

                                Txt {
                                    width: parent.width
                                    topPadding: 4
                                    text: "Picture shared with KDE Plasma, SDDM and the lock screen"
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontSm
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // Section title
                        Txt {
                            readonly property bool isHeader: true

                            width: parent.width
                            topPadding: 18
                            text: "Account"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.uiWeightStrong
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.8
                        }

                        // Own name only for the shell and hyprlock (empty = account name)
                        SettingRow {
                            width: parent.width
                            label: "Display name"
                            description: "Shown in the control center, in the corner of these settings and on the lock screen. Empty = your account name (" + User.systemName + ")"
                            controlWidth: 400

                            Row {
                                anchors.right: parent.right
                                spacing: 10

                                InputField {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - reset_userName.width - 10
                                    text: Config.opts.userName
                                    placeholder: User.systemName
                                    onCommitted: v => Config.opts.userName = v.trim()
                                }

                                IconButton {
                                    id: reset_userName

                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: String.fromCodePoint(0xF0450)
                                    iconSize: Theme.fontSm
                                    label: "Reset"
                                    idleColor: Theme.fill
                                    enabled: Config.opts.userName !== ""
                                    opacity: enabled ? 1 : 0.35
                                    onClicked: Config.opts.userName = ""
                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.ctlFast
                                        }
                                    }
                                }
                            }
                        }

                        // Account picture: picker below, here status/errors and getting the previous picture back
                        SettingRow {
                            width: parent.width
                            label: "Profile picture"
                            description: User.error !== "" ? "Could not set it: " + User.error : (User.busy ? "Setting the picture …" : "Your account picture, also used by KDE Plasma, SDDM and the lock screen. Click a picture below to crop and use it")
                            controlWidth: 220

                            TextButton {
                                anchors.right: parent.right
                                icon: Icons.restart
                                text: "Restore original"
                                enabled: User.hasOriginal && Config.opts.userPictureFrom !== "" && !User.busy
                                onClicked: User.restorePicture()
                            }
                        }

                        // Section title
                        Txt {
                            readonly property bool isHeader: true

                            width: parent.width
                            topPadding: 18
                            text: "Choose a picture"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.uiWeightStrong
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.8
                        }

                        // Folders, current path, one level up
                        Item {
                            width: parent.width
                            height: 34

                            Segmented {
                                id: picPlaces

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 440
                                options: [
                                    {
                                        value: "pictures",
                                        label: "Pictures"
                                    },
                                    {
                                        value: "downloads",
                                        label: "Downloads"
                                    },
                                    {
                                        value: "wallpapers",
                                        label: "Wallpapers"
                                    },
                                    {
                                        value: "home",
                                        label: "Home"
                                    }
                                ]
                                value: panel.picPlace
                                onPicked: v => panel.picPlace = v
                            }

                            IconButton {
                                id: picUpBtn

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                size: 34
                                icon: Icons.arrowUp
                                iconSize: Theme.iconSize - 2
                                idleColor: Theme.fill
                                enabled: panel.picSub !== ""
                                opacity: enabled ? 1 : 0.35
                                onClicked: panel.picUp()
                                Behavior on opacity {
                                    Anim {
                                        duration: Theme.ctlFast
                                    }
                                }
                            }

                            Txt {
                                anchors.left: picPlaces.right
                                anchors.leftMargin: 14
                                anchors.right: picUpBtn.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                text: panel.picDir.replace(Quickshell.env("HOME"), "~")
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSm
                                elide: Text.ElideMiddle
                            }
                        }

                        // Folders and pictures as tiles. When the folder changes the grid fades out and in again.
                        Grid {
                            id: picGrid

                            readonly property real cellW: Math.floor((width - spacing * (columns - 1)) / columns)

                            width: parent.width
                            columns: Math.max(4, Math.floor((width + spacing) / 150))
                            spacing: 10
                            opacity: panel.picReady ? 1 : 0

                            Behavior on opacity {
                                Anim {
                                    duration: Theme.ctlMed
                                }
                            }

                            Repeater {
                                model: panel.picLive ? panel.picItems : []

                                delegate: Item {
                                    id: picTile

                                    required property var modelData
                                    readonly property bool isDir: picTile.modelData.dir
                                    readonly property bool current: !picTile.isDir && picTile.modelData.path === Config.opts.userPictureFrom && User.faceStamp === Config.opts.userPictureStamp
                                    readonly property bool busy: !picTile.isDir && picTile.modelData.path === User.busyPath

                                    function load() {
                                        picImg.source = "";
                                        picImg.source = "file://" + picTile.modelData.thumb;
                                    }

                                    width: picGrid.cellW
                                    height: picGrid.cellW
                                    Component.onCompleted: {
                                        if (!picTile.isDir && Walls.isReady(picTile.modelData.thumb))
                                            picTile.load();
                                    }

                                    Connections {
                                        target: Walls
                                        enabled: !picTile.isDir

                                        function onThumbReady(t) {
                                            if (t === picTile.modelData.thumb)
                                                picTile.load();
                                        }
                                    }

                                    ClippingRectangle {
                                        anchors.fill: parent
                                        radius: Theme.radius
                                        color: picTile.isDir ? (picArea.containsMouse ? Theme.fillStrong : Theme.fill) : Theme.fillStrong

                                        Behavior on color {
                                            CAnim {}
                                        }

                                        // Folder: icon and name
                                        Glyph {
                                            visible: picTile.isDir
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.verticalCenterOffset: -12
                                            text: Icons.folder
                                            color: picArea.containsMouse ? Theme.fg : Theme.textDim
                                            font.pixelSize: 34

                                            Behavior on color {
                                                CAnim {}
                                            }
                                        }

                                        Txt {
                                            visible: picTile.isDir
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            anchors.right: parent.right
                                            anchors.rightMargin: 10
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 16
                                            horizontalAlignment: Text.AlignHCenter
                                            text: picTile.modelData.name
                                            color: Theme.textDim
                                            font.pixelSize: Theme.fontSm
                                            elide: Text.ElideMiddle
                                        }

                                        Image {
                                            id: picImg

                                            visible: !picTile.isDir
                                            width: parent.width
                                            height: parent.height
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: false
                                            scale: picArea.containsMouse ? 1.06 : 1
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
                                            visible: !picTile.isDir
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 46
                                            opacity: picArea.containsMouse ? 1 : 0
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
                                                text: picTile.modelData.name.replace(/\.[^.]+$/, "")
                                                font.pixelSize: Theme.fontSm
                                                elide: Text.ElideRight
                                            }
                                        }

                                        // Being set right now
                                        Rectangle {
                                            anchors.fill: parent
                                            color: Qt.rgba(0, 0, 0, 0.45)
                                            opacity: picTile.busy ? 1 : 0

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
                                                    running: picTile.busy
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
                                        border.width: picTile.current ? 2 : 1
                                        border.color: picTile.current ? Theme.accent : (picArea.containsMouse ? Theme.textMuted : Theme.hairline)

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
                                        scale: picTile.current ? 1 : 0.5
                                        opacity: picTile.current ? 1 : 0

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
                                        id: picArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (picTile.isDir)
                                                panel.picSub = picTile.modelData.path;
                                            else if (!User.busy) {
                                                cropDialog.file = picTile.modelData.path;
                                                cropDialog.open = true;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Txt {
                            readonly property string where: panel.picDir.replace(Quickshell.env("HOME"), "~")

                            width: parent.width
                            text: !panel.picReady ? "Reading " + where + " …" : (panel.picTotal === 0 ? "No images in " + where : (panel.picTotal > panel.picMax ? "The " + panel.picMax + " newest of " + panel.picTotal + " images in " + where : panel.picTotal + (panel.picTotal === 1 ? " image" : " images") + " in " + where))
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: 4
                            bottomPadding: 8
                        }
                    }

                    // ----- System > Wallpaper -----
                    // The current image large at the top, below it search, sorting, random and all images from the
                    // waypaper folder as tiles. A click sets the image (waypaper/awww, see services/Walls.qml).
                    // Tiles and thumbnails only exist while the tab is open.
                    Column {
                        id: pageWallpaper

                        readonly property bool live: panel.page === "wallpaper" && panel.progress > 0

                        width: parent.width
                        spacing: 12
                        visible: panel.page === "wallpaper"

                        // Rows that appear fade in, the ones below glide smoothly after (instant on a page switch,
                        // the whole page glides then)
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: tabIn.running ? 0 : Theme.ctlMed
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveSmooth
                            }
                        }
                        // With "Subpixel glide" every row glides between pixels: drawn as an image while moving
                        // (text sharp), without it again at the target
                        move: Transition {
                            SequentialAnimation {
                                PropertyAction {
                                    property: "layer.smooth"
                                    value: true
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: Config.opts.barGlide && !tabIn.running
                                }
                                NumberAnimation {
                                    property: "y"
                                    duration: tabIn.running ? 0 : Theme.ctlMed
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveSmooth
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: false
                                }
                            }
                        }

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
                            color: Theme.fill
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
                                    color: Theme.textDim
                                    font.pixelSize: Theme.fontSm - 1
                                    font.letterSpacing: 1.2
                                }

                                Txt {
                                    width: parent.width
                                    text: hero.file !== "" ? Walls.fileName(hero.file) : "No wallpaper set"
                                    font.pixelSize: Theme.fontLg
                                    font.weight: Theme.uiWeightStrong
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
                                idleColor: Theme.fill
                                onClicked: Walls.random()
                            }
                        }

                        Grid {
                            id: wallGrid

                            readonly property real cellW: Math.floor((width - spacing * (columns - 1)) / columns)
                            readonly property string query: wallSearch.input.text.trim().toLowerCase()

                            width: parent.width
                            // Tiles about as big as before (~200 px): the wider window simply fits more per row
                            columns: Math.max(3, Math.floor((width + spacing) / 230))
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
                                        color: Theme.fillStrong

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
                                        border.color: tile.current ? Theme.accent : (tileArea.containsMouse ? Theme.textMuted : Theme.hairline)

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
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: 4
                            bottomPadding: 8
                        }
                    }

                    // ----- System > Gaming -----
                    Column {
                        id: pageGaming

                        width: parent.width
                        spacing: 10
                        visible: panel.page === "gaming"

                        // Rows that appear fade in, the ones below glide smoothly after (instant on a page switch,
                        // the whole page glides then)
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: tabIn.running ? 0 : Theme.ctlMed
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveSmooth
                            }
                        }
                        // With "Subpixel glide" every row glides between pixels: drawn as an image while moving
                        // (text sharp), without it again at the target
                        move: Transition {
                            SequentialAnimation {
                                PropertyAction {
                                    property: "layer.smooth"
                                    value: true
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: Config.opts.barGlide && !tabIn.running
                                }
                                NumberAnimation {
                                    property: "y"
                                    duration: tabIn.running ? 0 : Theme.ctlMed
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveSmooth
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: false
                                }
                            }
                        }

                        // Section title
                        Txt {
                            readonly property bool isHeader: true

                            width: parent.width
                            topPadding: 0
                            text: "Display"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.uiWeightStrong
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.8
                        }

                        // Variable refresh rate (G-Sync / FreeSync): misc:vrr, laid over hyprland.lua at runtime with hyprctl eval
                        // (services/Hypr.qml), hyprland.lua stays unchanged. Reset = the value from hyprland.lua
                        // again (Hyprland reloads for that). Window rules with no_vrr still apply.
                        SettingRow {
                            width: parent.width
                            label: "Variable refresh rate"
                            description: panel.vrrText(panel.hyprVal("hyprVrr", "misc:vrr", 2)) + (Config.opts.hyprVrr >= 0 ? " · set here" : " · from hyprland.lua")
                            controlWidth: 440

                            Row {
                                anchors.right: parent.right
                                spacing: 10

                                Segmented {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 440 - reset_hyprVrr.width - 10
                                    options: [
                                        {
                                            value: "0",
                                            label: "Off"
                                        },
                                        {
                                            value: "1",
                                            label: "Always"
                                        },
                                        {
                                            value: "2",
                                            label: "Fullscreen"
                                        },
                                        {
                                            value: "3",
                                            label: "Games"
                                        }
                                    ]
                                    value: String(panel.hyprVal("hyprVrr", "misc:vrr", 2))
                                    onPicked: v => Config.opts.hyprVrr = Number(v)
                                }

                                IconButton {
                                    id: reset_hyprVrr

                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: String.fromCodePoint(0xF0450)
                                    iconSize: Theme.fontSm
                                    label: "Reset"
                                    idleColor: Theme.fill
                                    enabled: Config.opts.hyprVrr >= 0
                                    opacity: enabled ? 1 : 0.35
                                    onClicked: panel.hyprReset("hyprVrr")
                                    Behavior on opacity {
                                        Anim {
                                            duration: Theme.ctlFast
                                        }
                                    }
                                }
                            }
                        }

                        // Section title
                        Txt {
                            readonly property bool isHeader: true

                            width: parent.width
                            topPadding: 18
                            text: "MangoHud"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.uiWeightStrong
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.8
                        }

                        // Which file: global (MangoHud.conf) or a game config (services/MangoHud.qml).
                        // "+" expands the row for a new game config below.
                        SettingRow {
                            width: parent.width
                            label: "Config"
                            description: MangoHud.isGlobal ? "MangoHud.conf, used by every game without its own config. Changes apply right away, running games reload it" : MangoHud.current + ".conf, replaces the global config completely for this game"
                            controlWidth: 400

                            Row {
                                anchors.right: parent.right
                                spacing: 10

                                Choice {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - mhAddBtn.width - 10
                                    options: MangoHud.configs.map(n => ({
                                                value: n,
                                                label: n === "MangoHud" ? "Global" : n
                                            }))
                                    value: MangoHud.current
                                    menuParent: card
                                    scrollArea: flick
                                    active: panel.open && panel.page === "gaming"
                                    onPicked: v => MangoHud.select(v)
                                }

                                IconButton {
                                    id: mhAddBtn

                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    icon: Icons.plus
                                    iconSize: Theme.fontSm
                                    label: "Game"
                                    idleColor: Theme.fill
                                    active: panel.mhAdding
                                    onClicked: {
                                        panel.mhAddError = false;
                                        panel.mhAdding = !panel.mhAdding;
                                        if (panel.mhAdding)
                                            mhNewName.input.forceActiveFocus();
                                    }
                                }
                            }
                        }

                        // New game config: the row fades in, the rows below glide down
                        SettingRow {
                            width: parent.width
                            visible: panel.mhAdding
                            label: "New game config"
                            description: panel.mhAddError ? "Only letters, digits and . _ + - (without .conf)" : "The game's executable name, e.g. cs2. Proton games: wine-<exe name without .exe>. Starts as a copy of the global config"
                            controlWidth: 400

                            Row {
                                anchors.right: parent.right
                                spacing: 10

                                InputField {
                                    id: mhNewName

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 400 - mhCreateBtn.width - 10
                                    placeholder: "Executable name"
                                    // Only Enter creates it (not just leaving the field)
                                    onCommitted: v => {
                                        if (mhNewName.input.activeFocus)
                                            panel.createGameConfig(v);
                                    }
                                }

                                TextButton {
                                    id: mhCreateBtn

                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: Icons.plus
                                    text: "Create"
                                    onClicked: panel.createGameConfig(mhNewName.input.text)
                                }
                            }
                        }

                        // Show the HUD at game start (no_display). Right Shift + F12 toggles it in game.
                        SettingRow {
                            width: parent.width
                            label: "Show HUD at game start"
                            description: MangoHud.envNoDisplay ? "Right Shift + F12 shows or hides it in game. MANGOHUD_CONFIG in /etc/environment also sets no_display, so it starts hidden anyway" : "Off = hidden until you press Right Shift + F12 in game"

                            SwitchCtl {
                                checked: !MangoHud.has("no_display")
                                onToggled: MangoHud.set("no_display", MangoHud.has("no_display") ? null : "")
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Position"
                            controlWidth: 440

                            Segmented {
                                width: parent.width
                                options: [
                                    {
                                        value: "top-left",
                                        label: "Top left"
                                    },
                                    {
                                        value: "top-right",
                                        label: "Top right"
                                    },
                                    {
                                        value: "bottom-left",
                                        label: "Bottom left"
                                    },
                                    {
                                        value: "bottom-right",
                                        label: "Bottom right"
                                    }
                                ]
                                value: MangoHud.value("position", "top-left")
                                onPicked: v => MangoHud.set("position", v)
                            }
                        }

                        // What the HUD shows: one field per element, bright = on. Without its own entry MangoHud's default applies.
                        SettingRow {
                            width: parent.width
                            implicitHeight: Math.max(60, Math.max(textsHeight, mhChips.height) + 26)
                            label: "Shows"
                            description: "Click an item to switch it on or off"
                            controlWidth: 440

                            Flow {
                                id: mhChips

                                width: parent.width
                                spacing: 6

                                Repeater {
                                    model: panel.mhItems

                                    delegate: Rectangle {
                                        id: chip

                                        required property var modelData
                                        readonly property bool on: MangoHud.isOn(chip.modelData.key)

                                        width: chipRow.implicitWidth + 20
                                        height: 30
                                        radius: Theme.radiusSm
                                        color: chip.on ? (chipArea.pressed ? Theme.pressed : Theme.fillStrong) : (chipArea.pressed ? Theme.fill : "transparent")
                                        border.width: 1
                                        border.color: chip.on ? "transparent" : (chipArea.containsMouse ? Theme.textMuted : Theme.hairlineStrong)

                                        Behavior on color {
                                            CAnim {}
                                        }
                                        Behavior on border.color {
                                            CAnim {}
                                        }

                                        Row {
                                            id: chipRow

                                            anchors.centerIn: parent
                                            spacing: 6

                                            // Off: plus, on: checkmark. Both lie on top of each other and crossfade
                                            // (the field keeps its width, the others don't shift)
                                            Item {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: Math.max(chipCheck.implicitWidth, chipPlus.implicitWidth)
                                                height: chipCheck.implicitHeight

                                                Glyph {
                                                    id: chipCheck

                                                    anchors.centerIn: parent
                                                    text: Icons.check
                                                    color: Theme.fg
                                                    font.pixelSize: Theme.fontSm
                                                    opacity: chip.on ? 1 : 0

                                                    Behavior on opacity {
                                                        Anim {
                                                            duration: Theme.ctlFast
                                                        }
                                                    }
                                                }

                                                Glyph {
                                                    id: chipPlus

                                                    anchors.centerIn: parent
                                                    text: Icons.plus
                                                    color: chipArea.containsMouse ? Theme.textDim : Theme.textMuted
                                                    font.pixelSize: Theme.fontSm
                                                    opacity: chip.on ? 0 : 1

                                                    Behavior on opacity {
                                                        Anim {
                                                            duration: Theme.ctlFast
                                                        }
                                                    }
                                                }
                                            }

                                            Txt {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: chip.modelData.label
                                                color: chip.on ? Theme.fg : (chipArea.containsMouse ? Theme.textDim : Theme.textMuted)
                                                font.pixelSize: Theme.fontSm
                                            }
                                        }

                                        MouseArea {
                                            id: chipArea

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: MangoHud.setOn(chip.modelData.key, !chip.on)
                                        }
                                    }
                                }
                            }
                        }

                        // Section title
                        Txt {
                            readonly property bool isHeader: true

                            width: parent.width
                            topPadding: 18
                            text: "Frame rate"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.uiWeightStrong
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.8
                        }

                        // fps_limit (with several values "162,60" the first one counts)
                        SettingRow {
                            width: parent.width
                            label: "FPS limit"
                            description: "0 = no limit. A few below the refresh rate (e.g. 162 at 170 Hz) keeps G-Sync / VRR active. Scroll on the slider for single steps"
                            controlWidth: 400

                            RangeControl {
                                width: parent.width
                                from: 0
                                to: 360
                                value: parseInt(String(MangoHud.value("fps_limit", "0")).split(",")[0]) || 0
                                suffix: " fps"
                                onEdited: v => MangoHud.set("fps_limit", String(Math.round(v)))
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "Limit method"
                            description: "Late: lowest input latency. Early: smoothest frame times"
                            controlWidth: 300

                            Segmented {
                                width: parent.width
                                options: [
                                    {
                                        value: "early",
                                        label: "Early"
                                    },
                                    {
                                        value: "late",
                                        label: "Late"
                                    }
                                ]
                                value: MangoHud.value("fps_limit_method", "late")
                                onPicked: v => MangoHud.set("fps_limit_method", v)
                            }
                        }

                        // vsync (Vulkan): 0 adaptive, 1 off, 2 mailbox, 3 on (FIFO). Without an entry the game decides.
                        SettingRow {
                            width: parent.width
                            label: "Vsync (Vulkan)"
                            description: "App = the game decides. On = FIFO: with G-Sync and the limit below the refresh rate no tearing and low latency"
                            controlWidth: 440

                            Segmented {
                                width: parent.width
                                options: [
                                    {
                                        value: "app",
                                        label: "App"
                                    },
                                    {
                                        value: "1",
                                        label: "Off"
                                    },
                                    {
                                        value: "2",
                                        label: "Mailbox"
                                    },
                                    {
                                        value: "0",
                                        label: "Adaptive"
                                    },
                                    {
                                        value: "3",
                                        label: "On"
                                    }
                                ]
                                value: MangoHud.has("vsync") ? MangoHud.value("vsync", "") : "app"
                                onPicked: v => MangoHud.set("vsync", v === "app" ? null : v)
                            }
                        }

                        // gl_vsync (OpenGL): -1 adaptive, 0 off, 1 on. Without an entry the game decides.
                        SettingRow {
                            width: parent.width
                            label: "Vsync (OpenGL)"
                            description: "OpenGL games. App = the game decides"
                            controlWidth: 440

                            Segmented {
                                width: parent.width
                                options: [
                                    {
                                        value: "app",
                                        label: "App"
                                    },
                                    {
                                        value: "0",
                                        label: "Off"
                                    },
                                    {
                                        value: "-1",
                                        label: "Adaptive"
                                    },
                                    {
                                        value: "1",
                                        label: "On"
                                    }
                                ]
                                value: MangoHud.has("gl_vsync") ? MangoHud.value("gl_vsync", "") : "app"
                                onPicked: v => MangoHud.set("gl_vsync", v === "app" ? null : v)
                            }
                        }
                    }

                    // ----- System > Font -----
                    Column {
                        id: pageSystemFont

                        width: parent.width
                        spacing: 10
                        visible: panel.page === "systemFont"

                        // Rows that appear fade in, the ones below glide smoothly after (instant on a page switch,
                        // the whole page glides then)
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: tabIn.running ? 0 : Theme.ctlMed
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveSmooth
                            }
                        }
                        // With "Subpixel glide" every row glides between pixels: drawn as an image while moving
                        // (text sharp), without it again at the target
                        move: Transition {
                            SequentialAnimation {
                                PropertyAction {
                                    property: "layer.smooth"
                                    value: true
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: Config.opts.barGlide && !tabIn.running
                                }
                                NumberAnimation {
                                    property: "y"
                                    duration: tabIn.running ? 0 : Theme.ctlMed
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curveSmooth
                                }
                                PropertyAction {
                                    property: "layer.enabled"
                                    value: false
                                }
                            }
                        }

                        SettingRow {
                            width: parent.width
                            label: "System font"
                            description: "Every app (GTK, Qt, Firefox, Electron) and the shell. Open apps use it after a restart"

                            FontSelect {
                                objectName: "systemFontSelect"
                                width: parent.width
                                value: panel.systemFont
                                menuParent: card
                                scrollArea: flick
                                active: panel.open && panel.page === "systemFont"
                                onPicked: family => panel.applySystemFont(family)
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
                color: Theme.hairlineStrong
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

            NumberAnimation {
                target: pageTitle
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.ctlMed
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveSmooth
            }
        }

        // System > Profile: crop a picture (drag, zoom), then set it as the account picture. Covers the whole card.
        CropDialog {
            id: cropDialog

            anchors.fill: parent
            z: 200
            outPath: Quickshell.statePath("face-crop.png")
            onApplied: path => User.setPicture(path, cropDialog.file)
        }

        // New top tab: the page list on the left briefly glides in from below (like a new page)
        ParallelAnimation {
            id: sideIn

            NumberAnimation {
                target: tabList
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.ctlMed
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveSmooth
            }

            NumberAnimation {
                target: tabList
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
