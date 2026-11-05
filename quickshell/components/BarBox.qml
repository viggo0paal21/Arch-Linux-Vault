import QtQuick
import qs.config

// Box behind a group in the bar (Settings > Bar > Group boxes), exactly as big as the group.
Rectangle {
    required property Item row
    required property Item target

    visible: Config.opts.barBoxes && target.visible && target.width > 0
    x: row.x + target.x
    y: row.y + target.y
    width: target.width
    height: target.height
    radius: Theme.radiusSm
    antialiasing: true
    color: Config.opts.barBoxColor

    Behavior on color {
        CAnim {}
    }
}
