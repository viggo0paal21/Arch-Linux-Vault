import QtQuick
import Quickshell
import qs.config
import qs.components

BarChip {
    id: root

    readonly property string timeFormat: Config.opts.clock24h ? (Config.opts.clockSeconds ? "HH:mm:ss" : "HH:mm") : (Config.opts.clockSeconds ? "h:mm:ss AP" : "h:mm AP")

    spacing: 10

    SystemClock {
        id: clock

        precision: Config.opts.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Txt {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(clock.date, root.timeFormat)
        color: root.fg
    }

    Txt {
        anchors.verticalCenter: parent.verticalCenter
        visible: Config.opts.barShowDate
        text: clock.date.toLocaleString(Qt.locale("en_US"), "ddd, MMM d")
        color: root.fgDim
    }
}
