pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth ueber BlueZ (nur Status + an/aus, Geraete verwaltet blueman/bluetoothctl).
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: !!root.adapter
    readonly property bool enabled: root.available && root.adapter.enabled
    readonly property var connected: Array.from(Bluetooth.devices.values).filter(d => d.connected)

    function toggle() {
        if (root.available)
            root.adapter.enabled = !root.adapter.enabled;
    }
}
