pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Transparent surfaces with Hyprland blur (Settings > Appearance > Transparency).
// The blur itself is done by Hyprland via layer_rule (see Quickshell Guide).
Singleton {
    id: root

    readonly property string mode: Config.opts.transparency

    // Panels, menus, notifications, OSD
    readonly property bool popups: root.mode === "everywhere" || (root.mode === "popups" && !(Config.opts.popupsSolidWithWindows && Hypr.focusedTiledCount > 0))
    readonly property color popupBg: root.popups ? Qt.rgba(0, 0, 0, Theme.glassAlpha) : Theme.layer1
}
