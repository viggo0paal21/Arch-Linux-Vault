import QtQuick
import qs.config

NumberAnimation {
    duration: Theme.durMed
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve
}
