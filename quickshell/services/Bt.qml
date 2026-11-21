pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.config

// Bluetooth via BlueZ: status, on/off and the device list for the Bluetooth page in the control center.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: !!root.adapter
    readonly property bool enabled: root.available && root.adapter.enabled
    readonly property bool blocked: root.available && root.adapter.state === BluetoothAdapterState.Blocked
    readonly property var connected: Array.from(Bluetooth.devices.values).filter(d => d.connected)

    readonly property var devices: root.adapter ? Array.from(root.adapter.devices.values) : []
    // Paired devices: connected ones first, then by name
    readonly property var paired: root.devices.filter(d => d.paired || d.bonded).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // New devices nearby. Without a real name (address only) they are almost always other people's sensors etc., so they are left out.
    readonly property var nearby: root.devices.filter(d => !d.paired && !d.bonded && d.deviceName !== "").sort((a, b) => a.name.localeCompare(b.name))

    function toggle() {
        if (root.available)
            root.adapter.enabled = !root.adapter.enabled;
    }

    function deviceIcon(d) {
        const i = d.icon || "";
        if (i.startsWith("audio-head"))
            return Icons.headphones;
        if (i.startsWith("audio"))
            return Icons.speaker;
        if (i === "input-mouse")
            return Icons.mouse;
        if (i === "input-keyboard")
            return Icons.keyboard;
        if (i === "input-gaming")
            return Icons.gamepad;
        if (i === "phone")
            return Icons.phone;
        if (i === "computer")
            return Icons.laptop;
        if (i === "video-display")
            return Icons.tv;
        if (i === "printer")
            return Icons.printer;
        return Icons.bluetooth;
    }

    function busy(d) {
        return d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting;
    }

    function status(d) {
        if (d.pairing)
            return "Pairing…";
        if (d.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting…";
        if (d.connected)
            return d.batteryAvailable ? "Connected · " + Math.round(d.battery * 100) + "%" : "Connected";
        return d.paired || d.bonded ? "Not connected" : "";
    }

    // Click on a device: connect/disconnect, pair new devices first (then trust and connect)
    function activate(d) {
        if (root.busy(d))
            return;
        if (d.connected) {
            d.disconnect();
        } else if (d.paired || d.bonded) {
            d.connect();
        } else {
            pairWatch.target = d;
            d.pair();
        }
    }

    function openSettings() {
        Quickshell.execDetached(["sh", "-c", "command -v blueman-manager >/dev/null && exec blueman-manager || exec " + Config.opts.terminal + " -e bluetoothctl"]);
    }

    // After pairing worked: trust the device (it reconnects by itself from now on) and connect right away
    Connections {
        id: pairWatch

        target: null
        ignoreUnknownSignals: true

        function onPairedChanged() {
            const d = pairWatch.target;
            if (d && d.paired) {
                pairWatch.target = null;
                d.trusted = true;
                if (!d.connected)
                    d.connect();
            }
        }
    }
}
