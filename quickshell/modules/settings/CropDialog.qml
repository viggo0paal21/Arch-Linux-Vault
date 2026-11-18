import QtQuick
import qs.config
import qs.components

// Crop the profile picture (Settings > System > Profile), the classic way: square crop area in the middle,
// move the picture below it (drag) and zoom (mouse wheel at the mouse position, slider, - and + buttons).
// Darkened outside the crop area, rule-of-thirds lines while dragging. Zoom and position glide briefly (like the
// sliders), while dragging the picture follows the mouse directly. "Use picture" saves exactly the visible area as an
// outSize x outSize PNG (grabToImage) and reports the path (applied).
Item {
    id: root

    property string file: ""
    property bool open: false
    property string outPath: ""
    property int outSize: 256

    signal applied(string path)
    signal canceled

    readonly property int stageSize: 420
    readonly property int cropSize: 336
    readonly property real cropLeft: (root.stageSize - root.cropSize) / 2
    readonly property real maxZoom: 5

    // State: zoom (1 = crop area just filled) and the picture point in the middle of the crop area (0..1)
    property real zoom: 1
    property real cx: 0.5
    property real cy: 0.5
    property bool dragging: false
    property bool saving: false
    property string error: ""

    // Loaded picture size (capped at 2048, huge pictures would take too much memory otherwise)
    readonly property real iw: outer.implicitWidth
    readonly property real ih: outer.implicitHeight
    readonly property bool ready: outer.status === Image.Ready && root.iw > 0 && root.ih > 0
    readonly property real base: root.ready ? Math.max(root.cropSize / root.iw, root.cropSize / root.ih) : 1

    // Shown values glide after the target, not while dragging
    property real shownZoom: root.zoom
    property real shownCx: root.cx
    property real shownCy: root.cy
    readonly property real shownW: root.iw * root.base * root.shownZoom
    readonly property real shownH: root.ih * root.base * root.shownZoom
    // Position of the picture on the stage, always so that the crop area is completely filled
    readonly property real imgX: Math.max(root.cropLeft + root.cropSize - root.shownW, Math.min(root.cropLeft, root.stageSize / 2 - root.shownCx * root.shownW))
    readonly property real imgY: Math.max(root.cropLeft + root.cropSize - root.shownH, Math.min(root.cropLeft, root.stageSize / 2 - root.shownCy * root.shownH))

    Behavior on shownZoom {
        enabled: !root.dragging

        Anim {
            duration: Theme.ctlFast
            easing.bezierCurve: Theme.curveSmooth
        }
    }
    Behavior on shownCx {
        enabled: !root.dragging

        Anim {
            duration: Theme.ctlFast
            easing.bezierCurve: Theme.curveSmooth
        }
    }
    Behavior on shownCy {
        enabled: !root.dragging

        Anim {
            duration: Theme.ctlFast
            easing.bezierCurve: Theme.curveSmooth
        }
    }

    // Limit the center so the crop area stays inside the picture
    function clampC(v, z, dim) {
        const s = root.base * z * dim;
        const h = s > 0 ? (root.cropSize / 2) / s : 0.5;
        return h >= 0.5 ? 0.5 : Math.max(h, Math.min(1 - h, v));
    }

    // Zoom around a point of the stage (mx, my): the picture point there stays in place
    function zoomTo(nz, mx, my) {
        if (!root.ready)
            return;
        const z = Math.max(1, Math.min(root.maxZoom, nz));
        const c = root.stageSize / 2;
        const px = root.cx + (mx - c) / (root.iw * root.base * root.zoom);
        const py = root.cy + (my - c) / (root.ih * root.base * root.zoom);
        root.cx = root.clampC(px - (mx - c) / (root.iw * root.base * z), z, root.iw);
        root.cy = root.clampC(py - (my - c) / (root.ih * root.base * z), z, root.ih);
        root.zoom = z;
    }

    function reset() {
        root.dragging = true;
        root.zoom = 1;
        root.cx = 0.5;
        root.cy = 0.5;
        root.error = "";
        root.saving = false;
        root.dragging = false;
    }

    function cancel() {
        root.open = false;
        root.canceled();
    }

    // Only once zoom and position have settled: save exactly the crop area
    function apply() {
        if (!root.ready || root.saving)
            return;
        root.saving = true;
        root.error = "";
        grabDelay.restart();
    }

    function grab() {
        const ok = cropView.grabToImage(r => {
            const saved = r.saveToFile(root.outPath);
            root.saving = false;
            if (saved) {
                root.open = false;
                root.applied(root.outPath);
            } else {
                root.error = "Could not save the cropped picture";
            }
        }, Qt.size(root.outSize, root.outSize));
        if (!ok) {
            root.saving = false;
            root.error = "Could not crop this picture";
        }
    }

    onFileChanged: root.reset()
    onOpenChanged: {
        if (root.open)
            root.reset();
    }

    visible: opacity > 0
    enabled: root.open
    opacity: root.open ? 1 : 0

    Behavior on opacity {
        Anim {
            duration: Theme.ctlMed
            easing.bezierCurve: Theme.curveSmooth
        }
    }

    Timer {
        id: grabDelay

        interval: Theme.ctlFast + 40
        onTriggered: root.grab()
    }

    // Darken the settings behind, a click next to the dialog cancels
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Qt.rgba(0, 0, 0, 0.55)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: root.cancel()
            onWheel: ev => ev.accepted = true
        }
    }

    Rectangle {
        id: dialog

        anchors.centerIn: parent
        width: root.stageSize + 48
        height: dialogCol.implicitHeight + 48
        radius: Theme.radiusLg
        color: Qt.rgba(0.035, 0.035, 0.035, 0.97)
        border.width: 1
        border.color: Theme.hairlineStrong
        scale: root.open ? 1 : 0.97

        Behavior on scale {
            Anim {
                duration: Theme.ctlMed
                easing.bezierCurve: Theme.curveSmooth
            }
        }

        // Don't pass clicks inside the dialog through to the darkening
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: dialogCol

            x: 24
            y: 24
            width: root.stageSize
            spacing: 16

            Column {
                width: parent.width
                spacing: 3

                Txt {
                    text: "Crop picture"
                    font.pixelSize: Theme.fontLg + 2
                    font.weight: Theme.uiWeightStrong
                }

                Txt {
                    width: parent.width
                    text: root.error !== "" ? root.error : (outer.status === Image.Error ? "This image could not be opened" : "Drag to move, scroll or use the slider to zoom")
                    color: root.error !== "" ? Theme.fg : Theme.textMuted
                    font.pixelSize: Theme.fontSm
                    elide: Text.ElideRight
                }
            }

            // Stage: picture, darkened edge, crop area
            Rectangle {
                id: stage

                width: root.stageSize
                height: root.stageSize
                radius: Theme.radius
                color: Theme.fill
                clip: true

                // Whole picture (visible outside, darkened)
                Image {
                    id: outer

                    x: root.imgX
                    y: root.imgY
                    width: root.shownW
                    height: root.shownH
                    source: root.file !== "" ? "file://" + root.file : ""
                    sourceSize: Qt.size(2048, 2048)
                    asynchronous: true
                    autoTransform: true
                    smooth: true
                    mipmap: true
                    opacity: root.ready ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            duration: Theme.durMed
                        }
                    }
                }

                // Crop area: the same picture at full brightness, exactly this item gets saved
                Item {
                    id: cropView

                    x: root.cropLeft
                    y: root.cropLeft
                    width: root.cropSize
                    height: root.cropSize
                    clip: true
                    opacity: root.ready ? 1 : 0

                    Image {
                        x: root.imgX - root.cropLeft
                        y: root.imgY - root.cropLeft
                        width: root.shownW
                        height: root.shownH
                        source: outer.source
                        sourceSize: outer.sourceSize
                        asynchronous: true
                        autoTransform: true
                        smooth: true
                        mipmap: true
                    }
                }

                // Darken outside the crop area (four strips)
                Rectangle {
                    width: parent.width
                    height: root.cropLeft
                    color: Qt.rgba(0, 0, 0, 0.6)
                }
                Rectangle {
                    y: root.cropLeft + root.cropSize
                    width: parent.width
                    height: root.cropLeft
                    color: Qt.rgba(0, 0, 0, 0.6)
                }
                Rectangle {
                    y: root.cropLeft
                    width: root.cropLeft
                    height: root.cropSize
                    color: Qt.rgba(0, 0, 0, 0.6)
                }
                Rectangle {
                    x: root.cropLeft + root.cropSize
                    y: root.cropLeft
                    width: root.cropLeft
                    height: root.cropSize
                    color: Qt.rgba(0, 0, 0, 0.6)
                }

                // Frame of the crop area, rule-of-thirds lines while dragging
                Rectangle {
                    x: root.cropLeft
                    y: root.cropLeft
                    width: root.cropSize
                    height: root.cropSize
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.7)

                    Item {
                        anchors.fill: parent
                        opacity: root.dragging ? 1 : 0

                        Behavior on opacity {
                            Anim {
                                duration: Theme.ctlFast
                            }
                        }

                        Repeater {
                            model: 2

                            Rectangle {
                                required property int index

                                x: Math.round(root.cropSize * (index + 1) / 3)
                                width: 1
                                height: parent.height
                                color: Qt.rgba(1, 1, 1, 0.35)
                            }
                        }

                        Repeater {
                            model: 2

                            Rectangle {
                                required property int index

                                y: Math.round(root.cropSize * (index + 1) / 3)
                                width: parent.width
                                height: 1
                                color: Qt.rgba(1, 1, 1, 0.35)
                            }
                        }
                    }
                }

                // Still loading
                Glyph {
                    anchors.centerIn: parent
                    visible: !root.ready && outer.status === Image.Loading
                    text: Icons.refresh
                    color: Theme.textMuted

                    RotationAnimation on rotation {
                        running: outer.status === Image.Loading
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                    }
                }

                MouseArea {
                    property real startX: 0
                    property real startY: 0
                    property real startCx: 0.5
                    property real startCy: 0.5

                    anchors.fill: parent
                    enabled: root.ready && !root.saving
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    preventStealing: true
                    onPressed: ev => {
                        root.dragging = true;
                        startX = ev.x;
                        startY = ev.y;
                        startCx = root.cx;
                        startCy = root.cy;
                    }
                    onPositionChanged: ev => {
                        if (!pressed)
                            return;
                        root.cx = root.clampC(startCx - (ev.x - startX) / (root.iw * root.base * root.zoom), root.zoom, root.iw);
                        root.cy = root.clampC(startCy - (ev.y - startY) / (root.ih * root.base * root.zoom), root.zoom, root.ih);
                    }
                    onReleased: root.dragging = false
                    onCanceled: root.dragging = false
                    onWheel: ev => root.zoomTo(root.zoom * Math.pow(1.0015, ev.angleDelta.y), ev.x, ev.y)
                }
            }

            // Zoom: - slider +
            Item {
                width: parent.width
                height: 30

                IconButton {
                    id: zoomOut

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    size: 30
                    icon: Icons.minus
                    iconSize: Theme.fontSm + 2
                    fg: Theme.textDim
                    onClicked: root.zoomTo(root.zoom / 1.25, root.stageSize / 2, root.stageSize / 2)
                }

                SliderBar {
                    anchors.left: zoomOut.right
                    anchors.leftMargin: 10
                    anchors.right: zoomIn.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: root.ready
                    value: (root.zoom - 1) / (root.maxZoom - 1)
                    onMoved: v => root.zoomTo(1 + v * (root.maxZoom - 1), root.stageSize / 2, root.stageSize / 2)
                }

                IconButton {
                    id: zoomIn

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    size: 30
                    icon: Icons.plus
                    iconSize: Theme.fontSm + 2
                    fg: Theme.textDim
                    onClicked: root.zoomTo(root.zoom * 1.25, root.stageSize / 2, root.stageSize / 2)
                }
            }

            // Cancel / apply
            Item {
                width: parent.width
                height: 34

                IconButton {
                    id: applyBtn

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    size: 34
                    icon: root.saving ? Icons.refresh : Icons.check
                    iconSize: Theme.fontSm + 2
                    label: "Use picture"
                    active: true
                    enabled: root.ready && !root.saving
                    opacity: enabled || root.saving ? 1 : 0.4
                    onClicked: root.apply()
                }

                IconButton {
                    anchors.right: applyBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    size: 34
                    label: "Cancel"
                    idleColor: Theme.fill
                    fg: Theme.textDim
                    onClicked: root.cancel()
                }
            }
        }
    }
}
