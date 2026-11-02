import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Basis fuer alle Panels: Vollbild-Ebene (Klick daneben schliesst),
// weiches Ein-/Ausblenden, Escape schliesst, Tastatur gehoert dem Panel.
PanelWindow {
    id: win

    property bool open: false
    property bool dim: false
    property real dimOpacity: 0.5
    property string ns: "qs-panel"
    property int animDuration: Theme.durMed
    property bool mapped: false
    // Geschlossene Panels bleiben unsichtbar gemappt. So muss beim Oeffnen kein neues
    // Fenster (Wayland-Flaeche + Vulkan-Swapchain) angelegt werden, das gab ~90 ms Ruckler.
    // Ausnahme: ein Vollbild-Fenster ist aktiv. Dann sind sie ganz weg, sonst wuerde die
    // Overlay-Ebene Direct Scanout und Tearing in Spielen blockieren.
    readonly property bool fullscreenActive: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.fullscreen : false
    readonly property real progress: stage.t
    default property alias content: stage.data

    signal dismissed

    // Fenster erst schliessen, wenn die Raus-Animation fertig ist und ein leerer
    // (transparenter) Frame gezeichnet wurde. So kann eine Hyprland-Layer-Animation
    // nie ein halbes Panel "mitnehmen".
    onOpenChanged: {
        openAnim.stop();
        closeAnim.stop();
        unmapDelay.stop();
        if (win.open) {
            win.mapped = true;
            openAnim.start();
        } else {
            closeAnim.start();
            unmapDelay.interval = closeAnim.duration + 80;
            unmapDelay.restart();
        }
    }

    visible: win.mapped || !win.fullscreenActive
    color: win.dim ? Qt.rgba(0, 0, 0, win.dimOpacity * stage.t) : "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore

    // Geschlossen: Klicks gehen durch das unsichtbare Panel hindurch
    mask: Region {
        item: win.open ? stage : null
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: win.ns
    WlrLayershell.keyboardFocus: win.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: win.dismissed()
    }

    FocusScope {
        id: stage

        property real t: 0

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.dismissed()
    }

    NumberAnimation {
        id: openAnim

        target: stage
        property: "t"
        to: 1
        duration: win.animDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveEmph
    }

    NumberAnimation {
        id: closeAnim

        target: stage
        property: "t"
        to: 0
        duration: Math.round(win.animDuration * 0.85)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveAccel
    }

    Timer {
        id: unmapDelay

        interval: 80
        onTriggered: {
            if (!win.open)
                win.mapped = false;
        }
    }
}
