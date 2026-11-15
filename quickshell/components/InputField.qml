import QtQuick
import qs.config

// Single-line text field. Commits the value on Enter or when leaving the field.
Rectangle {
    id: root

    property string text: ""
    property string placeholder: ""
    property alias input: field

    signal committed(string value)

    implicitHeight: 34
    implicitWidth: 220
    radius: Theme.radiusSm
    color: field.activeFocus ? Theme.fillStrong : Theme.fill
    // No border at rest, a fine bright edge while typing
    border.width: 1
    border.color: field.activeFocus ? Theme.hairline : "transparent"

    Behavior on border.color {
        CAnim {}
    }
    Behavior on color {
        CAnim {}
    }

    onTextChanged: {
        if (!field.activeFocus)
            field.text = root.text;
    }

    TextInput {
        id: field

        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        text: root.text
        color: Theme.fg
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentFg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.weight: Theme.uiWeight
        renderType: Theme.smooth ? Text.QtRendering : Text.NativeRendering
        selectByMouse: true
        onAccepted: root.committed(text)
        onActiveFocusChanged: {
            if (!activeFocus && text !== root.text)
                root.committed(text);
        }

        Txt {
            anchors.fill: parent
            visible: field.text === "" && !field.activeFocus
            text: root.placeholder
            color: Theme.textMuted
        }
    }
}
