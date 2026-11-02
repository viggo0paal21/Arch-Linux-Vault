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
    readonly property int edge: floating ? Theme.gap : 0
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
    // 0 = durchsichtig (leere Arbeitsflaeche), Glas = Transparency "Everywhere", sonst schwarz
    readonly property real bgOpacity: {
        if (!bar.solid)
            return 0;
        if (Config.opts.transparency === "everywhere" && !(Config.opts.barSolidWithWindows && bar.tiledCount > 0))
            return Theme.glassAlpha;
        return 1;
    }

    // Rechte Kante des Uhr-/System-Kaestchens auf dem Bildschirm. Das Dashboard klappt darunter auf.
    readonly property real infoChipRight: bar.edge + rightRow.x + infoChip.x + infoChip.width

    onInfoChipRightChanged: Ui.setInfoChipRight(bar.modelData.name, bar.infoChipRight)
    Component.onCompleted: Ui.setInfoChipRight(bar.modelData.name, bar.infoChipRight)

    screen: modelData
    color: "transparent"
    implicitHeight: Theme.barHeight

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: bar.edge
        left: bar.edge
        right: bar.edge
    }

    WlrLayershell.namespace: "qs-bar"
    WlrLayershell.layer: WlrLayer.Top

    IdleInhibitor {
        enabled: Ui.caffeine
        window: bar
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: bar.bgOpacity
        radius: bar.floating ? Theme.radiusLg : 0
        border.width: bar.floating && Config.opts.barBorder ? 1 : 0
        border.color: Theme.border

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            visible: !bar.floating && Config.opts.barBorder
            color: Theme.border
        }

        Behavior on opacity {
            Anim {
                duration: Theme.durSlow
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
