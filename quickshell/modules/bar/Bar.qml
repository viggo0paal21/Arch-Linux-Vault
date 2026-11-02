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
    readonly property int edge: bar.floatingNow ? Math.ceil(bar.edgeExact - 0.001) : Math.floor(bar.edgeExact + 0.001)
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
    // Der reservierte Platz springt sofort, Hyprland schiebt die Fenster mit seiner eigenen Animation nach.
    implicitHeight: Theme.barHeight + (bar.floating ? Theme.gap : 0)
    exclusiveZone: Theme.barHeight + (bar.floatingNow ? Theme.gap : 0)

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
    // Fenster-Animation in hyprland.lua (windows: speed 3 = 300 ms, Kurve md3_decel), damit
    // Leiste und Fenster gleichzeitig ankommen.
    Item {
        id: frame

        property real progress: bar.floatingNow ? 1 : 0

        x: bar.edge
        y: bar.edge
        width: bar.width - 2 * bar.edge
        height: Theme.barHeight

        onProgressChanged: Ui.barFloat = frame.progress
        Component.onCompleted: {
            Ui.barFloat = frame.progress;
            Ui.barFloatTarget = bar.floatingNow;
        }

        Behavior on progress {
            NumberAnimation {
                duration: Config.opts.animations ? 300 : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
            }
        }

        // Hintergrund auf Sub-Pixel genau (mit Kantenglaettung), damit die Form fluessig gleitet
        Rectangle {
            x: bar.edgeExact - bar.edge
            y: bar.edgeExact - bar.edge
            width: bar.width - 2 * bar.edgeExact
            height: Theme.barHeight
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
                    duration: bar.dynamic ? (Config.opts.animations ? 300 : 0) : Theme.durSlow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: bar.dynamic ? [0.05, 0.7, 0.1, 1.0, 1.0, 1.0] : Theme.curve
                }
            }
        }

        // Links: Launcher, Arbeitsflaechen, Fenstertitel
        Row {
            id: leftRow

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
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
