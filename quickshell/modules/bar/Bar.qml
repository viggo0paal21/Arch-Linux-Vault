import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Top bar, one per screen.
PanelWindow {
    id: bar

    required property var modelData
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
    // "Solid bar with windows": black from 1 window, with "Only 1" only with exactly 1 window
    readonly property bool solidByWindows: Config.opts.barSolidWithWindows && (Config.opts.barSolidOnlySingle ? bar.glassCount === 1 : bar.glassCount > 0)
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

    WlrLayershell.namespace: "qs-bar"
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
            x: bar.glideX
            y: bar.glideY
            width: frame.width - 2 * bar.glideX
            // Bottom edge stays on whole pixels even with "Subpixel glide": a half-covered pixel row at the bottom
            // gets no blur from Hyprland (ignore_alpha), so the window shows through darkly = black line.
            height: bar.glide ? bar.bottomEdge - bar.offsetExact : bar.bottomEdge - bar.offset
            antialiasing: true
            color: Theme.bg
            opacity: bar.bgOpacity
            radius: bar.glide ? Theme.radiusLg * frame.progress : Math.round(Theme.radiusLg * frame.progress)
            border.width: frame.progress > 0.5 && Config.opts.barBorder ? 1 : 0
            border.color: Theme.border

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
