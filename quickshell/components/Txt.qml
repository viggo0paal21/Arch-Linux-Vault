import QtQuick
import qs.config

Text {
    color: Theme.fg
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    // Menus: Theme.uiWeight. The bar sets Theme.weight itself (texts in modules/bar).
    font.weight: Theme.uiWeight
    font.italic: false
    renderType: Theme.smooth ? Text.QtRendering : Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight

    Behavior on color {
        CAnim {}
    }
}
