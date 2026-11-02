import QtQuick
import qs.config

ColorAnimation {
    duration: Theme.durFast
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve
}
