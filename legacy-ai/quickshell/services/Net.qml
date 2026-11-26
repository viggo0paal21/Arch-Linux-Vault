pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.config

// Network status via NetworkManager. Without NetworkManager: fallback via "ip route".
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
    // NetworkManager reports "no internet" when its own check (through the device, not through the tunnel)
    // does not get through. With a VPN like NordVPN that happens a lot even though everything works. So in that case
    // we check again ourselves, and "No internet" only shows up when this check fails too.
    readonly property bool nmLimited: root.nm && root.connected && (Networking.connectivity === NetworkConnectivity.Limited || Networking.connectivity === NetworkConnectivity.Portal)
    // -1 = not checked yet, 0 = no internet, 1 = internet works
    property int probeResult: -1
    readonly property bool limited: root.nmLimited && root.probeResult === 0

    onNmLimitedChanged: {
        if (!root.nmLimited)
            root.probeResult = -1;
    }

    // Wi-Fi and wired device (even when not connected), for the Wi-Fi page in the control center
    readonly property var wifiDevice: {
        for (const d of root.devices) {
            if (d.type === DeviceType.Wifi)
                return d;
        }
        return null;
    }
    readonly property var wiredDevice: {
        for (const d of root.devices) {
            if (d.type === DeviceType.Wired)
                return d;
        }
        return null;
    }
    readonly property bool wifiEnabled: root.nm && Networking.wifiEnabled
    readonly property bool wifiBlocked: root.nm && !Networking.wifiHardwareEnabled

    // Networks found: connected first, then saved ones, then by signal. The signal is rounded roughly
    // so the list does not re-sort on every small fluctuation.
    readonly property var networks: {
        if (!root.wifiDevice)
            return [];
        const list = Array.from(root.wifiDevice.networks.values).filter(n => n.name !== "");
        const rank = n => (n.connected ? 100 : 0) + (n.known ? 10 : 0) + Math.round(n.signalStrength * 4);
        list.sort((a, b) => rank(b) - rank(a) || a.name.localeCompare(b.name));
        return list;
    }

    function setWifiEnabled(on) {
        if (root.nm)
            Networking.wifiEnabled = on;
    }

    // Open = no password, Enterprise = needs a user name (nm-connection-editor handles that)
    function isOpen(n) {
        return n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe;
    }
    function isEnterprise(n) {
        return n.security === WifiSecurityType.WpaEap || n.security === WifiSecurityType.Wpa2Eap || n.security === WifiSecurityType.Wpa3SuiteB192 || n.security === WifiSecurityType.Leap || n.security === WifiSecurityType.DynamicWep;
    }

    function networkIcon(n) {
        const s = n.signalStrength;
        const open = root.isOpen(n);
        if (s > 0.75)
            return open ? Icons.wifi4 : Icons.wifiLock4;
        if (s > 0.5)
            return open ? Icons.wifi3 : Icons.wifiLock3;
        if (s > 0.25)
            return open ? Icons.wifi2 : Icons.wifiLock2;
        return open ? Icons.wifi1 : Icons.wifiLock1;
    }

    function openSettings() {
        Quickshell.execDetached(["sh", "-c", "command -v nm-connection-editor >/dev/null && exec nm-connection-editor || exec " + Config.opts.terminal + " -e nmtui"]);
    }

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

    // Our own check: the same page NetworkManager uses on Arch, but through the normal default route (so
    // also through a VPN). Without curl a ping is enough.
    Process {
        id: probe

        command: ["sh", "-c", "if command -v curl >/dev/null 2>&1; then curl -s -m 5 http://ping.archlinux.org/nm-check.txt | grep -q 'NetworkManager is online'; else ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; fi"]
        onExited: code => {
            if (root.nmLimited)
                root.probeResult = code === 0 ? 1 : 0;
        }
    }

    // If the internet works: check every 5 minutes (as often as NetworkManager does), otherwise every 30 s
    Timer {
        interval: root.probeResult === 1 ? 300000 : 30000
        running: root.nmLimited
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!probe.running)
                probe.running = true;
        }
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
