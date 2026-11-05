import QtQuick
import qs.config

// Box hinter einer Gruppe in der Leiste (Settings > Bar > Group boxes), genau so gross wie die Gruppe.
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
