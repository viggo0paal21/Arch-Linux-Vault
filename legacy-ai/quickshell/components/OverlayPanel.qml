import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Base for all panels: fullscreen layer (clicking outside closes),
// soft fade in/out, Escape closes, the panel owns the keyboard.
PanelWindow {
    id: win

    property bool open: false
    property bool dim: false
    property real dimOpacity: 0.5
    property string ns: "qs-panel"
    property int animDuration: Theme.durMed
    // Group for Settings > Animations: "panel" (dashboard, control center) or "overlay" (launcher, settings, power)
    property string animGroup: "overlay"
    readonly property bool panelGroup: win.animGroup === "panel"
    readonly property real animSpeed: win.panelGroup ? Config.opts.animPanelSpeed : Config.opts.animOverlaySpeed
    property bool mapped: false
    // Closed panels stay mapped but invisible. That way opening doesn't have to create a new
    // window (Wayland surface + Vulkan swapchain), which caused ~90 ms stutters.
    // Exception: a fullscreen window is active. Then they're gone completely, otherwise the
    // overlay layer would block direct scanout and tearing in games.
    readonly property bool fullscreenActive: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.fullscreen : false
    readonly property real progress: stage.t
    default property alias content: stage.data

    signal dismissed

    // Only close the window once the out animation is done and an empty
    // (transparent) frame has been drawn. That way a Hyprland layer animation
    // can never "take along" half a panel.
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

    // When closed, the window is moved completely up off the screen (same size, stays mapped).
    // When it lay invisible over the screen, Hyprland blurred the whole screen for every closed panel
    // on every workspace switch (fps dropped to ~140). Only move it instead of
    // shrinking it: a resize rebuilds the Vulkan swapchain, which caused ~40 ms lag when opening.
    implicitWidth: win.screen ? win.screen.width : 1920
    implicitHeight: win.screen ? win.screen.height : 1080

    anchors {
        top: true
        left: true
    }

    margins {
        top: win.mapped ? 0 : -(win.implicitHeight + 64)
    }
    exclusionMode: ExclusionMode.Ignore

    // Closed: clicks go through the invisible panel
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
        duration: Math.round(win.animDuration * win.animSpeed)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveOf(win.panelGroup ? Config.opts.animPanelOpen : Config.opts.animOverlayOpen)
    }

    NumberAnimation {
        id: closeAnim

        target: stage
        property: "t"
        to: 0
        duration: Math.round(win.animDuration * 0.85 * win.animSpeed)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveOf(win.panelGroup ? Config.opts.animPanelClose : Config.opts.animOverlayClose)
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
