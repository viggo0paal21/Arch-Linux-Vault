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

    // Rechte Kante des Uhr-/System-Kaestchens in der Leiste, je Bildschirm (Bildschirm-Name -> x).
    // Das Dashboard klappt genau darunter auf.
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
