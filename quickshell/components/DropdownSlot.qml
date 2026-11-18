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
    // The sliding inner part (for content that moves in with "parent:", e.g. the launcher)
    readonly property alias contentItem: inner

    readonly property real fullHeight: root.contentHeight + Theme.gap + 2

    // Closed: fixed target value instead of the running dock animation. Otherwise the invisibly mapped
    // fullscreen panel redraws on every frame of the docking (stutter when switching workspaces / opening windows).
    y: root.progress > 0 ? Ui.barBottom : Ui.barBottomTarget
    height: root.fullHeight
    clip: true

    Item {
        id: inner

        readonly property real exactY: Theme.gap - root.fullHeight * (1 - root.progress)

        // closed: fully above (behind the bar), open: just below the bar.
        // With "Subpixel glide" it glides between pixels like the bar: while moving, the content is drawn
        // sharply into a texture once and that is moved smoothly. Without: whole pixels, no texture.
        // At rest it always sits on whole pixels without a texture.
        y: Config.opts.barGlide ? inner.exactY : Math.round(inner.exactY)
        width: parent.width
        height: root.contentHeight
        layer.enabled: Config.opts.barGlide && root.progress > 0 && root.progress < 1
        layer.smooth: true
    }
}
