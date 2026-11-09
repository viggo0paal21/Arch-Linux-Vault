import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Popups top right, slide in from the right and back out.
PanelWindow {
    id: win

    readonly property int topOffset: Ui.barBottomTarget + Theme.gap
    readonly property bool hasPopups: Notifs.popups.length > 0
    property bool mapped: false

    // Like the panels: the window always exists and sits above the screen when there are no popups.
    // Creating a new window (Vulkan swapchain) every time froze Quickshell for 60-120 ms.
    // Exception: fullscreen game. Then it's gone completely, otherwise the overlay layer blocks direct scanout.
    readonly property bool fullscreenActive: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.fullscreen : false

    screen: Ui.focusedScreen()
    visible: win.mapped || !win.fullscreenActive
    color: "transparent"
    implicitWidth: 400
    // Fixed height (space below the floating bar), NOT bound to the current dock position: otherwise
    // the window changes its size on every dock/undock and Quickshell rebuilds the Vulkan swapchain
    // (~20 ms stutter). The position (margins.top) still follows the bar.
    implicitHeight: win.screen ? Math.max(200, win.screen.height - Theme.barBottom - 2 * Theme.gap) : 800
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }

    margins {
        top: win.mapped ? win.topOffset : -(win.implicitHeight + 64)
        right: Theme.gap
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-notifications"

    // Only the cards take clicks, the rest lets them through
    mask: Region {
        item: maskItem
    }

    onHasPopupsChanged: {
        if (win.hasPopups) {
            hold.stop();
            win.mapped = true;
        } else {
            hold.restart();
        }
    }

    // Only close once the last card has slid out
    Timer {
        id: hold

        interval: Math.round(Theme.durSlow * Config.opts.animNotifSpeed) + 120
        onTriggered: {
            if (!win.hasPopups)
                win.mapped = false;
        }
    }

    Item {
        id: maskItem

        width: list.width
        height: Math.min(list.contentHeight, win.height)
    }

    ListView {
        id: list

        width: parent.width
        height: parent.height
        spacing: Theme.gap
        interactive: false
        model: ScriptModel {
            values: Notifs.popups
        }

        add: Transition {
            ParallelAnimation {
                Anim {
                    property: "x"
                    from: 72
                    to: 0
                    duration: Math.round(Theme.durSlow * Config.opts.animNotifSpeed)
                    easing.bezierCurve: Theme.curveOf(Config.opts.animNotifCurve)
                }
                Anim {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Math.round(Theme.durMed * Config.opts.animNotifSpeed)
                }
            }
        }

        remove: Transition {
            ParallelAnimation {
                Anim {
                    property: "x"
                    to: 72
                    duration: Math.round(Theme.durMed * Config.opts.animNotifSpeed)
                    easing.bezierCurve: Theme.curveOf(Config.opts.animNotifCurve)
                }
                Anim {
                    property: "opacity"
                    to: 0
                    duration: Math.round(Theme.durMed * Config.opts.animNotifSpeed)
                }
            }
        }

        displaced: Transition {
            Anim {
                property: "y"
                duration: Math.round(Theme.durMed * Config.opts.animNotifSpeed)
                easing.bezierCurve: Theme.curveOf(Config.opts.animNotifCurve)
            }
        }

        delegate: NotifCard {
            required property var modelData

            width: list.width
            notif: modelData
            popup: true
        }
    }
}
