import QtQuick
import qs.config
import qs.components

// Schieberegler mit echtem Wertebereich und Anzeige rechts.
Item {
    id: root

    property real from: 0
    property real to: 1
    property real stepSize: 1
    property real value: 0
    property int decimals: 0
    property string suffix: ""

    signal edited(real v)

    width: parent ? parent.width : 240
    height: 26

    function snap(v) {
        const raw = root.from + v * (root.to - root.from);
        const stepped = Math.round(raw / root.stepSize) * root.stepSize;
        return Math.max(root.from, Math.min(root.to, Number(stepped.toFixed(4))));
    }

    SliderBar {
        anchors.left: parent.left
        anchors.right: valueText.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        value: (root.value - root.from) / Math.max(0.0001, root.to - root.from)
        step: root.stepSize / Math.max(0.0001, root.to - root.from)
        onMoved: v => {
            const s = root.snap(v);
            if (s !== root.value)
                root.edited(s);
        }
    }

    Txt {
        id: valueText

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 54
        horizontalAlignment: Text.AlignRight
        text: root.value.toFixed(root.decimals) + root.suffix
        color: Theme.fgDim
    }
}
