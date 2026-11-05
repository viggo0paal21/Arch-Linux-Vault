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

    y: Ui.barBottom
    height: root.fullHeight
    clip: true

    Item {
        id: inner

        // closed: completely above (behind the bar), open: just below the bar
        // round to whole pixels: text stays sharp in every frame while sliding
        y: Theme.px(Theme.gap - root.fullHeight * (1 - root.progress))
        width: parent.width
        height: root.contentHeight
    }
}
