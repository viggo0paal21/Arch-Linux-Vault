import QtQuick
import qs.config

Rectangle {
    property bool vertical: false

    implicitWidth: vertical ? 1 : 10
    implicitHeight: vertical ? 10 : 1
    color: Theme.border
}
