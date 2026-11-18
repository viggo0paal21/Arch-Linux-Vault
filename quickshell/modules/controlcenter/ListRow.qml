import QtQuick
import qs.config
import qs.components

// One row on the Wi-Fi/Bluetooth page, styled like the tiles: just the icon (active = accent color), title,
// subtitle. On the right a sign at rest (e.g. a checkmark), the actions on hover.
// It can expand below (e.g. a password field), the height grows in whole pixels (smoothly with Subpixel glide).
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool clickable: true
    property string trailing: ""
    property bool expanded: false
    property alias actions: actionsRow.data
    default property alias detail: detailCol.data

    readonly property int rowHeight: 52
    readonly property bool hovered: hover.hovered
    // Shared gliding hover box of the list (HoverGlide), only over the row itself (not the expanded part)
    property Item glide: null
    readonly property bool glideDown: area.pressed && root.clickable
    readonly property int glideHeight: root.rowHeight
    property real openT: root.expanded ? 1 : 0

    signal clicked
    signal rightClicked

    // Whole pixels, smooth with "Subpixel glide"
    implicitHeight: Config.opts.barGlide ? root.rowHeight + (detailCol.implicitHeight + 10) * root.openT : Math.round(root.rowHeight + (detailCol.implicitHeight + 10) * root.openT)
    clip: root.openT > 0 && root.openT < 1
    // When a row above expands, this one lands between two pixels with "Subpixel glide": drawn as an image
    // meanwhile (text sharp) and shifted smoothly, without the image again on whole pixels
    layer.enabled: Config.opts.barGlide && root.y !== Math.round(root.y)
    layer.smooth: true

    Behavior on openT {
        Anim {
            duration: Theme.ctlMed
            easing.bezierCurve: Theme.curveSmooth
        }
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (root.glide)
                hovered && root.clickable ? root.glide.enter(root) : root.glide.leave(root);
        }
    }

    Rectangle {
        width: parent.width
        height: root.rowHeight
        radius: Theme.radius
        color: root.glide ? "transparent" : (area.pressed && root.clickable ? Theme.pressed : (root.clickable && hover.hovered ? Theme.fill : "transparent"))

        Behavior on color {
            CAnim {}
        }
    }

    MouseArea {
        id: area

        width: parent.width
        height: root.rowHeight
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: ev => {
            if (ev.button === Qt.RightButton)
                root.rightClicked();
            else if (root.clickable)
                root.clicked();
        }
    }

    Item {
        id: chip

        x: 10
        y: (root.rowHeight - height) / 2
        width: 30
        height: 30

        Glyph {
            anchors.centerIn: parent
            text: root.icon
            color: root.active ? Theme.accent : Theme.textMuted
            font.pixelSize: Theme.iconSize + 2
        }
    }

    Column {
        anchors.left: chip.right
        anchors.leftMargin: 11
        anchors.right: side.left
        anchors.rightMargin: 10
        y: Math.round((root.rowHeight - height) / 2)
        spacing: 1

        Txt {
            width: parent.width
            text: root.title
            font.pixelSize: Theme.fontSm + 1
        }

        Txt {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            color: root.active ? Theme.textDim : Theme.textMuted
            font.pixelSize: Theme.fontSm - 1
        }
    }

    // Right side: sign at rest, actions on hover (same spot)
    Item {
        id: side

        readonly property bool showActions: root.hovered && actionsRow.visibleChildren.length > 0

        anchors.right: parent.right
        anchors.rightMargin: 6
        y: (root.rowHeight - height) / 2
        width: Math.max(root.trailing !== "" ? 30 : 0, side.showActions ? actionsRow.implicitWidth : 0)
        height: 30

        Glyph {
            anchors.centerIn: parent
            visible: opacity > 0
            opacity: root.trailing !== "" && !side.showActions ? 1 : 0
            text: root.trailing
            color: Theme.accent
            font.pixelSize: Theme.iconSize

            Behavior on opacity {
                Anim {
                    duration: Theme.ctlFast
                }
            }
        }

        Row {
            id: actionsRow

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            opacity: side.showActions ? 1 : 0
            enabled: side.showActions

            Behavior on opacity {
                Anim {
                    duration: Theme.ctlFast
                }
            }
        }
    }

    Column {
        id: detailCol

        x: chip.x + chip.width + 11
        y: root.rowHeight + 2
        width: parent.width - x - 6
        spacing: 6
        visible: root.expanded || root.openT > 0
        opacity: root.openT
    }
}
