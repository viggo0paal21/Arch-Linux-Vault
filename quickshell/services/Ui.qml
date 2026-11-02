pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Welches Panel offen ist und auf welchem Bildschirm. Immer nur eins gleichzeitig.
// Namen: launcher, control, dashboard, power, settings
Singleton {
    id: root

    property string panel: ""
    property var panelScreen: null
    property bool caffeine: false

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
