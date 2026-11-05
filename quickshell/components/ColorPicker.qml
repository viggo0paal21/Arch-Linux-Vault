import QtQuick
import qs.config

// Moderner Farbwaehler: Saettigung/Helligkeit-Feld, Farbton- und Deckkraft-Regler, Hex-Feld und Vorlagen.
// Setzt "color" nicht selbst, sondern meldet picked("#RRGGBB" bzw. "#AARRGGBB").
Item {
    id: root

    property color color: "#1f1f1f"
    property var presets: ["#1f1f1f", "#2e2e2e", "#26ffffff", "#ffffff", "#ff453a", "#ff9f0a", "#ffd60a", "#30d158", "#64d2ff", "#0a84ff", "#5e5ce6", "#bf5af2"]

    // Eigener HSV-Zustand: Bei Grau/Schwarz geht der Farbton sonst verloren und das Feld springt.
    property real h: 0
    property real s: 0
    property real v: 0
    property real a: 1
    property bool internal: false

    signal picked(string value)

    implicitWidth: 360
    implicitHeight: col.implicitHeight

    function hex2(n) {
        const s = Math.round(Math.max(0, Math.min(1, n)) * 255).toString(16);
        return s.length < 2 ? "0" + s : s;
    }

    function toHex(c) {
        const rgb = hex2(c.r) + hex2(c.g) + hex2(c.b);
        return (c.a < 0.999 ? "#" + hex2(c.a) + rgb : "#" + rgb).toUpperCase();
    }

    function syncFrom(c) {
        if (root.internal)
            return;
        if (c.hsvHue >= 0)
            root.h = c.hsvHue;
        root.s = c.hsvSaturation;
        root.v = c.hsvValue;
        root.a = c.a;
    }

    function send() {
        root.internal = true;
        root.picked(root.toHex(Qt.hsva(root.h, root.s, root.v, root.a)));
        root.internal = false;
    }

    onColorChanged: syncFrom(root.color)
    Component.onCompleted: syncFrom(root.color)

    Column {
        id: col

        width: parent.width
        spacing: 12

        // Saettigung (links -> rechts) und Helligkeit (oben -> unten)
        Rectangle {
            id: sv

            width: parent.width
            height: 150
            radius: Theme.radiusSm
            color: Qt.hsva(root.h, 1, 1, 1)
            clip: true

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#ffffffff" }
                    GradientStop { position: 1; color: "#00ffffff" }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                border.width: 1
                border.color: Theme.borderStrong
                gradient: Gradient {
                    GradientStop { position: 0; color: "#00000000" }
                    GradientStop { position: 1; color: "#ff000000" }
                }
            }

            Rectangle {
                x: Math.round(root.s * sv.width - width / 2)
                y: Math.round((1 - root.v) * sv.height - height / 2)
                width: 16
                height: 16
                radius: 8
                color: Qt.hsva(root.h, root.s, root.v, 1)
                border.width: 2
                border.color: "#ffffff"

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: "#80000000"
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                preventStealing: true
                function pick(m) {
                    root.s = Math.max(0, Math.min(1, m.x / sv.width));
                    root.v = Math.max(0, Math.min(1, 1 - m.y / sv.height));
                    root.send();
                }
                onPressed: m => pick(m)
                onPositionChanged: m => {
                    if (pressed)
                        pick(m);
                }
            }
        }

        // Farbton
        Item {
            id: hueBar

            width: parent.width
            height: 16

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                border.width: 1
                border.color: Theme.borderStrong
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.000; color: "#ff0000" }
                    GradientStop { position: 0.167; color: "#ffff00" }
                    GradientStop { position: 0.333; color: "#00ff00" }
                    GradientStop { position: 0.500; color: "#00ffff" }
                    GradientStop { position: 0.667; color: "#0000ff" }
                    GradientStop { position: 0.833; color: "#ff00ff" }
                    GradientStop { position: 1.000; color: "#ff0000" }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round(root.h * (hueBar.width - width))
                width: 20
                height: 20
                radius: 10
                color: Qt.hsva(root.h, 1, 1, 1)
                border.width: 3
                border.color: "#ffffff"
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                function pick(m) {
                    root.h = Math.max(0, Math.min(0.9999, (m.x - 4) / hueBar.width));
                    root.send();
                }
                onPressed: m => pick(m)
                onPositionChanged: m => {
                    if (pressed)
                        pick(m);
                }
            }
        }

        // Deckkraft (Schachbrett zeigt Transparenz)
        Item {
            id: alphaBar

            width: parent.width
            height: 16

            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    const r = height / 2;
                    ctx.clearRect(0, 0, width, height);
                    ctx.save();
                    ctx.beginPath();
                    ctx.roundedRect(0, 0, width, height, r, r);
                    ctx.clip();
                    for (let x = 0; x < width; x += 6)
                        for (let y = 0; y < height; y += 6) {
                            ctx.fillStyle = ((x + y) / 6) % 2 === 0 ? "#3a3a3a" : "#1a1a1a";
                            ctx.fillRect(x, y, 6, 6);
                        }
                    ctx.restore();
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                border.width: 1
                border.color: Theme.borderStrong
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.hsva(root.h, root.s, root.v, 0) }
                    GradientStop { position: 1; color: Qt.hsva(root.h, root.s, root.v, 1) }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round(root.a * (alphaBar.width - width))
                width: 20
                height: 20
                radius: 10
                color: Qt.hsva(root.h, root.s, root.v, 1)
                border.width: 3
                border.color: "#ffffff"
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                function pick(m) {
                    root.a = Math.max(0, Math.min(1, (m.x - 4) / alphaBar.width));
                    root.send();
                }
                onPressed: m => pick(m)
                onPositionChanged: m => {
                    if (pressed)
                        pick(m);
                }
            }
        }

        // Vorschau, Hex-Feld, Deckkraft in %
        Row {
            width: parent.width
            spacing: 10

            Rectangle {
                width: 34
                height: 34
                radius: Theme.radiusSm
                color: root.color
                border.width: 1
                border.color: Theme.borderStrong
            }

            InputField {
                width: parent.width - 34 - 70 - 20
                text: root.toHex(root.color)
                placeholder: "#RRGGBB / #AARRGGBB"
                onCommitted: value => {
                    let t = value.trim();
                    if (t !== "" && t[0] !== "#")
                        t = "#" + t;
                    if (/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(t))
                        root.picked(t.toUpperCase());
                }
            }

            Txt {
                width: 70
                height: 34
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.a * 100) + " %"
                color: Theme.fgDim
            }
        }

        // Vorlagen
        Flow {
            width: parent.width
            spacing: 8

            Repeater {
                model: root.presets

                delegate: Rectangle {
                    required property string modelData

                    width: 26
                    height: 26
                    radius: 13
                    color: modelData
                    border.width: root.toHex(root.color) === modelData.toUpperCase() ? 2 : 1
                    border.color: root.toHex(root.color) === modelData.toUpperCase() ? Theme.fg : Theme.borderStrong

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked(parent.modelData.toUpperCase())
                    }
                }
            }
        }
    }
}
