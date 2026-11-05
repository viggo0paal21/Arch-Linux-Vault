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
    radius: Theme.radiusLg
    color: root.popup ? Glass.popupBg : Theme.layer2
    border.width: 1
    border.color: root.critical ? Theme.fg : (hover.hovered ? Theme.borderStrong : Theme.border)
    clip: true

    // While sliding in/out, x/y often sit between two pixels and the text shimmers.
    // The counter offset always draws the card on whole pixels.
    transform: Translate {
        x: Math.round(root.x) - root.x
        y: Math.round(root.y) - root.y
    }

    Behavior on border.color {
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
                    color: Theme.fgMuted
                    font.pixelSize: Theme.fontSm
                }

                IconButton {
                    id: closeBtn

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    size: 22
                    iconSize: Theme.fontSize + 1
                    icon: Icons.close
                    opacity: hover.hovered ? 1 : 0.5
                    onClicked: Notifs.dismiss(root.notif)
                }
            }

            Txt {
                width: parent.width
                visible: text !== ""
                text: root.summary
                font.weight: Theme.weightStrong
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }

            Text {
                width: parent.width
                visible: root.body !== ""
                text: root.body
                textFormat: Text.StyledText
                color: Theme.fgDim
                linkColor: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSm + 1
                font.weight: Theme.weight
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
                        color: actionArea.pressed ? Theme.pressed : (actionArea.containsMouse ? Theme.hover : Theme.layer3)
                        border.width: 1
                        border.color: Theme.border

                        Txt {
                            id: actionLabel

                            anchors.centerIn: parent
                            text: actionBtn.modelData.text || actionBtn.modelData.identifier
                            font.pixelSize: Theme.fontSm
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
        color: Theme.fgMuted
    }
}
