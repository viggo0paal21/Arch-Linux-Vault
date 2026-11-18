import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import Quickshell.Services.Notifications

// One notification. As a popup with a timeout bar (pauses on hover),
// compact in the history. All accesses are guarded in case the app already closed it.
Rectangle {
    id: root

    property var notif: null
    property bool popup: false
    property bool compact: false
    property real remaining: 1

    readonly property string appName: root.notif ? (root.notif.appName || "") : ""
    readonly property string summary: root.notif ? (root.notif.summary || "") : ""
    readonly property string body: root.notif ? (root.notif.body || "") : ""
    readonly property bool critical: root.notif ? root.notif.urgency === NotificationUrgency.Critical : false
    readonly property var actions: root.notif ? Array.from(root.notif.actions).filter(a => a.identifier !== "default") : []
    readonly property var defaultAction: {
        if (!root.notif)
            return null;
        for (const a of root.notif.actions) {
            if (a.identifier === "default")
                return a;
        }
        return null;
    }
    readonly property int timeout: root.notif && root.popup ? Notifs.timeoutFor(root.notif) : 0

    implicitHeight: content.implicitHeight + 28
    radius: root.popup ? Theme.radiusLg : Theme.radius
    // Popup: its own glass surface with a hairline. In the control center: just a light background, no border.
    color: root.popup ? Glass.popupBg : (hover.hovered ? Theme.fillStrong : Theme.fill)
    border.width: root.popup || root.critical ? 1 : 0
    border.color: root.critical ? Theme.accent : Theme.hairline
    clip: true

    // While sliding in/out, x/y lie between two pixels. The card is then drawn sharply into a texture once
    // and that texture is moved subpixel, like the bar. At rest it sits on whole pixels without a texture
    // (the counter offset then evens out remainders below one pixel).
    readonly property bool gliding: root.popup && (root.x !== 0 || root.opacity < 1 || root.y !== Math.round(root.y))

    layer.enabled: root.gliding
    layer.smooth: true

    transform: Translate {
        x: root.gliding ? 0 : Math.round(root.x) - root.x
        y: root.gliding ? 0 : Math.round(root.y) - root.y
    }

    Behavior on border.color {
        CAnim {}
    }
    Behavior on color {
        enabled: !root.popup

        CAnim {}
    }

    HoverHandler {
        id: hover
    }

    NumberAnimation {
        target: root
        property: "remaining"
        from: 1
        to: 0
        duration: Math.max(1, root.timeout)
        running: root.popup && root.timeout > 0
        paused: running && hover.hovered
        onFinished: Notifs.removePopup(root.notif)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: ev => {
            if (ev.button === Qt.MiddleButton) {
                Notifs.dismiss(root.notif);
                return;
            }
            if (root.defaultAction) {
                root.defaultAction.invoke();
                Notifs.removePopup(root.notif);
            } else if (root.popup) {
                Notifs.removePopup(root.notif);
            }
        }
    }

    Row {
        id: content

        x: 14
        y: 14
        width: parent.width - 28
        spacing: 12

        AppIcon {
            width: root.compact ? 32 : 40
            height: width
            icon: root.notif ? Notifs.iconFor(root.notif) : ""
            fallback: root.appName || root.summary || "?"
        }

        Column {
            width: parent.width - (root.compact ? 32 : 40) - 12
            spacing: 4

            Item {
                width: parent.width
                height: 18

                Txt {
                    anchors.left: parent.left
                    anchors.right: closeBtn.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.appName + (Notifs.timeOf(root.notif) !== "" ? "  ·  " + Notifs.timeOf(root.notif) : "")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSm - 1
                }

                IconButton {
                    id: closeBtn

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    size: 22
                    iconSize: Theme.fontSize + 1
                    fg: Theme.textDim
                    icon: Icons.close
                    opacity: hover.hovered ? 1 : 0
                    onClicked: Notifs.dismiss(root.notif)

                    Behavior on opacity {
                        Anim {
                            duration: Theme.ctlFast
                        }
                    }
                }
            }

            Txt {
                width: parent.width
                visible: text !== ""
                text: root.summary
                font.weight: Theme.uiWeightStrong
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }

            Text {
                width: parent.width
                visible: root.body !== ""
                text: root.body
                textFormat: Text.StyledText
                color: Theme.textDim
                linkColor: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSm + 1
                font.weight: Theme.uiWeight
                lineHeight: 1.1
                renderType: Theme.smooth ? Text.QtRendering : Text.NativeRendering
                wrapMode: Text.Wrap
                maximumLineCount: root.compact ? 3 : 5
                elide: Text.ElideRight
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                width: parent.width
                spacing: 6
                visible: root.actions.length > 0
                topPadding: 4

                Repeater {
                    model: root.actions

                    delegate: Rectangle {
                        id: actionBtn

                        required property var modelData

                        width: actionLabel.implicitWidth + 24
                        height: 28
                        radius: Theme.radiusSm
                        color: actionArea.pressed || actionArea.containsMouse ? Theme.pressed : Theme.fillStrong

                        Behavior on color {
                            CAnim {}
                        }

                        Txt {
                            id: actionLabel

                            anchors.centerIn: parent
                            text: actionBtn.modelData.text || actionBtn.modelData.identifier
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.uiWeightStrong
                        }

                        MouseArea {
                            id: actionArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                actionBtn.modelData.invoke();
                                Notifs.removePopup(root.notif);
                            }
                        }
                    }
                }
            }
        }
    }

    // Timeout bar at the bottom
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.radius
        height: 2
        width: (parent.width - 2 * root.radius) * root.remaining
        visible: root.popup && root.timeout > 0
        color: Theme.hairlineStrong
    }
}
