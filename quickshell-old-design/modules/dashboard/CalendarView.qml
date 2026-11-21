import QtQuick
import qs.config
import qs.components

// Month calendar (week starts on Monday). Today = filled white. Scroll flips months.
Item {
    id: root

    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var days: {
        const first = new Date(root.year, root.month, 1);
        const offset = (first.getDay() + 6) % 7;
        const start = new Date(root.year, root.month, 1 - offset);
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === root.month,
                isToday: d.getFullYear() === root.today.getFullYear() && d.getMonth() === root.today.getMonth() && d.getDate() === root.today.getDate()
            });
        }
        return out;
    }

    function shift(delta) {
        let m = root.month + delta;
        let y = root.year;
        while (m < 0) {
            m += 12;
            y -= 1;
        }
        while (m > 11) {
            m -= 12;
            y += 1;
        }
        root.month = m;
        root.year = y;
    }

    function reset() {
        root.today = new Date();
        root.year = root.today.getFullYear();
        root.month = root.today.getMonth();
    }

    implicitWidth: 7 * 38
    implicitHeight: head.height + 8 + weekRow.height + 6 * 34

    Item {
        id: head

        width: parent.width
        height: 32

        Txt {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: root.monthNames[root.month] + " " + root.year
            font.weight: Theme.weightStrong

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.reset()
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            IconButton {
                size: 28
                icon: Icons.left
                onClicked: root.shift(-1)
            }

            IconButton {
                size: 28
                icon: Icons.right
                onClicked: root.shift(1)
            }
        }
    }

    Row {
        id: weekRow

        anchors.top: head.bottom
        anchors.topMargin: 8
        height: 24

        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

            delegate: Txt {
                required property var modelData

                width: root.width / 7
                height: 24
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.fgMuted
                font.pixelSize: Theme.fontSm
            }
        }
    }

    Grid {
        anchors.top: weekRow.bottom
        columns: 7

        Repeater {
            model: root.days

            delegate: Item {
                id: cell

                required property var modelData

                width: root.width / 7
                height: 34

                Rectangle {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: Theme.radiusSm
                    color: cell.modelData.isToday ? Theme.accent : "transparent"
                }

                Txt {
                    anchors.centerIn: parent
                    text: cell.modelData.day
                    color: cell.modelData.isToday ? Theme.accentFg : (cell.modelData.inMonth ? Theme.fg : Theme.fgMuted)
                    font.weight: cell.modelData.isToday ? Theme.weightStrong : Theme.weight
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: ev => root.shift(ev.angleDelta.y > 0 ? -1 : 1)
    }
}
