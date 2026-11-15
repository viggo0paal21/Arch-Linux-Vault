import QtQuick
import qs.config

NumberAnimation {
    duration: Theme.ctlMed
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve
}
