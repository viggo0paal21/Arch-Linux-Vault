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
    // Abstand zum Rand, gleitet mit frame.progress zwischen 0 (angedockt) und Theme.gap (schwebend).
    // edgeExact ist der genaue Wert fuer den Hintergrund: Bei nur 8 px Weg gaebe es auf ganze Pixel
    // gerundet nur ~7 sichtbare Schritte. Inhalt und Klickflaeche bleiben auf ganzen Pixeln (scharfe Schrift).
    readonly property real edgeExact: Theme.gap * frame.progress
    // Ganze Pixel fuer den Inhalt, in Richtung Ziel gerundet: Der letzte Pixelschritt kommt so noch waehrend
    // die Leiste sichtbar gleitet (~95 ms) statt einzeln hinterher (~140 ms, wirkte wie "Einklicken").
    // Der Inhalt ist dabei nie mehr als 1 px vor dem Hintergrund.
    readonly property int intEdge: bar.floatingNow ? Math.ceil(bar.edgeExact - 0.001) : Math.floor(bar.edgeExact + 0.001)
    // Mit "Smooth text" gleitet auch der Inhalt genau mit; die Unterkante bleibt trotzdem auf ganzen Pixeln
    readonly property real edge: Theme.smooth ? bar.edgeExact : bar.intEdge
    // Hoehe der schwebenden Leiste ueber dem Bildschirmrand (Settings > Bar > Floating position, Standard 8 px).
    // Gleitet wie edge, nur mit eigenem Weg; die Seiten bleiben bei Theme.gap.
    readonly property real offsetExact: Config.opts.barFloatOffset * frame.progress
    readonly property int intOffset: bar.floatingNow ? Math.ceil(bar.offsetExact - 0.001) : Math.floor(bar.offsetExact + 0.001)
    readonly property real offset: Theme.smooth ? bar.offsetExact : bar.intOffset
    // Angedockt ist der Hintergrund unten etwas dicker (Settings > Bar > Bar height > Docked, Standard 2 px)
    // und liegt damit ueber den obersten Pixelreihen des Fensters. Schliesst man eins von zwei Fenstern,
    // waechst das andere 18 px nach oben, die Leiste gleitet nur 8 px. Das Fenster kriecht seinen letzten
    // Pixel noch, wenn die Leiste schon oben ist; ohne die Extra-Pixel blitzt dazwischen das Wallpaper als
    // Linie. Waechst mit dem Andocken von 0 auf den eingestellten Wert (schwebend 0).
    readonly property int dockExtra: bar.dynamic ? Math.round(Math.max(0, Config.opts.barDockedExtra) * (1 - frame.progress)) : 0
    // Unterkante des Hintergrunds als eine stetige Kurve (Position + Extra-Dicke), auf ganze Pixel nach unten
    // gerundet: Sobald die Fensterkante die Leiste erreicht hat, kann sie nicht mehr darunter hervorschauen
    // (vorher sprangen Position und Extra-Dicke getrennt und der Spalt ging fuer einzelne Frames wieder auf).
    // Die -0.25 lassen sie kurz vor Schluss ankommen statt erst im letzten Frame (kein Nachklicken).
    readonly property real bottomExact: Theme.barHeight + bar.offsetExact + (bar.dynamic ? Math.max(0, Config.opts.barDockedExtra) * (1 - frame.progress) : 0)
    readonly property int bottomY: Math.ceil(bar.bottomExact - 0.25)
    // Mit "Smooth text" gleitet auch die Unterkante auf Bruchteile von Pixeln (kein Einrasten im letzten Pixel).
    // Die Extra-Dicke sorgt dafuer, dass sie dabei ueber dem Fenster liegt und nicht ueber einem Spalt.
    readonly property real bottomEdge: Theme.smooth ? bar.bottomExact : bar.bottomY
    // Inhalt mit "Dynamic" fest 1 px tiefer, schwebend wie angedockt: So sitzt er in beiden Zustaenden
    // praktisch mittig und muss beim An-/Abdocken nicht extra um einen Pixel nachrutschen.
    readonly property real contentShift: bar.dynamic ? 1 : 0
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

    onFloatingNowChanged: Ui.barFloatTarget = bar.floatingNow

    // Sichtbare Leiste. Wechselt zwischen angedockt und schwebend genauso schnell wie Hyprlands
    // Fenster-Animation in hyprland.lua (windows: speed 3 = 300 ms, Kurve smooth_out = easeOutQuint), damit
    // Leiste und Fenster gleichzeitig ankommen.
    Item {
        id: frame

        property real progress: bar.floatingNow ? 1 : 0

        x: bar.edge
        y: bar.offset
        width: bar.width - 2 * bar.edge
        height: Theme.barHeight

        onProgressChanged: Ui.barFloat = frame.progress
        Component.onCompleted: {
            Ui.barFloat = frame.progress;
            Ui.barFloatTarget = bar.floatingNow;
        }

        // Dauer: Settings > Bar > Dock animation (Standard 400 ms). Etwas langsamer als die Fenster (300 ms),
        // damit ein nach oben wachsendes Fenster vor der Leiste ankommt und kein Spalt aufblitzt.
        Behavior on progress {
            NumberAnimation {
                duration: Config.opts.animations ? Config.opts.barDockDuration : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
            }
        }

        // Hintergrund: links/rechts auf Sub-Pixel genau (mit Kantenglaettung), damit die Form fluessig gleitet.
        // Oben/unten auf ganzen Pixeln im Takt des Inhalts: So ist die Leiste in jedem Frame exakt gleich dick
        // (vorher kroch die Oberkante am Ende noch den letzten Pixel nach und die Leiste wurde sichtbar duenner),
        // und unten gibt es keine halb bedeckte Pixelreihe ueber dem Fenster.
        Rectangle {
            x: bar.edgeExact - bar.edge
            y: 0
            width: bar.width - 2 * bar.edgeExact
            height: bar.bottomEdge - bar.offset
            antialiasing: true
            color: Theme.bg
            opacity: bar.bgOpacity
            radius: Theme.radiusLg * frame.progress
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

            // Mit "Dynamic" im selben Takt wie das Andocken (300 ms, md3_decel): Schwarzwerden und
            // Andocken sind dann eine Bewegung statt schnellem Gleiten mit langsamem Nachblenden.
            Behavior on opacity {
                NumberAnimation {
                    duration: bar.dynamic ? (Config.opts.animations ? Config.opts.barDockDuration : 0) : Theme.durSlow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: bar.dynamic ? [0.22, 1.0, 0.36, 1.0, 1.0, 1.0] : Theme.curve
                }
            }
        }

        // Links: Launcher, Arbeitsflaechen, Fenstertitel
        Row {
            id: leftRow

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: bar.contentShift
            spacing: 6

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: bar.itemHeight
                icon: Icons.arch
                iconSize: Theme.barIconSize + 2
                active: Ui.panel === "launcher"
                onClicked: Ui.toggle("launcher", bar.screen)
            }

            Workspaces {
                anchors.verticalCenter: parent.verticalCenter
                height: bar.itemHeight
                monitor: bar.hyprMonitor
            }
        }

        Txt {
            id: windowTitle

            readonly property var toplevel: Hyprland.activeToplevel
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
            spacing: 4

            Tray {
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
                anchors.verticalCenter: parent.verticalCenter
                height: bar.itemHeight
                active: Ui.panel === "control"
                onClicked: Ui.toggle("control", bar.screen)
            }

            IconButton {
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
