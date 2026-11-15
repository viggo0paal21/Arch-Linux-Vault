import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Bluetooth page in the control center: connect/disconnect/remove paired devices, pair new devices.
// It only searches for new devices while the page is open (active).
Column {
    id: page

    property bool active: false

    signal back

    spacing: 16

    Binding {
        target: Bt.adapter
        property: "discovering"
        value: true
        when: page.active && Bt.enabled
        restoreMode: Binding.RestoreBindingOrValue
    }

    PageHeader {
        width: page.width
        title: "Bluetooth"
        subtitle: !Bt.available ? "No adapter" : (!Bt.enabled ? "Off" : (Bt.connected.length > 0 ? Bt.connected.map(d => d.name).join(", ") : "On"))
        checked: Bt.enabled
        toggleVisible: Bt.available && !Bt.blocked
        onBack: page.back()
        onToggled: Bt.toggle()
    }

    // Paired devices
    Column {
        width: page.width
        spacing: 2
        visible: Bt.enabled && Bt.paired.length > 0

        Item {
            width: parent.width
            height: 24

            Txt {
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                text: "My devices"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSm
                font.weight: Theme.uiWeightStrong
            }
        }

        Repeater {
            model: ScriptModel {
                values: Bt.paired
            }

            delegate: ListRow {
                id: row

                required property var modelData
                readonly property var dev: modelData

                width: page.width
                icon: Bt.deviceIcon(row.dev)
                title: row.dev.name
                subtitle: Bt.status(row.dev)
                active: row.dev.connected
                trailing: row.dev.connected ? Icons.check : ""
                onClicked: Bt.activate(row.dev)

                actions: [
                    TextButton {
                        visible: row.dev.connected
                        text: "Disconnect"
                        onClicked: row.dev.disconnect()
                    },
                    IconButton {
                        size: 28
                        iconSize: Theme.iconSize - 2
                        fg: Theme.textMuted
                        icon: Icons.trash
                        onClicked: row.dev.forget()
                    }
                ]
            }
        }
    }

    // New devices nearby
    Column {
        width: page.width
        spacing: 2
        visible: Bt.enabled

        Item {
            width: parent.width
            height: 24

            Txt {
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                text: "Other devices"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSm
                font.weight: Theme.uiWeightStrong
            }

            Txt {
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                visible: Bt.adapter !== null && Bt.adapter.discovering
                text: "Searching…"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSm
            }
        }

        Repeater {
            model: ScriptModel {
                values: Bt.nearby
            }

            delegate: ListRow {
                id: nrow

                required property var modelData
                readonly property var dev: modelData

                width: page.width
                icon: Bt.deviceIcon(nrow.dev)
                title: nrow.dev.name
                subtitle: nrow.dev.pairing ? "Pairing…" : (Bt.busy(nrow.dev) ? Bt.status(nrow.dev) : "")
                onClicked: Bt.activate(nrow.dev)
            }
        }

        Txt {
            x: 2
            width: parent.width - 4
            height: 32
            visible: Bt.nearby.length === 0
            text: "Put a device into pairing mode to see it here."
            color: Theme.textMuted
            font.pixelSize: Theme.fontSm + 1
        }
    }

    Txt {
        x: 2
        width: page.width - 4
        visible: !Bt.enabled
        text: !Bt.available ? "No Bluetooth adapter found." : (Bt.blocked ? "Bluetooth is blocked (rfkill)." : "Bluetooth is off.")
        color: Theme.textMuted
        font.pixelSize: Theme.fontSm + 1
        wrapMode: Text.Wrap
    }

    TextButton {
        x: -6
        icon: Icons.openExternal
        text: "Bluetooth settings"
        onClicked: {
            Ui.close();
            Bt.openSettings();
        }
    }
}
