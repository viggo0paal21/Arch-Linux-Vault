import QtQuick
import qs.config

// Frame like the boxes in fastfetch: thin line with square corners, the title sits centered in the top
// edge ("──── Sound ────"). The line is broken around the title instead of being covered by a background,
// so the blur behind it stays visible. Children stack in "inner" (width = inner width).
Item {
    id: root

    property string title: ""
    property int padding: 12
    property int spacing: 8
    property color lineColor: Theme.line
    default property alias content: inner.data
    readonly property int innerWidth: inner.width

    implicitHeight: inner.implicitHeight + Math.round(head.height / 2) + 12 + root.padding

    // Title in the edge: whole pixels, so line and text stay sharp
    Txt {
        id: head

        x: Math.round((root.width - width) / 2)
        y: 0
        visible: root.title !== ""
        text: root.title
        color: root.lineColor
        font.pixelSize: Theme.fontSm
        font.weight: Theme.uiWeightStrong
    }

    // Top edge left and right of the title
    Rectangle {
        x: 0
        y: Math.round(head.height / 2)
        width: root.title !== "" ? head.x - 8 : root.width
        height: 1
        color: root.lineColor
    }

    Rectangle {
        x: head.x + head.width + 8
        y: Math.round(head.height / 2)
        width: root.width - x
        height: 1
        visible: root.title !== ""
        color: root.lineColor
    }

    // Sides and bottom
    Rectangle {
        x: 0
        y: Math.round(head.height / 2)
        width: 1
        height: root.height - y
        color: root.lineColor
    }

    Rectangle {
        x: root.width - 1
        y: Math.round(head.height / 2)
        width: 1
        height: root.height - y
        color: root.lineColor
    }

    Rectangle {
        x: 0
        y: root.height - 1
        width: root.width
        height: 1
        color: root.lineColor
    }

    Column {
        id: inner

        x: root.padding
        y: Math.round(head.height / 2) + 12
        width: root.width - 2 * root.padding
        spacing: root.spacing
    }
}
