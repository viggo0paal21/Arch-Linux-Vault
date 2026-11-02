pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Durchsichtige Flaechen mit Hyprland-Blur (Settings > Appearance > Transparency).
// Den Blur selbst macht Hyprland per layer_rule (siehe Quickshell Guide).
Singleton {
    id: root

    readonly property string mode: Config.opts.transparency

    // Panels, Menues, Benachrichtigungen, OSD
    readonly property bool popups: root.mode === "everywhere" || (root.mode === "popups" && !(Config.opts.popupsSolidWithWindows && Hypr.focusedTiledCount > 0))
    readonly property color popupBg: root.popups ? Qt.rgba(0, 0, 0, Theme.glassAlpha) : Theme.layer1
}
