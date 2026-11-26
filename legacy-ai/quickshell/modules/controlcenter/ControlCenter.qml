import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.notifications

// Control center top right: quick settings, volume, media, notifications.
// Wi-Fi and Bluetooth each have a sub page that slides in from the right.
OverlayPanel {
    id: panel

    readonly property int topOffset: Ui.barBottomTarget + Theme.gap
    // Sub page: "" = main page, otherwise "wifi" or "bluetooth". shownPage stays set while sliding back.
    property string page: ""
    property string shownPage: ""
    // 0 = main page, 1 = sub page. While sliding, both pages are drawn as a texture (sharp text),
    // at rest without a texture on whole pixels, like when the panel opens.
    property real pageT: panel.page !== "" ? 1 : 0
    // Per-app volume expanded (stays that way until collapsed again)
    property bool mixerOpen: false
    // "Subpixel glide" (Settings > Bar or Animations): heights grow smoothly instead of in whole pixels. What slides
    // down because of that is drawn as an image while moving (text sharp) and shifted smoothly, like the bar.
    readonly property bool glide: Config.opts.barGlide
    readonly property bool mixerGliding: panel.glide && mixer.openT > 0 && mixer.openT < 1

    // Whole pixels without "Subpixel glide", exact otherwise
    function glidePx(v) {
        return panel.glide ? v : Math.round(v);
    }

    Behavior on pageT {
        enabled: panel.open

        Anim {
            duration: Theme.durMed
            easing.bezierCurve: Theme.curveSmooth
        }
    }

    onPageChanged: {
        if (panel.page !== "")
            panel.shownPage = panel.page;
    }
    // Fully closed: show the main page again next time it opens
    onProgressChanged: {
        if (panel.progress === 0 && !panel.open && panel.page + panel.shownPage !== "") {
            panel.page = "";
            panel.shownPage = "";
        }
    }

    open: Ui.panel === "control"
    screen: Ui.panelScreen
    ns: "qs-control"
    animDuration: Theme.durSlow
    animGroup: "panel"
    onDismissed: Ui.close()

    // Slides out from under the bar
    DropdownSlot {
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
        width: 420
        contentHeight: card.height
        progress: panel.progress

        Card {
            id: card

            readonly property real maxH: panel.height - panel.topOffset - Theme.gap
            readonly property real mainH: Math.min(col.implicitHeight + 2 * Theme.padLg, card.maxH)
            readonly property real subH: Math.min(pageLoader.height + 2 * Theme.padLg, card.maxH)

            width: parent.width
            // The height follows the page change, on whole pixels (smoothly with Subpixel glide)
            height: panel.glidePx(card.mainH + (card.subH - card.mainH) * panel.pageT)
            clip: true

            Item {
                id: mainPage

                width: card.width
                height: card.mainH
                x: -card.width * panel.pageT
                visible: panel.pageT < 1
                layer.enabled: panel.pageT > 0 && panel.pageT < 1
                layer.smooth: true

                Flickable {
                    id: flick

                    anchors.fill: parent
                    anchors.margins: Theme.padLg
                    contentWidth: width
                    contentHeight: col.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: col

                        width: flick.width
                        spacing: 18

                        // Header: profile picture, name and uptime, four plain buttons without background on the right.
                        // Clicking the picture or the name opens Settings > System > Profile.
                        Item {
                            width: col.width
                            height: 38

                            // Hover box glides from button to button
                            HoverGlide {
                                id: headGlide

                                color: Theme.hover
                                radius: Theme.radiusSm
                            }

                            Avatar {
                                id: headAvatar

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                size: 38
                                hovered: profileArea.containsMouse
                            }

                            Column {
                                id: headName

                                anchors.left: headAvatar.right
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Txt {
                                    text: User.name
                                    font.pixelSize: Theme.fontSize + 1
                                    font.weight: Theme.uiWeightStrong
                                }

                                Txt {
                                    text: "up " + SysInfo.formatUptime(SysInfo.uptime)
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontSm
                                }
                            }

                            MouseArea {
                                id: profileArea

                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: headName.x + headName.width
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Ui.openSettings("profile", Ui.panelScreen)
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                IconButton {
                                    size: 34
                                    iconSize: Theme.iconSize - 1
                                    fg: Theme.textDim
                                    glide: headGlide
                                    icon: Icons.reload
                                    onClicked: Quickshell.reload(false)
                                }

                                IconButton {
                                    size: 34
                                    iconSize: Theme.iconSize - 1
                                    fg: Theme.textDim
                                    glide: headGlide
                                    icon: Icons.cog
                                    onClicked: Ui.open("settings", Ui.panelScreen)
                                }

                                IconButton {
                                    size: 34
                                    iconSize: Theme.iconSize - 1
                                    fg: Theme.textDim
                                    glide: headGlide
                                    icon: Icons.lock
                                    onClicked: {
                                        Ui.close();
                                        Quickshell.execDetached(["sh", "-c", Config.opts.lockCommand]);
                                    }
                                }

                                IconButton {
                                    size: 34
                                    iconSize: Theme.iconSize - 1
                                    fg: Theme.textDim
                                    glide: headGlide
                                    icon: Icons.power
                                    onClicked: Ui.open("power", Ui.panelScreen)
                                }
                            }
                        }

                        // Quick settings
                        Item {
                            width: col.width
                            height: tileGrid.height

                            // Hover box glides from tile to tile (like the selection in the launcher)
                            HoverGlide {
                                id: tileGlide

                                color: Theme.fill
                                radius: Theme.radius
                            }

                            Grid {
                                id: tileGrid

                                width: col.width
                                columns: 2
                                columnSpacing: 8
                                rowSpacing: 8

                                // Click: own sub page, right click: on/off
                                Tile {
                                    width: (col.width - 8) / 2
                                    glide: tileGlide
                                    icon: Net.icon()
                                    title: Net.connected ? (Net.wifi ? "Wi-Fi" : "Ethernet") : "Wi-Fi"
                                    subtitle: Net.connected ? (Net.limited ? "No internet" : Net.name) : (Net.nm && !Net.wifiEnabled ? "Off" : "Disconnected")
                                    active: Net.connected
                                    chevron: true
                                    onClicked: panel.page = "wifi"
                                    onRightClicked: Net.setWifiEnabled(!Net.wifiEnabled)
                                }

                                Tile {
                                    width: (col.width - 8) / 2
                                    glide: tileGlide
                                    icon: Bt.enabled ? Icons.bluetooth : Icons.bluetoothOff
                                    title: "Bluetooth"
                                    subtitle: !Bt.available ? "No adapter" : (!Bt.enabled ? "Off" : (Bt.connected.length > 0 ? Bt.connected[0].name : "On"))
                                    active: Bt.enabled
                                    chevron: true
                                    onClicked: panel.page = "bluetooth"
                                    onRightClicked: Bt.toggle()
                                }

                                Tile {
                                    width: (col.width - 8) / 2
                                    glide: tileGlide
                                    icon: Notifs.dnd ? Icons.bellOff : Icons.bell
                                    title: "Do not disturb"
                                    subtitle: Notifs.dnd ? "On" : "Off"
                                    active: Notifs.dnd
                                    onClicked: Notifs.toggleDnd()
                                }

                                Tile {
                                    width: (col.width - 8) / 2
                                    glide: tileGlide
                                    icon: Icons.moon
                                    title: "Night light"
                                    subtitle: !NightLight.installed ? "hyprsunset missing" : (NightLight.active ? NightLight.temperature + " K" : "Off")
                                    active: NightLight.active
                                    opacity: NightLight.installed ? 1 : 0.5
                                    onClicked: NightLight.toggle()
                                }

                                Tile {
                                    width: (col.width - 8) / 2
                                    glide: tileGlide
                                    icon: Audio.micMuted ? Icons.micOff : Icons.mic
                                    title: "Microphone"
                                    subtitle: !Audio.hasSource ? "No device" : (Audio.micMuted ? "Muted" : Math.round(Audio.micVolume * 100) + "%")
                                    active: Audio.hasSource && !Audio.micMuted
                                    onClicked: Audio.toggleMicMute()
                                }
                            }
                        }

                        // Sound: no box, heading with the output device, the sliders below
                        Column {
                            id: audioCol

                            width: col.width
                            spacing: 6

                            Item {
                                width: audioCol.width
                                height: 20

                                Txt {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Sound"
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontSm
                                    font.weight: Theme.uiWeightStrong
                                }

                                Txt {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, audioCol.width - 90)
                                    horizontalAlignment: Text.AlignRight
                                    text: Audio.sinkName
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontSm
                                }
                            }

                            Row {
                                width: audioCol.width
                                spacing: 8

                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 32
                                    fg: Audio.muted ? Theme.textMuted : Theme.textDim
                                    icon: Audio.icon()
                                    onClicked: Audio.toggleMute()
                                }

                                SliderBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: audioCol.width - 32 - 44 - 16
                                    value: Audio.muted ? 0 : Audio.volume
                                    enabled: Audio.hasSink
                                    onMoved: v => Audio.setVolume(v)
                                }

                                FixedText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 44
                                    horizontalAlignment: Text.AlignRight
                                    text: Math.round(Audio.volume * 100) + "%"
                                    color: Audio.muted ? Theme.textMuted : Theme.textDim
                                    font.pixelSize: Theme.fontSm + 1
                                }
                            }

                            // Per-app volume: small expander below the volume slider (like the volume mixer on
                            // Windows). Only apps that currently have an audio stream open (see Audio.apps). The height
                            // grows in whole pixels (smoothly with Subpixel glide), the rows fade in.
                            Item {
                                id: mixer

                                property real openT: panel.mixerOpen ? 1 : 0

                                width: audioCol.width
                                height: mixerHead.height + panel.glidePx((mixerCol.implicitHeight + 6) * mixer.openT)
                                clip: mixer.openT > 0 && mixer.openT < 1

                                Behavior on openT {
                                    Anim {
                                        duration: Theme.ctlMed
                                        easing.bezierCurve: Theme.curveSmooth
                                    }
                                }

                                // Header: "Apps", count, arrow. Text aligned with the start of the sliders.
                                Rectangle {
                                    id: mixerHead

                                    x: 32
                                    width: mixerHeadRow.implicitWidth + 16
                                    height: 24
                                    radius: Theme.radiusSm
                                    color: mixerHeadArea.pressed ? Theme.fillStrong : (mixerHeadArea.containsMouse ? Theme.fill : "transparent")

                                    Behavior on color {
                                        CAnim {}
                                    }

                                    Row {
                                        id: mixerHeadRow

                                        x: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        Txt {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Apps"
                                            color: mixerHeadArea.containsMouse ? Theme.fg : Theme.textMuted
                                            font.pixelSize: Theme.fontSm
                                        }

                                        FixedText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: Audio.apps.length > 0
                                            text: Audio.apps.length
                                            color: Theme.textMuted
                                            font.pixelSize: Theme.fontSm
                                        }

                                        Glyph {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Icons.down
                                            rotation: 180 * mixer.openT
                                            color: mixerHeadArea.containsMouse ? Theme.fg : Theme.textMuted
                                            font.pixelSize: Theme.fontSm + 2
                                        }
                                    }

                                    MouseArea {
                                        id: mixerHeadArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: panel.mixerOpen = !panel.mixerOpen
                                    }
                                }

                                // Hover box glides between the app icons
                                HoverGlide {
                                    id: mixerGlide

                                    color: Theme.hover
                                    radius: Theme.radiusSm
                                }

                                Column {
                                    id: mixerCol

                                    y: mixerHead.height + 6
                                    width: parent.width
                                    spacing: 6
                                    visible: mixer.openT > 0
                                    opacity: mixer.openT

                                    // One row like the volume above: app icon (click = mute), name above the
                                    // slider, value on the right
                                    Repeater {
                                        model: ScriptModel {
                                            values: Audio.appKeys
                                        }

                                        delegate: Row {
                                            id: appRow

                                            required property var modelData
                                            readonly property var app: Audio.app(appRow.modelData)
                                            readonly property var node: appRow.app && appRow.app.nodes.length > 0 ? appRow.app.nodes[0] : null
                                            readonly property bool appMuted: !!(appRow.node && appRow.node.audio && appRow.node.audio.muted)
                                            readonly property real appVolume: appRow.node && appRow.node.audio ? appRow.node.audio.volume : 0

                                            width: audioCol.width
                                            spacing: 8

                                            IconButton {
                                                anchors.verticalCenter: parent.verticalCenter
                                                size: 32
                                                glide: mixerGlide
                                                onClicked: Audio.toggleAppMute(appRow.modelData)

                                                AppIcon {
                                                    anchors.centerIn: parent
                                                    width: 20
                                                    height: 20
                                                    icon: appRow.app ? appRow.app.icon : ""
                                                    fallback: appRow.app ? appRow.app.name : "?"
                                                    monochrome: true
                                                    opacity: appRow.appMuted ? 0.35 : 0.9

                                                    Behavior on opacity {
                                                        Anim {
                                                            duration: Theme.ctlFast
                                                        }
                                                    }
                                                }
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: audioCol.width - 32 - 44 - 16
                                                spacing: 0

                                                Txt {
                                                    width: parent.width
                                                    text: appRow.app ? appRow.app.name : ""
                                                    color: appRow.appMuted ? Theme.textMuted : Theme.textDim
                                                    font.pixelSize: Theme.fontXs
                                                }

                                                SliderBar {
                                                    width: parent.width
                                                    value: appRow.appMuted ? 0 : appRow.appVolume
                                                    onMoved: v => Audio.setAppVolume(appRow.modelData, v)
                                                }
                                            }

                                            FixedText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 44
                                                horizontalAlignment: Text.AlignRight
                                                text: Math.round(appRow.appVolume * 100) + "%"
                                                color: appRow.appMuted ? Theme.textMuted : Theme.textDim
                                                font.pixelSize: Theme.fontSm + 1
                                            }
                                        }
                                    }

                                    Txt {
                                        x: 40
                                        width: parent.width - 40
                                        height: 24
                                        visible: Audio.apps.length === 0
                                        verticalAlignment: Text.AlignVCenter
                                        text: "No apps playing audio"
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.fontSm
                                    }
                                }
                            }

                            Row {
                                width: audioCol.width
                                spacing: 8
                                visible: Audio.hasSource
                                layer.enabled: panel.mixerGliding
                                layer.smooth: true

                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 32
                                    fg: Audio.micMuted ? Theme.textMuted : Theme.textDim
                                    icon: Audio.micMuted ? Icons.micOff : Icons.mic
                                    onClicked: Audio.toggleMicMute()
                                }

                                SliderBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: audioCol.width - 32 - 44 - 16
                                    value: Audio.micMuted ? 0 : Audio.micVolume
                                    onMoved: v => Audio.setMicVolume(v)
                                }

                                FixedText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 44
                                    horizontalAlignment: Text.AlignRight
                                    text: Math.round(Audio.micVolume * 100) + "%"
                                    color: Audio.micMuted ? Theme.textMuted : Theme.textDim
                                    font.pixelSize: Theme.fontSm + 1
                                }
                            }
                        }

                        MediaCard {
                            width: col.width
                            visible: Media.player !== null
                            layer.enabled: panel.mixerGliding
                            layer.smooth: true
                        }

                        // Notifications
                        Column {
                            width: col.width
                            spacing: 10
                            layer.enabled: panel.mixerGliding
                            layer.smooth: true

                            Item {
                                width: col.width
                                height: 24

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Notifications"
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.fontSm
                                        font.weight: Theme.uiWeightStrong
                                    }

                                    FixedText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: Notifs.count > 0
                                        text: Notifs.count
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.fontSm
                                    }
                                }

                                // Plain text button instead of an icon with a label
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: clearLabel.implicitWidth + 16
                                    height: 24
                                    radius: Theme.radiusSm
                                    visible: Notifs.count > 0
                                    color: clearArea.pressed ? Theme.fillStrong : (clearArea.containsMouse ? Theme.fill : "transparent")

                                    Behavior on color {
                                        CAnim {}
                                    }

                                    Txt {
                                        id: clearLabel

                                        anchors.centerIn: parent
                                        text: "Clear all"
                                        color: clearArea.containsMouse ? Theme.fg : Theme.textDim
                                        font.pixelSize: Theme.fontSm
                                    }

                                    MouseArea {
                                        id: clearArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Notifs.clearAll()
                                    }
                                }
                            }

                            Column {
                                width: col.width
                                spacing: 6

                                Repeater {
                                    model: Array.from(Notifs.list).reverse()

                                    delegate: NotifCard {
                                        required property var modelData

                                        width: col.width
                                        notif: modelData
                                        compact: true
                                    }
                                }
                            }

                            Txt {
                                x: 2
                                width: col.width - 4
                                height: 28
                                visible: Notifs.count === 0
                                text: "Nothing new"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSm + 1
                            }
                        }
                    }
                }
            }

            Item {
                id: subPage

                width: card.width
                height: card.subH
                x: card.width * (1 - panel.pageT)
                visible: panel.pageT > 0
                layer.enabled: panel.pageT > 0 && panel.pageT < 1
                layer.smooth: true

                Flickable {
                    id: subFlick

                    anchors.fill: parent
                    anchors.margins: Theme.padLg
                    contentWidth: width
                    contentHeight: pageLoader.height
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Loader {
                        id: pageLoader

                        width: subFlick.width
                        active: panel.shownPage !== ""
                        sourceComponent: panel.shownPage === "bluetooth" ? btPage : wifiPage
                    }
                }
            }
        }
    }

    Component {
        id: wifiPage

        WifiPage {
            active: panel.open && panel.page === "wifi"
            onBack: panel.page = ""
        }
    }

    Component {
        id: btPage

        BluetoothPage {
            active: panel.open && panel.page === "bluetooth"
            onBack: panel.page = ""
        }
    }
}
