import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// App launcher. Type = search, arrows/Tab = select, Enter = launch.
// "=" calculates (result goes to the clipboard), ">" runs a command.
OverlayPanel {
    id: panel

    readonly property string query: search.text
    readonly property string mode: query.startsWith("=") ? "calc" : (query.startsWith(">") ? "cmd" : "apps")
    readonly property var calcResult: mode === "calc" ? Apps.calc(query.slice(1)) : null

    readonly property var results: {
        if (panel.mode === "calc") {
            return [
                {
                    kind: "calc",
                    title: panel.calcResult === null ? "Type a calculation …" : String(panel.calcResult),
                    subtitle: panel.calcResult === null ? "e.g. =12*(3+4)^2" : "Enter copies the result"
                }
            ];
        }
        if (panel.mode === "cmd") {
            const cmd = panel.query.slice(1).trim();
            return [
                {
                    kind: "cmd",
                    title: cmd === "" ? "Type a command …" : cmd,
                    subtitle: "Enter runs the command (sh -c)"
                }
            ];
        }
        return Apps.query(panel.query).slice(0, 60).map(e => ({
                    kind: "app",
                    title: e.name,
                    subtitle: e.genericName || e.comment || "",
                    entry: e
                }));
    }

    property int current: 0

    function activate(index) {
        const r = panel.results[index];
        if (!r)
            return;
        if (r.kind === "app") {
            Apps.launch(r.entry);
        } else if (r.kind === "calc") {
            if (panel.calcResult === null)
                return;
            Quickshell.clipboardText = String(panel.calcResult);
        } else if (r.kind === "cmd") {
            const cmd = panel.query.slice(1).trim();
            if (cmd === "")
                return;
            Apps.runCommand(cmd);
        }
        Ui.close();
    }

    function move(delta) {
        const n = panel.results.length;
        if (n === 0)
            return;
        panel.current = (panel.current + delta + n) % n;
        list.positionViewAtIndex(panel.current, ListView.Contain);
    }

    open: Ui.panel === "launcher"
    screen: Ui.panelScreen
    dim: true
    dimOpacity: 0.4
    ns: "qs-launcher"
    onDismissed: Ui.close()
    onResultsChanged: panel.current = 0
    onOpenChanged: {
        if (open) {
            search.text = "";
            panel.current = 0;
            search.forceActiveFocus();
        }
    }

    Card {
        id: card

        readonly property int rowHeight: 52
        readonly property int visibleRows: Math.min(8, Math.max(1, panel.results.length))

        // Fade in + short glide, subpixel like the bar: drawn as a texture while moving (text stays sharp),
        // at rest on whole pixels without a texture
        x: Math.round((parent.width - width) / 2)
        y: Math.round(parent.height * 0.16) - 14 * (1 - panel.progress)
        width: Math.min(620, parent.width - 40)
        property real h: header.height + list.height + 25

        height: h
        opacity: panel.progress
        layer.enabled: panel.progress > 0 && panel.progress < 1
        layer.smooth: true

        Behavior on h {
            Anim {
                duration: Theme.ctlFast
                easing.bezierCurve: Theme.curveSmooth
            }
        }

        // Search row: no box of its own, just a hairline to the results
        Item {
            id: header

            x: 12
            y: 6
            width: parent.width - 24
            height: 54

            Glyph {
                id: modeIcon

                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: panel.mode === "calc" ? Icons.calculator : (panel.mode === "cmd" ? Icons.terminal : Icons.search)
                color: Theme.textMuted
            }

            Txt {
                id: modeHint

                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === ""
                text: "=  calculate      >  run"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSm
            }

            TextInput {
                id: search

                anchors.left: modeIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                focus: true
                color: Theme.fg
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentFg
                font.family: Theme.font
                font.pixelSize: Theme.fontLg
                font.weight: Theme.uiWeight
                renderType: Theme.smooth ? Text.QtRendering : Text.NativeRendering
                clip: true

                Keys.onDownPressed: panel.move(1)
                Keys.onUpPressed: panel.move(-1)
                Keys.onTabPressed: panel.move(1)
                Keys.onBacktabPressed: panel.move(-1)
                Keys.onReturnPressed: panel.activate(panel.current)
                Keys.onEnterPressed: panel.activate(panel.current)
                Keys.onPressed: ev => {
                    if (ev.key === Qt.Key_PageDown) {
                        panel.move(5);
                        ev.accepted = true;
                    } else if (ev.key === Qt.Key_PageUp) {
                        panel.move(-5);
                        ev.accepted = true;
                    } else if ((ev.modifiers & Qt.ControlModifier) && ev.key === Qt.Key_J) {
                        panel.move(1);
                        ev.accepted = true;
                    } else if ((ev.modifiers & Qt.ControlModifier) && ev.key === Qt.Key_K) {
                        panel.move(-1);
                        ev.accepted = true;
                    }
                }

                Txt {
                    anchors.fill: parent
                    visible: search.text === ""
                    text: "Search"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontLg
                }
            }
        }

        Rectangle {
            anchors.top: header.bottom
            width: parent.width
            height: 1
            color: Theme.hairline
        }

        ListView {
            id: list

            anchors.top: header.bottom
            anchors.topMargin: 7
            x: 12
            width: parent.width - 24
            height: card.visibleRows * card.rowHeight
            clip: true
            model: panel.results
            currentIndex: panel.current
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: Theme.ctlFast
            highlightFollowsCurrentItem: true

            highlight: Rectangle {
                width: list.width
                radius: Theme.radius
                color: Theme.fillStrong
            }

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                width: list.width
                height: card.rowHeight

                AppIcon {
                    id: appIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    visible: row.modelData.kind === "app"
                    icon: row.modelData.kind === "app" ? (row.modelData.entry.icon || "") : ""
                    fallback: row.modelData.title
                }

                Glyph {
                    anchors.centerIn: appIcon
                    visible: row.modelData.kind !== "app"
                    text: row.modelData.kind === "calc" ? Icons.calculator : Icons.terminal
                    color: Theme.textDim
                    font.pixelSize: 22
                }

                Column {
                    anchors.left: appIcon.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Txt {
                        width: parent.width
                        text: row.modelData.title
                        color: row.index === panel.current ? Theme.fg : Theme.textDim

                        Behavior on color {
                            CAnim {}
                        }
                    }

                    Txt {
                        width: parent.width
                        visible: text !== ""
                        text: row.modelData.subtitle
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSm - 1
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: panel.current = row.index
                    onClicked: panel.activate(row.index)
                }
            }
        }

        Txt {
            anchors.centerIn: list
            visible: panel.mode === "apps" && panel.results.length === 0
            text: "No matches"
            color: Theme.textMuted
        }
    }
}
