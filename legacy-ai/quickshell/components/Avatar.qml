import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services

// Profile picture (services/User.qml) as a rounded square, no circles. A new picture fades in over the old one
// (the old one stays fully visible below, nothing shines through halfway). No picture: first letter of the name.
Item {
    id: root

    property int size: 40
    property int radius: Theme.radius
    // Fine edge, brighter on hover (hover set from outside)
    property bool hovered: false
    readonly property string source: User.faceUrl
    readonly property bool hasImage: imgA.status === Image.Ready || imgB.status === Image.Ready

    property int front: 0
    property Item incoming: null

    function show() {
        // No picture found anymore: letter instead of picture
        if (root.source === "") {
            fade.stop();
            root.incoming = null;
            imgA.source = "";
            imgB.source = "";
            return;
        }
        const inc = root.front === 0 ? imgB : imgA;
        const old = inc === imgA ? imgB : imgA;
        fade.stop();
        inc.opacity = 0;
        inc.z = 1;
        old.z = 0;
        root.incoming = inc;
        inc.source = root.source;
    }

    function fadeIn(img) {
        fade.target = img;
        fade.start();
        root.front = img === imgA ? 0 : 1;
    }

    implicitWidth: root.size
    implicitHeight: root.size
    width: root.size
    height: root.size
    onSourceChanged: root.show()
    Component.onCompleted: {
        if (root.source !== "")
            root.show();
    }

    NumberAnimation {
        id: fade

        property: "opacity"
        from: 0
        to: 1
        duration: Theme.durMed
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curveSmooth
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.fillStrong

        Txt {
            anchors.centerIn: parent
            text: User.name.charAt(0).toUpperCase()
            color: Theme.textDim
            font.pixelSize: Math.round(root.size * 0.42)
            font.weight: Theme.uiWeightStrong
            opacity: root.hasImage ? 0 : 1

            Behavior on opacity {
                Anim {
                    duration: Theme.durMed
                }
            }
        }

        Image {
            id: imgA

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            mipmap: true
            sourceSize: Qt.size(root.size * 2, root.size * 2)
            opacity: 0
            onStatusChanged: {
                if (status === Image.Ready && root.incoming === imgA)
                    root.fadeIn(imgA);
            }
        }

        Image {
            id: imgB

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            mipmap: true
            sourceSize: Qt.size(root.size * 2, root.size * 2)
            opacity: 0
            onStatusChanged: {
                if (status === Image.Ready && root.incoming === imgB)
                    root.fadeIn(imgB);
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: root.hovered ? Theme.hairlineStrong : Theme.hairline

        Behavior on border.color {
            CAnim {}
        }
    }
}
