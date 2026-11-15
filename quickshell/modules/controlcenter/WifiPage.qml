import QtQuick
import Quickshell
import Quickshell.Networking
import qs.config
import qs.components
import qs.services

// Wi-Fi page in the control center: nearby networks, connect (with password), disconnect, forget.
// It only scans while the page is open (active).
Column {
    id: page

    property bool active: false
    // Network with the password field open, and network where connecting failed last (both by name)
    property string expanded: ""
    property string failed: ""

    signal back

    spacing: 16

    onActiveChanged: {
        if (!page.active)
            page.expanded = "";
    }

    Binding {
        target: Net.wifiDevice
        property: "scannerEnabled"
        value: true
        when: page.active && Net.wifiDevice !== null && Net.wifiEnabled
        restoreMode: Binding.RestoreBindingOrValue
    }

    PageHeader {
        width: page.width
        title: "Wi-Fi"
        subtitle: !Net.nm ? "NetworkManager not running" : (!Net.wifiDevice ? "No Wi-Fi adapter" : (!Net.wifiEnabled ? "Off" : (Net.wifi ? Net.name : "Not connected")))
        checked: Net.wifiEnabled
        toggleVisible: Net.nm && Net.wifiDevice !== null && !Net.wifiBlocked
        onBack: page.back()
        onToggled: Net.setWifiEnabled(!Net.wifiEnabled)
    }

    // Ethernet, only when a cable is connected
    ListRow {
        width: page.width
        visible: Net.wiredDevice !== null && Net.wiredDevice.connected
        clickable: false
        active: true
        icon: Icons.ethernet
        title: "Ethernet"
        subtitle: {
            const d = Net.wiredDevice;
            if (!d)
                return "";
            let s = "Connected";
            if (d.linkSpeed > 0)
                s += " · " + (d.linkSpeed >= 1000 ? (d.linkSpeed / 1000) + " Gb/s" : d.linkSpeed + " Mb/s");
            if (Net.limited && !Net.wifi)
                s += " · No internet";
            return s;
        }
        trailing: Icons.check
    }

    Column {
        width: page.width
        spacing: 2
        visible: Net.wifiEnabled

        Item {
            width: parent.width
            height: 24

            Txt {
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                text: "Networks"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSm
                font.weight: Theme.uiWeightStrong
            }
        }

        Repeater {
            model: ScriptModel {
                values: Net.networks
            }

            delegate: ListRow {
                id: row

                required property var modelData
                readonly property var net: modelData
                readonly property bool open: Net.isOpen(row.net)
                readonly property bool enterprise: Net.isEnterprise(row.net)

                width: page.width
                icon: Net.networkIcon(row.net)
                title: row.net.name
                active: row.net.connected
                trailing: row.net.connected ? Icons.check : ""
                expanded: page.expanded === row.net.name
                subtitle: {
                    const n = row.net;
                    if (n.stateChanging)
                        return n.state === ConnectionState.Disconnecting ? "Disconnecting…" : "Connecting…";
                    if (n.connected)
                        return Net.limited ? "Connected · No internet" : "Connected";
                    if (page.failed === n.name)
                        return row.open ? "Couldn't connect" : "Couldn't connect · check the password";
                    if (n.known)
                        return "Saved";
                    if (row.enterprise)
                        return "Enterprise · opens network settings";
                    return row.open ? "Open" : "";
                }

                onClicked: {
                    const n = row.net;
                    if (n.connected || n.stateChanging)
                        return;
                    if (row.enterprise && !n.known) {
                        Ui.close();
                        Net.openSettings();
                        return;
                    }
                    if (n.known || row.open) {
                        page.failed = "";
                        page.expanded = "";
                        n.connect();
                        return;
                    }
                    page.expanded = page.expanded === n.name ? "" : n.name;
                }

                onExpandedChanged: {
                    if (row.expanded)
                        Qt.callLater(() => pw.forceActiveFocus());
                    else
                        pw.text = "";
                }

                function connectWithPassword() {
                    if (pw.text === "")
                        return;
                    page.failed = "";
                    row.net.connectWithPsk(pw.text);
                    page.expanded = "";
                }

                actions: [
                    TextButton {
                        visible: row.net.connected
                        text: "Disconnect"
                        onClicked: row.net.disconnect()
                    },
                    IconButton {
                        visible: row.net.known
                        size: 28
                        iconSize: Theme.iconSize - 2
                        fg: Theme.textMuted
                        icon: Icons.trash
                        onClicked: {
                            if (page.failed === row.net.name)
                                page.failed = "";
                            row.net.forget();
                        }
                    }
                ]

                Connections {
                    target: row.net

                    function onConnectionFailed(reason) {
                        page.failed = row.net.name;
                        // Wrong or missing password: expand the field (again)
                        if (!row.open && !row.enterprise)
                            page.expanded = row.net.name;
                    }
                    function onConnectedChanged() {
                        if (row.net.connected && page.failed === row.net.name)
                            page.failed = "";
                    }
                }

                // Password field (expanded)
                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: parent.width - connectBtn.width - 8
                        height: 32
                        radius: Theme.radiusSm
                        color: pw.activeFocus ? Theme.fillStrong : Theme.fill
                        border.width: 1
                        border.color: pw.activeFocus ? Theme.hairline : "transparent"

                        TextInput {
                            id: pw

                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            echoMode: TextInput.Password
                            passwordCharacter: "•"
                            color: Theme.fg
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.accentFg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSm + 1
                            font.weight: Theme.uiWeight
                            renderType: Theme.smooth ? Text.QtRendering : Text.NativeRendering
                            selectByMouse: true
                            onAccepted: row.connectWithPassword()
                            Keys.onEscapePressed: page.expanded = ""

                            Txt {
                                anchors.fill: parent
                                visible: pw.text === ""
                                text: "Password"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSm + 1
                            }
                        }
                    }

                    TextButton {
                        id: connectBtn

                        anchors.verticalCenter: parent.verticalCenter
                        height: 32
                        text: "Connect"
                        fg: Theme.fg
                        enabled: pw.text !== ""
                        onClicked: row.connectWithPassword()
                    }
                }
            }
        }

        Txt {
            x: 2
            width: parent.width - 4
            height: 32
            visible: Net.networks.length === 0
            text: "Searching for networks…"
            color: Theme.textMuted
            font.pixelSize: Theme.fontSm + 1
        }
    }

    Txt {
        x: 2
        width: page.width - 4
        visible: Net.nm && Net.wifiDevice !== null && !Net.wifiEnabled
        text: Net.wifiBlocked ? "Wi-Fi is blocked (airplane mode or hardware switch)." : "Wi-Fi is off."
        color: Theme.textMuted
        font.pixelSize: Theme.fontSm + 1
        wrapMode: Text.Wrap
    }

    TextButton {
        x: -6
        icon: Icons.openExternal
        text: "Network settings"
        onClicked: {
            Ui.close();
            Net.openSettings();
        }
    }
}
