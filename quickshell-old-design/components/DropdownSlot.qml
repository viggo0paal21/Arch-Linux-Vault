import QtQuick
import qs.config
import qs.services

// Area right below the bar. When opening, the whole panel slides down from under
// the bar, and back up when closing. The area is clipped at the bar's
// bottom edge, so it looks as if it comes out from behind the bar.
Item {
    id: root

    property real progress: 0
    property real contentHeight: 0
    default property alias content: inner.data

    readonly property real fullHeight: root.contentHeight + Theme.gap + 2

    // Closed: fixed target value instead of the running dock animation. Otherwise the invisibly mapped
    // fullscreen panel redraws on every frame of the docking (stutter when switching workspaces / opening windows).
    y: root.progress > 0 ? Ui.barBottom : Ui.barBottomTarget
    height: root.fullHeight
    clip: true

    Item {
        id: inner

        // closed: fully above (behind the bar), open: just below the bar.
        // Glides between pixels like the bar: while moving, the content is drawn once
        // sharply into a texture and that is moved smoothly. At rest it sits on whole pixels without a texture.
        y: Theme.gap - root.fullHeight * (1 - root.progress)
        width: parent.width
        height: root.contentHeight
        layer.enabled: root.progress > 0 && root.progress < 1
        layer.smooth: true
    }
}
