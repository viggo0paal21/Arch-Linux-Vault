import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Leiste oben, eine pro Bildschirm.
PanelWindow {
    id: bar

    required property var modelData
    readonly property bool floating: Config.opts.barFloating
    // "Dynamic": genau 1 gekacheltes Fenster = angedockt, sonst schwebend (floating Fenster zaehlen nie)
    readonly property bool dynamic: bar.floating && Config.opts.barFloatingDynamic
    readonly property bool floatingNow: bar.floating && !(bar.dynamic && bar.tiledCount === 1)
    // EIN Pixelzaehler fuer die ganze Bewegung: Hoehe ueber dem Rand (intOffset) in ganzen Pixeln, der
    // Seitenabstand wird daraus abgeleitet. So aendern sich Seite und Hoehe immer im selben Frame (gerade
    // schraeg statt Zickzack) und nichts liegt je zwischen zwei Pixeln (kein Jittern, scharfe Kanten).
    readonly property int offset: Math.round(Config.opts.barFloatOffset * frame.progress)
    readonly property int edge: Config.opts.barFloatOffset > 0 ? Math.round(bar.offset * Theme.gap / Config.opts.barFloatOffset) : Math.round(Theme.gap * frame.progress)
    // Angedockt optional dicker (Settings > Bar > Bar height > Docked), ebenfalls in ganzen Pixeln
    readonly property int dockExtra: bar.dynamic ? Math.round(Math.max(0, Config.opts.barDockedHeight - Config.opts.barHeight) * (1 - frame.progress)) : 0
    readonly property int bottomEdge: bar.offset + Theme.barHeight + bar.dockExtra
    // Inhalt mit "Dynamic" fest 1 px tiefer, schwebend wie angedockt
    readonly property int contentShift: bar.dynamic ? 1 : 0
    // Unterkante der sichtbaren Leiste (fuer das Tray-Menue)
    readonly property int visualBottom: frame.y + frame.height
    readonly property var hyprMonitor: Hyprland.monitorFor(bar.modelData)
    readonly property int itemHeight: Theme.barHeight - 8

    // Fenster auf der aktiven Arbeitsflaeche dieses Monitors.
    // Keine Fenster = Leiste durchsichtig, ab 1 Fenster = schwarz.
    readonly property int windowCount: {
        const ws = bar.hyprMonitor ? bar.hyprMonitor.activeWorkspace : null;
        return ws ? ws.toplevels.values.length : 0;
    }
    readonly property bool solid: !Config.opts.barAutoTransparent || bar.windowCount > 0
    // Fenster ohne schwebende (floating), fuer "Solid bar with windows"
    readonly property int tiledCount: Hypr.tiledCount(bar.hyprMonitor)
    // Dasselbe fuer die Farbe der Leiste, auf Wunsch ohne kitty (Exclude kitty terminal)
    readonly property int glassCount: Config.opts.barExcludeKitty ? Hypr.tiledCount(bar.hyprMonitor, true) : bar.tiledCount
    // "Solid bar with windows": schwarz ab 1 Fenster, mit "Only 1" nur bei genau 1 Fenster
    readonly property bool solidByWindows: Config.opts.barSolidWithWindows && (Config.opts.barSolidOnlySingle ? bar.glassCount === 1 : bar.glassCount > 0)
    // 0 = durchsichtig (leere Arbeitsflaeche), Glas = Transparency "Everywhere", sonst schwarz
    readonly property real bgOpacity: {
        if (!bar.solid)
            return 0;
        if (Config.opts.transparency === "everywhere" && !bar.solidByWindows)
            return Theme.glassAlpha;
        return 1;
    }

    // Rechte Kante des Uhr-/System-Kaestchens auf dem Bildschirm. Das Dashboard klappt darunter auf.
    readonly property real infoChipRight: frame.x + rightRow.x + infoChip.x + infoChip.width

    onInfoChipRightChanged: Ui.setInfoChipRight(bar.modelData.name, bar.infoChipRight)
    Component.onCompleted: Ui.setInfoChipRight(bar.modelData.name, bar.infoChipRight)

    screen: modelData
    color: "transparent"
    // Das Fenster selbst bleibt fest, nur die sichtbare Leiste (frame) gleitet darin.
    implicitHeight: Theme.barHeight + (bar.floating ? Math.max(Theme.gap, Config.opts.barFloatOffset) : 0)
    // Reservierter Platz oben. Mit "Dynamic" bleibt er immer bei der Leistenhoehe: Den Abstand unter der
    // schwebenden Leiste macht Hyprland (gaps_out oben 10 + 8 = 18, bei einem Fenster 0 per Smart Gaps).
    // So bewegt beim Wechsel nur Hyprland die Fenster, in einem Zug, und die Leiste gleitet einfach
    // darueber. Wuerde Quickshell den Platz umschalten, starten Fenster und Leiste nie exakt gleichzeitig
    // und dazwischen blitzt kurz eine Linie auf.
    exclusiveZone: Theme.barHeight + (bar.floating && !bar.dynamic ? Config.opts.barFloatOffset : 0)

    anchors {
        top: true
        left: true
        right: true
    }

    // Klicks nur auf der sichtbaren Leiste, der freie Streifen darunter ist durchlaessig
    mask: Region {
        item: frame
    }

    WlrLayershell.namespace: "qs-bar"
    WlrLayershell.layer: WlrLayer.Top

    IdleInhibitor {
        enabled: Ui.caffeine
        window: bar
    }

    // Andock-Animation, Frame fuer Frame selbst gerechnet statt nach der Uhr. Oeffnet oder schliesst ein
    // Fenster, zeichnet Quickshell manchmal ~70 ms lang nichts (Treiber). Eine normale Animation laeuft
    // nach der Uhr weiter und die Leiste springt danach 2-3 px auf einmal. Hier zaehlt jeder Frame
    // hoechstens 1/60 s: Nach so einem Haenger geht es einfach dort weiter, wo die Leiste stand.
    property real dockFrom: 0
    property real dockTo: 0
    property real dockElapsed: 0

    // Wert der Bezier-Kurve (x1, y1, x2, y2) an der Stelle u (0..1)
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

    // Startet nur, wenn sich das Ziel wirklich aendert. Qt.callLater fasst alle Fenster-Events eines
    // Durchlaufs zusammen, ein kurzes Hin und Her der Fensterzahl bricht nichts ab.
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

    // Sichtbare Leiste. Wechselt zwischen angedockt und schwebend genauso schnell wie Hyprlands
    // Fenster-Animation in hyprland.lua (windows: speed 3 = 300 ms, Kurve smooth_out = easeOutQuint), damit
    // Leiste und Fenster gleichzeitig ankommen.
    Item {
        id: frame

        // 0 = angedockt, 1 = schwebend. Wird nur von dockTicker bewegt (siehe syncDock).
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

        // Hintergrund: alle Kanten auf ganzen Pixeln, immer gleich dick
        Rectangle {
            x: 0
            y: 0
            width: frame.width
            height: bar.bottomEdge - bar.offset
            antialiasing: true
            color: Theme.bg
            opacity: bar.bgOpacity
            radius: Math.round(Theme.radiusLg * frame.progress)
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

            // Mit "Dynamic" im selben Takt wie das Andocken
            Behavior on opacity {
                NumberAnimation {
                    duration: bar.dynamic ? (Config.opts.animations ? Config.opts.barDockDuration : 0) : Theme.durSlow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: bar.dynamic ? Theme.curveOf(Config.opts.animBarCurve) : Theme.curve
                }
            }
        }

        // Gruppen-Boxen (Settings > Bar > Group boxes): eigene Flaeche hinter jeder Gruppe,
        // genau so gross wie die Gruppe selbst (Hover/Aktiv-Flaechen liegen deckungsgleich darauf).
        BarBox { row: leftRow; target: archBtn }
        BarBox { row: leftRow; target: wsGroup }
        BarBox { row: rightRow; target: trayGroup }
        BarBox { row: rightRow; target: infoChip }
        BarBox { row: rightRow; target: statusGroup }
        BarBox { row: rightRow; target: powerBtn }

        // Links: Launcher, Arbeitsflaechen, Fenstertitel
        Row {
            id: leftRow

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: bar.contentShift
            spacing: 6

            IconButton {
                id: archBtn

                anchors.verticalCenter: parent.verticalCenter
                size: bar.itemHeight
                icon: Icons.arch
                iconSize: Theme.barIconSize + 2
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

            // Nur wenn "Window title" an ist: Sonst rechnet Quickshell bei jeder Titelaenderung (Terminal-Prompt)
            // trotzdem Text-Layout und Ersatzschriften neu aus, das blockierte die Leiste kurz.
            readonly property var toplevel: Config.opts.barShowTitle ? Hyprland.activeToplevel : null
            readonly property string value: (toplevel && toplevel.monitor === bar.hyprMonitor) ? (toplevel.title || "") : ""

            anchors.left: leftRow.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: bar.contentShift
            width: Math.max(0, Math.min(implicitWidth, rightRow.x - x - 24))
            visible: Config.opts.barShowTitle && value !== "" && width > 30
            text: value
            color: Theme.fgDim
        }

        // Rechts: Tray, Systemmonitor + Uhr, Status, Power
        Row {
            id: rightRow

            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: bar.contentShift
            spacing: Config.opts.barBoxes ? 6 : 4

            Tray {
                id: trayGroup

                anchors.verticalCenter: parent.verticalCenter
                barWindow: bar
                itemSize: bar.itemHeight
            }

            // Ein Kaestchen fuer CPU/RAM/Temperatur und Uhr, oeffnet das Dashboard
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
