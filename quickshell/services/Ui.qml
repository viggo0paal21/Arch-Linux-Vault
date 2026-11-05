pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

// Which panel is open and on which screen. Only one at a time.
// Names: launcher, control, dashboard, power, settings
Singleton {
    id: root

    property string panel: ""
    property var panelScreen: null
    property bool caffeine: false

    // Shape of the bar, set by the bar itself: 0 = docked, 1 = floating.
    // barFloat follows the animation, barFloatTarget is the target state.
    property real barFloat: Config.opts.barFloating ? 1 : 0
    property bool barFloatTarget: Config.opts.barFloating
    // Bottom edge of the bar (panels open below it)
    readonly property real barBottom: Theme.px(Theme.barHeight + Config.opts.barFloatOffset * root.barFloat)
    readonly property int barBottomTarget: Theme.barHeight + (root.barFloatTarget ? Config.opts.barFloatOffset : 0)

    // Right edge of the clock/system box in the bar, per screen (screen name -> x).
    // The dashboard opens right below it.
    property var infoChipRight: ({})

    function setInfoChipRight(screenName, x) {
        if (root.infoChipRight[screenName] === x)
            return;
        const next = Object.assign({}, root.infoChipRight);
        next[screenName] = x;
        root.infoChipRight = next;
    }

    function focusedScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === name)
                return screens[i];
        }
        return screens.length > 0 ? screens[0] : null;
    }

    function open(name, screen) {
        root.panelScreen = screen ? screen : root.focusedScreen();
        root.panel = name;
    }

    function close() {
        root.panel = "";
    }

    function toggle(name, screen) {
        if (root.panel === name)
            root.close();
        else
            root.open(name, screen);
    }
}
