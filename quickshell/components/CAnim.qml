import QtQuick
import qs.config

ColorAnimation {
    duration: Theme.ctlFast
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve
}
