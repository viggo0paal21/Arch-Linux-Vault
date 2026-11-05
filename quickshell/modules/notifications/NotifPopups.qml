import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Popups oben rechts, gleiten von rechts rein und wieder raus.
PanelWindow {
    id: win

    readonly property int topOffset: Ui.barBottomTarget + Theme.gap
    readonly property bool hasPopups: Notifs.popups.length > 0
    property bool mapped: false

    // Wie die Panels: Das Fenster bleibt dauerhaft bestehen und liegt ohne Popups oberhalb des Bildschirms.
    // Jedes Mal ein neues Fenster (Vulkan-Swapchain) anzulegen liess Quickshell 60-120 ms haengen.
    // Ausnahme Vollbild-Spiel: dann ganz weg, sonst blockiert die Overlay-Ebene Direct Scanout.
    readonly property bool fullscreenActive: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.fullscreen : false

    screen: Ui.focusedScreen()
    visible: win.mapped || !win.fullscreenActive
    color: "transparent"
    implicitWidth: 400
    implicitHeight: win.screen ? Math.max(200, win.screen.height - win.topOffset - Theme.gap) : 800
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

    // Nur die Karten nehmen Klicks an, der Rest ist durchlaessig
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

    // Erst schliessen, wenn die letzte Karte rausgeglitten ist
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
