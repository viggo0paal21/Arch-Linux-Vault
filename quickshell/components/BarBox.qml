import QtQuick
import qs.config

// Box behind a group in the bar (Settings > Bar > Group boxes), exactly as big as the group.
Rectangle {
    id: root

    required property Item row
    required property Item target
    // Subpixel glide: same leftover offset as the group's row (otherwise 0)
    property real shiftX: 0
    property real shiftY: 0

    visible: Config.opts.barBoxes && target.visible && target.width > 0
    x: row.x + target.x
    y: row.y + target.y
    width: target.width
    height: target.height
    radius: Theme.radiusSm
    antialiasing: true
    color: Config.opts.barBoxColor
    transform: Translate {
        x: root.shiftX
        y: root.shiftY
    }

    Behavior on color {
        CAnim {}
    }
}
