import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// App launcher. Type = search, arrows/Tab = select, Enter = launch.
// "=" calculates (result goes to the clipboard), ">" runs a command.
// Settings > Bar > Launcher position: "center" = exactly in the middle of the screen (fades in and glides a little),
// "logo" = slides out from under the bar at the launcher logo, just like the dashboard and control center
// (same animation, speed and curves as those two).
OverlayPanel {
    id: panel

    readonly property bool fromLogo: Config.opts.launcherPosition === "logo"

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
    dim: !panel.fromLogo
    dimOpacity: 0.4
    ns: "qs-launcher"
    animDuration: panel.fromLogo ? Theme.durSlow : Theme.durMed
    animGroup: panel.fromLogo ? "panel" : "overlay"
    onDismissed: Ui.close()
    onResultsChanged: panel.current = 0
    onOpenChanged: {
        if (open) {
            search.text = "";
            panel.current = 0;
            search.forceActiveFocus();
        }
    }

    // Center: area covering the whole screen, the card sits centered in it
    Item {
        id: centerHost

        anchors.fill: parent
    }

    // From the logo: slides out from under the bar, left-aligned below the logo (like the control center on the right)
    DropdownSlot {
        id: slot

        anchors.left: parent.left
        anchors.leftMargin: Theme.gap
        width: card.width
        visible: panel.fromLogo
        contentHeight: card.height
        progress: panel.fromLogo ? panel.progress : 0
    }

    Card {
        id: card

        readonly property int rowHeight: 52
        readonly property int visibleRows: Math.min(8, Math.max(1, panel.results.length))
        // Height with a full list: the centering is based on it. Fewer results -> the card gets shorter at the bottom,
        // the search field stays in place.
        readonly property real fullH: header.height + 8 * card.rowHeight + 25
        readonly property real centerY: Math.round((centerHost.height - card.fullH) / 2) - 14 * (1 - panel.progress)

        parent: panel.fromLogo ? slot.contentItem : centerHost
        // Center: fade in + short glide. With "Subpixel glide" between pixels like the bar (drawn as a texture while
        // moving, text stays sharp), otherwise whole pixels. At rest always on whole pixels without a texture.
        // From the logo: movement, texture and clipping at the bar are done by the DropdownSlot.
        x: panel.fromLogo ? 0 : Math.round((centerHost.width - width) / 2)
        y: panel.fromLogo ? 0 : (Config.opts.barGlide ? card.centerY : Math.round(card.centerY))
        width: Math.min(620, centerHost.width - 40)
        property real h: header.height + list.height + 25

        height: h
        opacity: panel.fromLogo ? 1 : panel.progress
        layer.enabled: !panel.fromLogo && Config.opts.barGlide && panel.progress > 0 && panel.progress < 1
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
