import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick.Effects
import qs.config
import qs.components
import qs.services

// Top bar, one per screen.
PanelWindow {
    id: bar

    required property var modelData
    // "Shell glass" (Settings > Bar): the bar draws the blurred wallpaper itself instead of Hyprland blur.
    // Set by shell.qml when the bar is created (the layer namespace can't be changed later).
    property bool glassMode: false
    property string wallpaperFile: ""
    readonly property bool floating: Config.opts.barFloating
    // "Dynamic": exactly 1 tiled window = docked, otherwise floating (floating windows never count)
    readonly property bool dynamic: bar.floating && Config.opts.barFloatingDynamic
    readonly property bool floatingNow: bar.floating && !(bar.dynamic && bar.tiledCount === 1)
    // ONE pixel counter for the whole motion: height above the edge (offset) in whole pixels, the
    // side gap is derived from it. That way side and height always change in the same frame (straight
    // diagonal instead of zigzag) and nothing ever sits between two pixels (no jitter, sharp edges).
    readonly property int offset: Math.round(Config.opts.barFloatOffset * frame.progress)
    readonly property int edge: Config.opts.barFloatOffset > 0 ? Math.round(bar.offset * Config.opts.barFloatSide / Config.opts.barFloatOffset) : Math.round(Config.opts.barFloatSide * frame.progress)
    // Optionally thicker when docked (Settings > Bar > Bar height > Docked), also in whole pixels
    readonly property int dockExtra: bar.dynamic ? Math.round(Math.max(0, Config.opts.barDockedHeight - Config.opts.barHeight) * (1 - frame.progress)) : 0
    readonly property int bottomEdge: bar.offset + Theme.barHeight + bar.dockExtra
    // "Subpixel glide" (Settings > Bar): only WHILE the dock animation runs. The bar still sits on whole
    // pixels (above), plus only the leftover to the exact position (glideX/glideY, below 1 px). That leftover is
    // rendered smoothly by the background (antialiasing) and the content (each side as one image, filtered).
    // Off or at rest: glideX = glideY = 0, no layer, everything exactly as without the option.
    readonly property bool glide: Config.opts.barGlide && dockTicker.running
    // The glass surface glides between pixels with both blur types, just like the content. With Hyprland's
    // blur (Glass blur: Hyprland) the barshape shader draws it instead of a rectangle: Hyprland only blurs
    // pixels above ignore_alpha 0.5; a half-covered edge pixel over a window would get no blur and the
    // window would show through darkened (dark line). At the top (only wallpaper behind) normal antialiasing; in the
    // rows where a window can be under the bar, an edge pixel is either full glass (blurred) or
    // stays just below the threshold, in a fixed pattern (see edgeDither and shaders/barshape.frag).
    // On whole pixels (at rest) this is exactly the same as a rectangle.
    readonly property bool bgGlide: bar.glide
    // Pattern only while a window can be under the bottom edge: the whole time while docking (the window comes up),
    // only at the start while undocking (after that only wallpaper is under the edge, where
    // normal antialiasing is more accurate).
    readonly property bool edgeDither: dockTicker.running && (bar.dockTo === 0 || bar.dockElapsed < 0.1 * Config.opts.barDockDuration)
    readonly property real edgeExact: Config.opts.barFloatSide * frame.progress
    readonly property real offsetExact: Config.opts.barFloatOffset * frame.progress
    readonly property real dockExtraExact: bar.dynamic ? Math.max(0, Config.opts.barDockedHeight - Config.opts.barHeight) * (1 - frame.progress) : 0
    readonly property real glideX: bar.glide ? bar.edgeExact - bar.edge : 0
    readonly property real glideY: bar.glide ? bar.offsetExact - bar.offset : 0
    // With "Dynamic" the content sits 1 px lower, floating and docked alike
    readonly property int contentShift: bar.dynamic ? 1 : 0
    // Bottom edge of the visible bar (for the tray menu)
    readonly property int visualBottom: frame.y + frame.height
    readonly property var hyprMonitor: Hyprland.monitorFor(bar.modelData)
    readonly property int itemHeight: Theme.barHeight - 8

    // Windows on the active workspace of this monitor.
    // No windows = transparent bar, 1 or more windows = black.
    readonly property int windowCount: {
        const ws = bar.hyprMonitor ? bar.hyprMonitor.activeWorkspace : null;
        return ws ? ws.toplevels.values.length : 0;
    }
    readonly property bool solid: !Config.opts.barAutoTransparent || bar.windowCount > 0
    // Windows without floating ones, for "Solid bar with windows"
    readonly property int tiledCount: Hypr.tiledCount(bar.hyprMonitor)
    // Same for the bar color, optionally without kitty (Exclude kitty terminal)
    readonly property int glassCount: Config.opts.barExcludeKitty ? Hypr.tiledCount(bar.hyprMonitor, true) : bar.tiledCount
    // "Solid bar with windows": black from 1 window on, with "Only 1" only with exactly 1 window.
    // "Only 1" counts all windows: from 2 windows on the bar is translucent, even if one of them is kitty.
    // "Exclude kitty" only means that a single kitty doesn't make the bar black.
    readonly property bool solidByWindows: Config.opts.barSolidWithWindows && (Config.opts.barSolidOnlySingle ? bar.tiledCount === 1 && bar.glassCount === 1 : bar.glassCount > 0)
    // 0 = transparent (empty workspace), glass = Transparency "Everywhere", otherwise black
    readonly property real bgOpacity: {
        if (!bar.solid)
            return 0;
        if (Config.opts.transparency === "everywhere" && !bar.solidByWindows)
            return Theme.glassAlpha;
        return 1;
    }

    // Right edge of the clock/system box on screen. The dashboard opens below it.
    readonly property real infoChipRight: frame.x + rightRow.x + infoChip.x + infoChip.width

    onInfoChipRightChanged: Ui.setInfoChipRight(bar.modelData.name, bar.infoChipRight)
    Component.onCompleted: Ui.setInfoChipRight(bar.modelData.name, bar.infoChipRight)

    screen: modelData
    color: "transparent"
    // The window itself stays put, only the visible bar (frame) slides inside it.
    implicitHeight: Theme.barHeight + (bar.floating ? Math.max(Theme.gap, Config.opts.barFloatOffset) : 0)
    // Reserved space at the top. With "Dynamic" it always stays at the bar height: the gap below the
    // floating bar comes from Hyprland (gaps_out top, 0 with a single window via smart gaps).
    // That way only Hyprland moves the windows when switching, in one go, and the bar simply slides
    // over them. If Quickshell switched the reserved space, windows and bar would never start at exactly
    // the same time and a line would flash in between.
    exclusiveZone: Theme.barHeight + (bar.floating && !bar.dynamic ? Config.opts.barFloatOffset : 0)

    anchors {
        top: true
        left: true
        right: true
    }

    // Clicks only on the visible bar, the free strip below it lets clicks through
    mask: Region {
        item: frame
    }

    // qsglass-bar: no Hyprland blur (own layer rule in hyprland.lua), qs-bar: Hyprland blur + xray
    WlrLayershell.namespace: bar.glassMode ? "qsglass-bar" : "qs-bar"
    WlrLayershell.layer: WlrLayer.Top

    IdleInhibitor {
        enabled: Ui.caffeine
        window: bar
    }

    // Dock animation, computed frame by frame instead of by the clock. When a window opens or closes,
    // Quickshell may not draw for ~70 ms. A normal animation keeps running by the clock
    // and the bar then jumps 2-3 px at once. Here every frame counts
    // at most 1/60 s: after such a freeze it simply continues where the bar was.
    property real dockFrom: 0
    property real dockTo: 0
    property real dockElapsed: 0

    // Value of the bezier curve (x1, y1, x2, y2) at position u (0..1)
    function curveAt(c, u) {
        if (u <= 0)
            return 0;
        if (u >= 1)
            return 1;
        const x1 = c[0], y1 = c[1], x2 = c[2], y2 = c[3];
        let lo = 0, hi = 1, t = u;
        for (let i = 0; i < 24; i++) {
            const x = 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t;
            if (Math.abs(x - u) < 0.00001)
                break;
            if (x < u)
                lo = t;
            else
                hi = t;
            t = (lo + hi) / 2;
        }
        return 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t;
    }

    // Only starts when the target really changes. Qt.callLater merges all window events of one
    // pass, so a quick back and forth of the window count doesn't interrupt anything.
    function syncDock() {
        const target = bar.floatingNow ? 1 : 0;
        Ui.barFloatTarget = bar.floatingNow;
        if (dockTicker.running && bar.dockTo === target)
            return;
        if (!dockTicker.running && frame.progress === target)
            return;
        dockTicker.running = false;
        if (!Config.opts.animations || Config.opts.barDockDuration <= 0) {
            frame.progress = target;
            return;
        }
        bar.dockFrom = frame.progress;
        bar.dockTo = target;
        bar.dockElapsed = 0;
        dockTicker.running = true;
    }

    onFloatingNowChanged: Qt.callLater(bar.syncDock)

    FrameAnimation {
        id: dockTicker

        running: false
        onTriggered: {
            const dt = Math.max(0, Math.min(dockTicker.frameTime, 1 / 60)) * 1000;
            bar.dockElapsed += dt;
            const u = Math.min(1, bar.dockElapsed / Math.max(1, Config.opts.barDockDuration));
            frame.progress = bar.dockFrom + (bar.dockTo - bar.dockFrom) * bar.curveAt(Theme.curveOf(Config.opts.animBarCurve), u);
            if (u >= 1)
                dockTicker.running = false;
        }
    }

    // ---------- Shell glass ----------
    // Why: Hyprland only blurs behind bar pixels above ignore_alpha (0.5). When the bottom edge glides smoothly,
    // the bottom row is only partly covered, gets no blur and the window below shows through darkly
    // (black line). When the bar draws its glass itself (blurred wallpaper, like xray), it is opaque within its
    // shape and edge pixels blend normally with the window below, just like Hyprland windows.

    // Wallpaper from waypaper (wallpaper = ..., fill = fill)
    FileView {
        id: waypaperConfig

        path: bar.glassMode ? Quickshell.env("HOME") + "/.config/waypaper/config.ini" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const m = /^\s*wallpaper\s*=\s*(.+?)\s*$/m.exec(waypaperConfig.text());
            bar.wallpaperFile = m ? m[1].replace(/^~(?=\/|$)/, Quickshell.env("HOME")) : "";
        }
    }

    // ---------- Glass exactly like kitty: Hyprland's own blur ----------
    // Behind kitty Hyprland (decoration:blur) does: contrast curve -> dual kawase blur (halve passes times with
    // vibrancy, double passes times) -> noise, then kitty puts 55 % black on top. components/HyprBlur.qml
    // recomputes that with Hyprland's shaders 1:1. The values are in Settings > Bar (same as in hyprland.lua).
    // It starts from the wallpaper exactly as awww shows it (qs-glasswall, below).
    // Only a strip at the top is computed, and only when the wallpaper or a value changes. After that they are
    // finished images: it costs nothing per frame.
    readonly property real screenW: bar.screen ? bar.screen.width : bar.width
    readonly property real screenH: bar.screen ? bar.screen.height : bar.height
    readonly property int glassPasses: Math.max(1, Math.min(8, Config.opts.glassBlurPasses))
    // Strip = bar window + as far as the blur reaches (2 x size x (2^passes - 1) + margin), divisible by 2^passes
    // so every stage has whole pixels. At most the whole screen.
    readonly property int glassStripHeight: {
        const step = Math.pow(2, bar.glassPasses);
        const reach = 2 * Math.max(1, Config.opts.glassBlurSize) * (step - 1) + 2 * step + 8;
        const want = Math.ceil((bar.height + reach) / step) * step;
        return Math.min(want, Math.round(bar.screenH));
    }

    // Wallpaper exactly as awww shows it: qs-glasswall (source in tools/glasswall, same Rust crates as awww
    // 0.12.1) decodes and scales it like awww and writes the strip at the top as an image. Qt decodes JPEGs slightly
    // differently (libjpeg instead of zune-jpeg), that was most of the difference to kitty.
    // Only runs when the wallpaper, the screen or the strip height changes (about 0.1 s, in the background).
    // If the program is missing or fails, the bar computes the wallpaper itself (wallFull, below).
    readonly property string glassWallTool: Quickshell.env("HOME") + "/.local/bin/qs-glasswall"
    readonly property string glassWallOut: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/glass/" + bar.modelData.name + ".ppm"
    readonly property string glassWallKey: bar.glassMode && bar.wallpaperFile !== "" ? [bar.wallpaperFile, bar.screenW, bar.screenH, bar.glassStripHeight].join("|") : ""
    // "" = still running, "exact" = image from qs-glasswall, "fallback" = compute it itself
    property string glassWallState: ""
    property int glassWallRun: 0

    onGlassWallKeyChanged: glassWallDelay.restart()

    // Wait briefly until size and values are set at startup (otherwise several runs in a row)
    Timer {
        id: glassWallDelay

        interval: 50
        onTriggered: {
            if (bar.glassWallKey === "")
                return;
            if (glassWallProc.running) {
                glassWallDelay.restart();
                return;
            }
            glassWallProc.running = true;
        }
    }

    Process {
        id: glassWallProc

        // Through sh, so a missing program cleanly ends up as an error (exit code 127)
        command: ["sh", "-c", "mkdir -p \"$(dirname \"$5\")\" && exec \"$0\" \"$@\"", bar.glassWallTool, bar.wallpaperFile, String(Math.round(bar.screenW)), String(Math.round(bar.screenH)), String(bar.glassStripHeight), bar.glassWallOut]
        onExited: code => {
            if (code === 0) {
                bar.glassWallRun++;
                bar.glassWallState = "exact";
            } else {
                bar.glassWallState = "fallback";
            }
        }
    }

    Image {
        id: wallExact

        visible: false
        source: bar.glassWallState === "exact" ? "file://" + bar.glassWallOut + "?n=" + bar.glassWallRun : ""
        asynchronous: true
        cache: false
        // Keep the old image while reloading until the new one is ready (no black flash)
        retainWhileLoading: true
        smooth: false
        layer.enabled: bar.glassMode
    }

    // Computed by the bar itself (only without qs-glasswall): wallpaper at its original size, exactly the pixels from the file.
    // Scaled down in the shader like awww does it (Lanczos3, cropped centered).
    // The bar window starts at 0,0, so the coordinates match 1:1. Only the strip at the top is needed.
    Image {
        id: wallFull

        visible: false
        source: bar.glassMode && bar.glassWallState === "fallback" && bar.wallpaperFile !== "" ? "file://" + bar.wallpaperFile : ""
        asynchronous: true
        cache: false
        // As a layer at its original size (pixels 1:1): this way the shader reliably gets every new image
        layer.enabled: bar.glassMode
    }

    readonly property real wallW: wallFull.status === Image.Ready ? wallFull.implicitWidth : 0
    readonly property real wallH: wallFull.status === Image.Ready ? wallFull.implicitHeight : 0
    // awww "fill": scale so the screen is filled, crop the rest centered
    readonly property real wallZoom: bar.wallW > 0 ? Math.max(bar.screenW / bar.wallW, bar.screenH / bar.wallH) : 1
    readonly property real wallLeft: (bar.wallW - bar.screenW / bar.wallZoom) / 2
    readonly property real wallTop: (bar.wallH - bar.screenH / bar.wallZoom) / 2
    readonly property real wallSupport: 3 * Math.max(1 / bar.wallZoom, 1)
    // Only the image rows the strip at the top needs
    readonly property int wallRowStart: Math.max(0, Math.floor(bar.wallTop - bar.wallSupport) - 1)
    readonly property int wallRowEnd: Math.min(bar.wallH, Math.ceil(bar.wallTop + bar.glassStripHeight / bar.wallZoom + bar.wallSupport) + 2)

    // awww step 1: scale horizontally (only the rows that are needed)
    ShaderEffect {
        id: wallResizeH

        property var source: wallFull
        property vector2d dstSize: Qt.vector2d(width, height)
        property real vertical: 0
        property real zoom: bar.wallZoom
        property real offset: bar.wallLeft
        property real rowStart: bar.wallRowStart

        visible: false
        width: bar.width
        height: Math.max(1, bar.wallRowEnd - bar.wallRowStart)
        layer.enabled: bar.glassMode
        fragmentShader: bar.glassMode ? glassBlur.shader("hyprresample") : ""
    }

    // awww step 2: scale vertically. Result = the strip at the top, exactly as awww shows it
    ShaderEffect {
        id: wallStrip

        property var source: wallResizeH
        property vector2d dstSize: Qt.vector2d(width, height)
        property real vertical: 1
        property real zoom: bar.wallZoom
        property real offset: bar.wallTop - bar.wallRowStart
        property real rowStart: 0

        visible: false
        width: bar.width
        height: bar.glassStripHeight
        layer.enabled: bar.glassMode
        layer.smooth: true
        fragmentShader: bar.glassMode ? glassBlur.shader("hyprresample") : ""
    }

    HyprBlur {
        id: glassBlur

        source: bar.glassWallState === "exact" ? wallExact : wallStrip
        active: bar.glassMode
        screenSize: Qt.vector2d(bar.screenW, bar.screenH)
        noise: Config.opts.glassBlurNoise
        size: Config.opts.glassBlurSize
        passes: Config.opts.glassBlurPasses
        contrast: Config.opts.glassBlurContrast
        brightness: Config.opts.glassBlurBrightness
        vibrancy: Config.opts.glassBlurVibrancy
        vibrancyDarkness: Config.opts.glassBlurVibrancyDarkness
    }

    Item {
        id: glassSource

        visible: false
        width: bar.width
        height: bar.height
        layer.enabled: bar.glassMode

        // Opaque base: the glass is always 100 % opaque, nothing below ever shows through
        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        // On top the black with the bar's opacity (Transparency 55 % = kitty background_opacity 0.55),
        // computed and rounded to 8 bits the way Hyprland puts kitty's background over the blur. Blended by Qt
        // it would come out darker: the driver writes 8-bit textures rounding up only from x.56 on.
        // Deliberately without its own layer: inside an invisible layer Qt hides a child that has its own layer
        // (that was the cause of the black bar).
        ShaderEffect {
            id: glassDim

            property var source: glassBlur.output
            property real dim: bgRect.opacity

            width: glassBlur.width
            height: glassBlur.height
            visible: bar.glassMode
            fragmentShader: bar.glassMode ? glassBlur.shader("hyprdim") : ""
        }
    }

    // Shape of the bar (exactly like the background, antialiased) as the mask
    Item {
        id: glassMask

        visible: false
        width: bar.width
        height: bar.height
        layer.enabled: bar.glassMode

        Rectangle {
            x: frame.x + bgRect.x
            y: frame.y + bgRect.y
            width: bgRect.width
            height: bgRect.height
            radius: bgRect.radius
            antialiasing: true
            color: "white"
        }
    }

    MultiEffect {
        x: 0
        y: 0
        width: bar.width
        height: bar.height
        visible: bar.glassMode
        source: glassSource
        autoPaddingEnabled: false
        maskEnabled: bar.glassMode
        maskSource: glassMask
        // Threshold 0.5 + spread 1.0 = smooth transition over the whole edge coverage (no hard cut)
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        // "Transparent when empty": the glass fades out with the bar
        opacity: bgRect.opacity >= Theme.glassAlpha ? 1 : bgRect.opacity / Math.max(0.01, Theme.glassAlpha)
    }

    // Visible bar. Switches between docked and floating as fast as Hyprland's
    // window animation in hyprland.lua (windows: speed 3 = 300 ms), so that
    // bar and windows arrive at the same time.
    Item {
        id: frame

        // 0 = docked, 1 = floating. Only moved by dockTicker (see syncDock).
        property real progress: 0

        x: bar.edge
        y: bar.offset
        width: bar.width - 2 * bar.edge
        height: Theme.barHeight

        onProgressChanged: Ui.barFloat = frame.progress
        Component.onCompleted: {
            frame.progress = bar.floatingNow ? 1 : 0;
            Ui.barFloat = frame.progress;
            Ui.barFloatTarget = bar.floatingNow;
        }

        // Background: all edges on whole pixels, always the same thickness
        Rectangle {
            id: bgRect

            x: bar.bgGlide ? bar.glideX : 0
            y: bar.bgGlide ? bar.glideY : 0
            width: frame.width - 2 * (bar.bgGlide ? bar.glideX : 0)
            // With "Subpixel glide" the bottom edge glides just like the top edge (exact thickness in every frame).
            // When it ran on whole pixels, the bar was briefly up to 1 px thicker at the end while the top edge
            // crept over the last half pixel. At the start/end the values equal the resting ones (no jump).
            height: bar.bgGlide ? Theme.barHeight + bar.dockExtraExact : bar.bottomEdge - bar.offset
            antialiasing: true
            // With "Own" the glass effect draws the surface (it takes over the opacity), with Hyprland's blur
            // the shader below (black over the blur like kitty). The rectangle itself only carries shape,
            // opacity and border.
            color: "transparent"
            opacity: bar.bgOpacity
            radius: bar.bgGlide ? Theme.radiusLg * frame.progress : Math.round(Theme.radiusLg * frame.progress)
            border.width: frame.progress > 0.5 && Config.opts.barBorder ? 1 : 0
            border.color: Theme.border

            // Surface for Hyprland's blur. Sits on whole pixels (1 px margin around the bar), the shape comes in exactly
            // as numbers, so every edge can lie between two pixels.
            ShaderEffect {
                readonly property int pad: 1
                property vector4d rect: Qt.vector4d(bgRect.x + pad, bgRect.y + pad, bgRect.x + bgRect.width + pad, bgRect.y + bgRect.height + pad)
                property vector2d itemSize: Qt.vector2d(width, height)
                property vector2d origin: Qt.vector2d(frame.x - pad, frame.y - pad)
                property real radius: bgRect.radius
                property real zoneY: bar.exclusiveZone
                property real dither: bar.edgeDither ? 1 : 0
                property color fill: Theme.bg

                x: -bgRect.x - pad
                y: -bgRect.y - pad
                width: frame.width + 2 * pad
                height: Theme.barHeight + Math.max(0, Config.opts.barDockedHeight - Config.opts.barHeight) + 2 * pad + 2
                visible: !bar.glassMode
                fragmentShader: glassBlur.shader("barshape")
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                visible: frame.progress <= 0.5 && Config.opts.barBorder
                color: Theme.border
            }

            // With "Dynamic" in sync with the docking
            Behavior on opacity {
                NumberAnimation {
                    duration: bar.dynamic ? (Config.opts.animations ? Config.opts.barDockDuration : 0) : Theme.durSlow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: bar.dynamic ? Theme.curveOf(Config.opts.animBarCurve) : Theme.curve
                }
            }
        }

        // Group boxes (Settings > Bar > Group boxes): a surface behind every group,
        // exactly as big as the group itself (hover/active surfaces sit exactly on top of it).
        BarBox { row: leftRow; target: archBtn; shiftX: bar.glideX; shiftY: bar.glideY }
        BarBox { row: leftRow; target: wsGroup; shiftX: bar.glideX; shiftY: bar.glideY }
        BarBox { row: rightRow; target: trayGroup; shiftX: -bar.glideX; shiftY: bar.glideY }
        BarBox { row: rightRow; target: infoChip; shiftX: -bar.glideX; shiftY: bar.glideY }
        BarBox { row: rightRow; target: statusGroup; shiftX: -bar.glideX; shiftY: bar.glideY }
        BarBox { row: rightRow; target: powerBtn; shiftX: -bar.glideX; shiftY: bar.glideY }

        // Left: launcher, workspaces, window title
        Row {
            id: leftRow

            anchors.left: parent.left
            anchors.leftMargin: 6
            // Whole pixels for the image with "Subpixel glide" (see rightRow)
            width: Math.ceil(implicitWidth)
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: bar.contentShift
            spacing: 6
            // Subpixel glide: moved smoothly by the leftover as one image (only during the animation)
            layer.enabled: bar.glide
            layer.smooth: true
            transform: Translate {
                x: bar.glideX
                y: bar.glideY
            }

            IconButton {
                id: archBtn

                anchors.verticalCenter: parent.verticalCenter
                size: bar.itemHeight
                icon: Config.opts.launcherIcon === "tux" ? Icons.tux : Icons.arch
                iconSize: Config.opts.launcherIconSize
                active: Ui.panel === "launcher"
                onClicked: Ui.toggle("launcher", bar.screen)
            }

            Workspaces {
                id: wsGroup

                anchors.verticalCenter: parent.verticalCenter
                height: bar.itemHeight
                monitor: bar.hyprMonitor
            }
        }

        Txt {
            id: windowTitle

            // Only when "Window title" is on: otherwise Quickshell redoes text layout and font fallback
            // on every title change (terminal prompt) for nothing.
            readonly property var toplevel: Config.opts.barShowTitle ? Hyprland.activeToplevel : null
            readonly property string value: (toplevel && toplevel.monitor === bar.hyprMonitor) ? (toplevel.title || "") : ""

            anchors.left: leftRow.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: bar.contentShift
            width: Math.max(0, Math.min(implicitWidth, rightRow.x - x - 24))
            visible: Config.opts.barShowTitle && value !== "" && width > 30
            layer.enabled: bar.glide && visible
            layer.smooth: true
            transform: Translate {
                x: bar.glideX
                y: bar.glideY
            }
            text: value
            color: Theme.fgDim
        }

        // Right: tray, system monitor + clock, status, power
        Row {
            id: rightRow

            // Position and width on whole pixels. With "Subpixel glide" the row is drawn as an image during the
            // animation; when it sat between two pixels (width from text widths like "73%"), the image landed
            // 1 px further right and jumped at the start/end of the animation. This way both paths match exactly.
            x: Math.round(parent.width - 6 - implicitWidth)
            width: Math.ceil(implicitWidth)
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: bar.contentShift
            spacing: Config.opts.barBoxes ? 6 : 4
            layer.enabled: bar.glide
            layer.smooth: true
            transform: Translate {
                x: -bar.glideX
                y: bar.glideY
            }

            Tray {
                id: trayGroup

                anchors.verticalCenter: parent.verticalCenter
                barWindow: bar
                itemSize: bar.itemHeight
            }

            // One box for CPU/RAM/temperature and clock, opens the dashboard
            BarChip {
                id: infoChip

                anchors.verticalCenter: parent.verticalCenter
                height: bar.itemHeight
                spacing: 12
                active: Ui.panel === "dashboard"
                onClicked: Ui.toggle("dashboard", bar.screen)

                SysMini {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Config.opts.barShowSysmon
                    fg: infoChip.fg
                    fgDim: infoChip.fgDim
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Config.opts.barShowSysmon
                    width: 1
                    height: 14
                    color: infoChip.fgDim
                    opacity: 0.4
                }

                BarClock {
                    anchors.verticalCenter: parent.verticalCenter
                    fg: infoChip.fg
                    fgDim: infoChip.fgDim
                }
            }

            StatusCluster {
                id: statusGroup

                anchors.verticalCenter: parent.verticalCenter
                height: bar.itemHeight
                active: Ui.panel === "control"
                onClicked: Ui.toggle("control", bar.screen)
            }

            IconButton {
                id: powerBtn

                anchors.verticalCenter: parent.verticalCenter
                size: bar.itemHeight
                icon: Icons.power
                iconSize: Theme.barIconSize
                active: Ui.panel === "power"
                onClicked: Ui.toggle("power", bar.screen)
            }
        }
    }
}
