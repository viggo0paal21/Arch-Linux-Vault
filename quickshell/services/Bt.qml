pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth via BlueZ (status + on/off only, devices are managed by blueman/bluetoothctl).
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
