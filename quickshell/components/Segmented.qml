import QtQuick
import qs.config

// Pick one of a few options side by side: one shared track, the active option gets a lighter background.
// The bright highlight glides to the new option, the slightly dimmer hover box glides along under the mouse
// (like the selection in the launcher).
// options: [{ value: "off", label: "Off" }, ...]
Item {
    id: root

    property var options: []
    property string value: ""
    property int spacing: 2

    signal picked(string value)

    readonly property int activeIndex: {
        for (let i = 0; i < root.options.length; i++) {
            if (root.options[i].value === root.value)
                return i;
        }
        return -1;
    }
    // Hover and selection box share one layer that is drawn as a whole with the opacity of the selection box
    // (inside it the selection is fully opaque, the hover box proportionally): where both overlap while gliding,
    // the white doesn't add up, the brighter one simply wins. Without glass boxAlpha is 1.
    readonly property real boxAlpha: Theme.fillStrong.a
    function boxColor(c) {
        return Qt.rgba(c.r, c.g, c.b, Math.min(1, c.a / root.boxAlpha));
    }
    readonly property int segWidth: Math.floor((root.width - 6 - root.spacing * (root.options.length - 1)) / Math.max(1, root.options.length))

    implicitWidth: row.implicitWidth + 6
    implicitHeight: 34

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm + 2
        color: Theme.fill
    }

    // Hover and selection box as one layer (see boxAlpha): no brighter stripe where they overlap
    Item {
        anchors.fill: parent
        opacity: root.boxAlpha
        layer.enabled: root.boxAlpha < 1

        // Hover: appears right under the mouse (fades in), then glides from option to option
        Rectangle {
            id: hoverBox

            property int idx: 0

            x: 3 + hoverBox.idx * (root.segWidth + root.spacing)
            y: 3
            width: root.segWidth
            height: root.height - 6
            radius: Theme.radiusSm
            color: root.boxColor(Theme.fill)
            opacity: area.containsMouse ? 1 : 0

            Behavior on x {
                enabled: hoverBox.opacity > 0.01

                SmoothedAnimation {
                    velocity: 400
                    duration: Theme.ctlFast
                }
            }
            Behavior on opacity {
                Anim {
                    duration: Theme.ctlFast
                }
            }
        }

        // Bright highlight of the active option
        Rectangle {
            x: 3 + Math.max(0, root.activeIndex) * (root.segWidth + root.spacing)
            y: 3
            width: root.segWidth
            height: root.height - 6
            radius: Theme.radiusSm
            color: root.boxColor(Theme.fillStrong)
            opacity: root.activeIndex >= 0 ? 1 : 0

            Behavior on x {
                SmoothedAnimation {
                    velocity: 400
                    duration: Theme.ctlFast
                }
            }
            Behavior on opacity {
                Anim {
                    duration: Theme.ctlFast
                }
            }
        }
    }

    Row {
        id: row

        x: 3
        y: 3
        spacing: root.spacing

        Repeater {
            model: root.options

            delegate: Item {
                id: seg

                required property var modelData
                readonly property bool active: seg.modelData.value === root.value

                width: root.segWidth
                height: root.height - 6

                Txt {
                    anchors.centerIn: parent
                    text: seg.modelData.label
                    color: seg.active ? Theme.fg : Theme.textDim
                    font.pixelSize: Theme.fontSm + 1
                    font.weight: seg.active ? Theme.uiWeightStrong : Theme.uiWeight

                    Behavior on color {
                        CAnim {}
                    }
                }
            }
        }
    }

    // One mouse area over all options (including the gaps between them): the hover box glides without flickering
    MouseArea {
        id: area

        function indexAt(mx) {
            return Math.max(0, Math.min(root.options.length - 1, Math.floor((mx - 3 + root.spacing / 2) / (root.segWidth + root.spacing))));
        }

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: hoverBox.idx = indexAt(mouseX)
        onPositionChanged: mouse => hoverBox.idx = indexAt(mouse.x)
        onClicked: mouse => {
            const o = root.options[indexAt(mouse.x)];
            if (o)
                root.picked(o.value);
        }
    }
}
