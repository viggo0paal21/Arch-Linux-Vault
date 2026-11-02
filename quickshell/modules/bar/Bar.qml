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
        opacity: bar.solid ? 1 : 0
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
        width: Math.max(0, Math.min(implicitWidth, clock.x - x - 24))
        visible: Config.opts.barShowTitle && value !== "" && width > 30
        text: value
        color: Theme.fgDim
    }

    // Mitte: Uhr
    BarClock {
        id: clock

        anchors.centerIn: parent
        height: bar.itemHeight
        active: Ui.panel === "dashboard"
        onClicked: Ui.toggle("dashboard", bar.screen)
    }

    // Rechts: Tray, Systemmonitor, Status, Power
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

        SysMini {
            anchors.verticalCenter: parent.verticalCenter
            height: bar.itemHeight
            visible: Config.opts.barShowSysmon
            active: Ui.panel === "dashboard"
            onClicked: Ui.toggle("dashboard", bar.screen)
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
