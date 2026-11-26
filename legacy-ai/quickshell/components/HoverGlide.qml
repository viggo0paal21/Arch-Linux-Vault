import QtQuick
import qs.config

// Shared hover box for a group (buttons, tiles, list rows): appears right under the mouse
// (fades in) and then glides from item to item, like the selection in the launcher and in the settings.
// Put it into a plain Item (not directly into a Row/Column/Grid: those hide children without a size), before
// the items so the box lies behind them. The items may be nested deeper, e.g. in a Row next to it.
// The items get "glide: <id>" and register themselves on hover (enter/leave).
// Optional on the item: glideDown (currently pressed), glideHeight (height of the box, e.g. only the row without
// the expanded part below it).
Item {
    id: root

    property color color: Theme.fill
    property color downColor: Theme.pressed
    property real radius: Theme.radius
    // Item under the mouse (null = none) and the last one shown (the box stays there while fading out)
    property Item target: null
    property Item shown: null

    readonly property bool down: root.target !== null && root.target.glideDown === true
    // Position, size and opacity of the shown item in our own coordinates. Position and size of the item and its
    // parent item are read too, so the box follows when the layout changes.
    // If the item disappears, the last position stays (the box then fades out in place).
    property var last: ({
            x: 0,
            y: 0,
            w: 0,
            h: 0,
            o: 1
        })
    readonly property var geo: {
        const s = root.shown;
        if (!s)
            return root.last;
        const par = s.parent;
        const deps = [s.x, s.y, s.width, s.height, s.opacity, par ? par.x : 0, par ? par.y : 0, par ? par.width : 0];
        const p = s.mapToItem(root, 0, 0);
        return {
            x: p.x,
            y: p.y,
            w: s.width,
            h: s.glideHeight !== undefined ? s.glideHeight : s.height,
            o: s.opacity
        };
    }

    onGeoChanged: {
        if (root.shown)
            root.last = root.geo;
    }

    function enter(item) {
        hideDelay.stop();
        root.target = item;
        root.shown = item;
    }

    function leave(item) {
        if (root.target === item)
            hideDelay.restart();
    }

    width: 0
    height: 0

    // Wait briefly before the box fades out: when the mouse crosses the gap to the neighbour, it simply glides on
    // instead of fading for a moment
    Timer {
        id: hideDelay

        interval: 80
        onTriggered: root.target = null
    }

    Rectangle {
        id: box

        property real fade: root.target !== null && root.target.visible && root.target.enabled ? 1 : 0

        x: root.geo.x
        y: root.geo.y
        width: root.geo.w
        height: root.geo.h
        radius: root.radius
        color: root.down ? root.downColor : root.color
        // A half transparent item (e.g. a button that can't be used right now) also gets a fainter box
        opacity: box.fade * root.geo.o
        visible: box.opacity > 0

        Behavior on fade {
            Anim {
                duration: Theme.ctlFast
            }
        }
        Behavior on x {
            enabled: box.fade > 0.01

            SmoothedAnimation {
                velocity: 400
                duration: Theme.ctlFast
            }
        }
        Behavior on y {
            enabled: box.fade > 0.01

            SmoothedAnimation {
                velocity: 400
                duration: Theme.ctlFast
            }
        }
        Behavior on width {
            enabled: box.fade > 0.01

            SmoothedAnimation {
                velocity: 400
                duration: Theme.ctlFast
            }
        }
        Behavior on height {
            enabled: box.fade > 0.01

            SmoothedAnimation {
                velocity: 400
                duration: Theme.ctlFast
            }
        }
        Behavior on color {
            CAnim {}
        }
    }
}
