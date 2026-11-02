pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.config

// Netzwerkstatus ueber NetworkManager. Ohne NetworkManager: Fallback ueber "ip route".
Singleton {
    id: root

    readonly property bool nm: Networking.backend !== NetworkBackendType.None
    readonly property var devices: Networking.devices.values

    readonly property var active: {
        let wifi = null;
        for (const d of root.devices) {
            if (!d.connected)
                continue;
            if (d.type === DeviceType.Wired)
                return d;
            if (d.type === DeviceType.Wifi && !wifi)
                wifi = d;
        }
        return wifi;
    }

    readonly property var activeNetwork: {
        if (!root.active)
            return null;
        for (const n of root.active.networks.values) {
            if (n.connected)
                return n;
        }
        return null;
    }

    property string fallbackIface: ""
    property bool fallbackWifi: false

    readonly property bool connected: root.nm ? root.active !== null : root.fallbackIface !== ""
    readonly property bool wifi: root.nm ? (root.active !== null && root.active.type === DeviceType.Wifi) : root.fallbackWifi
    readonly property real strength: (root.wifi && root.activeNetwork && root.activeNetwork.signalStrength !== undefined) ? root.activeNetwork.signalStrength : 1
    readonly property string name: {
        if (!root.nm)
            return root.fallbackIface;
        if (root.activeNetwork && root.activeNetwork.name)
            return root.activeNetwork.name;
        return root.active ? root.active.name : "";
    }
    readonly property bool limited: root.nm && root.connected && (Networking.connectivity === NetworkConnectivity.Limited || Networking.connectivity === NetworkConnectivity.Portal)

    function icon() {
        if (!root.connected)
            return root.wifi ? Icons.wifiOff : Icons.lanOff;
        if (!root.wifi)
            return Icons.ethernet;
        if (root.strength > 0.75)
            return Icons.wifi4;
        if (root.strength > 0.5)
            return Icons.wifi3;
        if (root.strength > 0.25)
            return Icons.wifi2;
        return Icons.wifi1;
    }

    Process {
        id: fallback

        command: ["sh", "-c", "dev=$(ip -o route get 1.1.1.1 2>/dev/null | sed -n 's/.* dev \\([^ ]*\\).*/\\1/p'); [ -n \"$dev\" ] || exit 0; if [ -d \"/sys/class/net/$dev/wireless\" ]; then echo \"$dev wifi\"; else echo \"$dev wired\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split(" ");
                root.fallbackIface = p[0] || "";
                root.fallbackWifi = p[1] === "wifi";
            }
        }
    }

    Timer {
        interval: 10000
        running: !root.nm
        repeat: true
        triggeredOnStart: true
        onTriggered: fallback.running = true
    }
}
