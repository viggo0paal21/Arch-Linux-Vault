import QtQuick
import qs.config

// While the wallpaper colors fade (WallColors.fading), the color follows instantly: otherwise this
// animation would restart on every frame of the fade, barely move with its slow-starting curve and
// only jump to the new color at the end (no visible transition at all, e.g. on the workspaces).
ColorAnimation {
    duration: WallColors.fading ? 0 : Theme.ctlFast
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve
}
