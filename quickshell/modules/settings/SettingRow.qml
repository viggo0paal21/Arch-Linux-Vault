import QtQuick
import qs.config
import qs.components

// One row in the settings panel: text on the left, control on the right. No box of its own anymore, the rows
// of a page are separated by fine lines like a list.
Item {
    id: root

    property string label: ""
    property string description: ""
    property int controlWidth: 260
    default property alias control: slot.data

    // First visible row of a page: no line above it
    readonly property bool first: {
        const p = root.parent;
        if (!p)
            return true;
        const kids = p.children;
        for (let i = 0; i < kids.length; i++) {
            if (kids[i].visible && kids[i].height > 0)
                return kids[i] === root;
        }
        return true;
    }

    implicitHeight: Math.max(60, texts.implicitHeight + 26)

    // Separator in the middle of the gap above the row (the pages have 10 px between rows)
    Rectangle {
        y: -6
        width: parent.width
        height: 1
        visible: !root.first
        color: Theme.hairline
    }

    Column {
        id: texts

        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.right: slot.left
        anchors.rightMargin: 28
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Txt {
            width: parent.width
            text: root.label
        }

        Txt {
            width: parent.width
            visible: root.description !== ""
            text: root.description
            color: Theme.textMuted
            font.pixelSize: Theme.fontSm
            wrapMode: Text.Wrap
        }
    }

    Item {
        id: slot

        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.controlWidth
        height: childrenRect.height
    }
}
