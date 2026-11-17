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
    // Optional: an app icon on the left (black and white), e.g. in the tab Apps > Opacity
    property string appIcon: ""
    // Greyed out and not usable (e.g. "Transparent when empty" with Group boxes)
    property bool locked: false
    default property alias control: slot.data
    // Height of the texts on the left (for rows with their own implicitHeight)
    readonly property real textsHeight: texts.implicitHeight

    // First visible row of a page or right below a section title: no line above
    readonly property bool first: {
        const p = root.parent;
        if (!p)
            return true;
        const kids = p.children;
        let prev = null;
        for (let i = 0; i < kids.length; i++) {
            const k = kids[i];
            if (k === root)
                break;
            if (k.visible && k.height > 0)
                prev = k;
        }
        return prev === null || prev.isHeader === true;
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

    AppIcon {
        id: appIconImg

        x: 2
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        visible: root.appIcon !== ""
        icon: root.appIcon
        fallback: root.label
        monochrome: true
    }

    Column {
        id: texts

        anchors.left: parent.left
        anchors.leftMargin: root.appIcon !== "" ? 2 + 30 + 14 : 2
        opacity: root.locked ? 0.5 : 1
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
        enabled: !root.locked
        opacity: root.locked ? 0.4 : 1
    }
}
