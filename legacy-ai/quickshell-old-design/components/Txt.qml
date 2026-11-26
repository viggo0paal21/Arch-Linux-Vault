import QtQuick
import qs.config

Text {
    color: Theme.fg
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.weight: Theme.weight
    font.italic: false
    renderType: Theme.smooth ? Text.QtRendering : Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight

    Behavior on color {
        CAnim {}
    }
}
