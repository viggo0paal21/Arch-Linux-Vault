import QtQuick
import Quickshell.Io
import qs.config
import qs.components

// Font picker: field with the current font (written in that font), a click opens a searchable
// list of all installed font families (fc-list, read fresh on every open, runs in the background).
// The list lives on menuParent (the settings card), so the scroll area doesn't cut it off.
// The names in the list use the UI font (no font is loaded while scrolling), the font under
// the mouse shows a preview line at the bottom, only after a short pause (not on every pass).
// List and fields stay on whole pixels, opening only fades in (no movement).
Item {
    id: root

    property string value: ""
    property Item menuParent: null
    property Item scrollArea: null
    property bool active: true

    property var families: []
    property string hoverFamily: ""
    // Highlighted row (mouse or arrow keys). Deliberately not ListView.currentIndex: hovering the last,
    // half visible row would scroll the list on.
    property int sel: -1
    property string previewFamily: ""
    readonly property string query: search.text.trim().toLowerCase()
    readonly property var shown: root.query === "" ? root.families : root.families.filter(f => f.toLowerCase().indexOf(root.query) >= 0)

    signal picked(string family)

    implicitHeight: 34

    onActiveChanged: {
        if (!root.active)
            root.close();
    }
    onVisibleChanged: {
        if (!root.visible)
            root.close();
    }

    function openMenu() {
        if (!root.menuParent)
            return;
        lister.running = true;
        search.text = "";
        root.hoverFamily = "";
        root.previewFamily = "";
        root.place();
        menu.open = true;
        root.selectCurrent();
        search.forceActiveFocus();
    }

    function close() {
        if (!menu.open)
            return;
        menu.open = false;
        if (root.menuParent)
            root.menuParent.forceActiveFocus();
    }

    function choose(family) {
        root.close();
        if (family !== "" && family !== root.value)
            root.picked(family);
    }

    // Below the field, right aligned; if there's not enough room below, above it. Always whole pixels.
    function place() {
        const host = root.menuParent;
        const p = root.mapToItem(host, 0, 0);
        const h = Math.min(menu.fullHeight, host.height - 28);
        const below = p.y + root.height + 6;
        menu.height = h;
        menu.x = Math.round(Math.max(14, Math.min(p.x + root.width - menu.width, host.width - menu.width - 14)));
        menu.y = Math.round(below + h <= host.height - 14 ? below : Math.max(14, p.y - 6 - h));
    }

    function selectCurrent() {
        const i = root.shown.indexOf(root.value);
        root.sel = i;
        if (i >= 0)
            list.positionViewAtIndex(i, ListView.Center);
        else
            list.positionViewAtBeginning();
    }

    function moveSel(d) {
        if (root.shown.length === 0)
            return;
        root.sel = Math.max(0, Math.min(root.shown.length - 1, root.sel + d));
        list.positionViewAtIndex(root.sel, ListView.Contain);
    }

    Process {
        id: lister

        command: ["sh", "-c", "fc-list --format '%{family[0]}\\n' : family | sort -fu"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = this.text.split("\n").map(s => s.trim()).filter(s => s !== "" && !s.startsWith("."));
                if (names.join("\n") !== root.families.join("\n")) {
                    root.families = names;
                    if (menu.open && root.query === "")
                        root.selectCurrent();
                }
            }
        }
    }

    Timer {
        id: previewDelay

        interval: 160
        onTriggered: root.previewFamily = root.hoverFamily
    }

    Connections {
        target: root.scrollArea
        ignoreUnknownSignals: true

        function onContentYChanged() {
            root.close();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: fieldArea.pressed ? Theme.pressed : (menu.open || fieldArea.containsMouse ? Theme.fillStrong : Theme.fill)
        border.width: 1
        border.color: menu.open ? Theme.hairlineStrong : "transparent"

        Behavior on color {
            CAnim {}
        }

        Txt {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: chevron.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.value !== "" ? root.value : "…"
            font.family: root.value !== "" ? root.value : Theme.font
            font.pixelSize: Theme.fontSm + 1
        }

        Glyph {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.down
            color: Theme.textDim
            font.pixelSize: Theme.iconSize - 2
        }

        MouseArea {
            id: fieldArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.open ? root.close() : root.openMenu()
        }
    }

    // A click outside closes the list (sits below the list, above the rest of the card)
    MouseArea {
        parent: root.menuParent ? root.menuParent : root
        anchors.fill: parent
        z: 99
        visible: menu.open
        acceptedButtons: Qt.AllButtons
        onPressed: root.close()
    }

    Rectangle {
        id: menu

        property bool open: false
        readonly property int fullHeight: 48 + 10 * 34 + 44

        parent: root.menuParent ? root.menuParent : root
        z: 100
        width: Math.max(root.width, 340)
        visible: opacity > 0
        enabled: menu.open
        opacity: menu.open ? 1 : 0
        radius: Theme.radius
        color: "#090909"
        border.width: 1
        border.color: Theme.hairlineStrong

        Behavior on opacity {
            Anim {
                duration: Theme.ctlFast
            }
        }

        // Don't let own clicks through to the area below
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        // Suche
        Item {
            id: searchRow

            x: 6
            y: 6
            width: parent.width - 12
            height: 36

            Glyph {
                id: searchIcon

                x: 8
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.search
                color: Theme.textMuted
                font.pixelSize: Theme.iconSize - 2
            }

            TextInput {
                id: search

                anchors.left: searchIcon.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                color: Theme.fg
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentFg
                font.family: Theme.font
                font.pixelSize: Theme.fontSm + 1
                font.weight: Theme.uiWeight
                renderType: Theme.smooth ? Text.QtRendering : Text.NativeRendering
                selectByMouse: true

                // Empty (also when opening): current font highlighted in the middle, while typing the first match
                onTextChanged: Qt.callLater(() => {
                    if (root.query === "") {
                        root.selectCurrent();
                    } else {
                        root.sel = root.shown.length > 0 ? 0 : -1;
                        list.positionViewAtBeginning();
                    }
                })
                Keys.onEscapePressed: root.close()
                Keys.onDownPressed: root.moveSel(1)
                Keys.onUpPressed: root.moveSel(-1)
                Keys.onTabPressed: {}
                Keys.onBacktabPressed: {}
                onAccepted: {
                    if (root.sel >= 0 && root.sel < root.shown.length)
                        root.choose(root.shown[root.sel]);
                }

                Txt {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: search.text === ""
                    text: root.families.length > 0 ? "Search " + root.families.length + " fonts" : "Loading fonts…"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSm + 1
                }
            }
        }

        Rectangle {
            x: 1
            y: searchRow.y + searchRow.height + 5
            width: parent.width - 2
            height: 1
            color: Theme.hairline
        }

        ListView {
            id: list

            x: 6
            y: searchRow.y + searchRow.height + 10
            width: parent.width - 12
            height: parent.height - y - preview.height - 6
            clip: true
            pixelAligned: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.shown
            keyNavigationEnabled: false
            interactive: true

            // Highlight of the row under the mouse / arrow keys: glides like the selection in the launcher. Lives in the
            // list's content (so it scrolls along), behind the rows (they have z = 1).
            Rectangle {
                id: selBox

                property bool down: false

                parent: list.contentItem
                x: 0
                y: Math.max(0, root.sel) * 34
                z: 0
                width: list.width
                height: 34
                radius: Theme.radiusSm
                color: selBox.down ? Theme.pressed : Theme.fill
                opacity: root.sel >= 0 && root.sel < list.count ? 1 : 0

                Behavior on y {
                    enabled: selBox.opacity > 0.01

                    SmoothedAnimation {
                        velocity: 400
                        duration: Theme.ctlFast
                    }
                }
                Behavior on opacity {
                    Anim {
                        duration: Theme.ctlFast
                    }
                }
                Behavior on color {
                    CAnim {}
                }
            }

            delegate: Rectangle {
                id: item

                required property string modelData
                required property int index
                readonly property bool isValue: item.modelData === root.value

                width: list.width
                height: 34
                radius: Theme.radiusSm
                color: "transparent"

                Txt {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 44
                    text: item.modelData
                    color: item.isValue || item.index === root.sel ? Theme.fg : Theme.textDim
                    font.pixelSize: Theme.fontSm + 1

                    Behavior on color {
                        CAnim {}
                    }
                }

                Glyph {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: item.isValue
                    text: Icons.check
                    color: Theme.accent
                    font.pixelSize: Theme.iconSize - 2
                }

                MouseArea {
                    id: itemArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressedChanged: selBox.down = pressed
                    onEntered: {
                        root.sel = item.index;
                        root.hoverFamily = item.modelData;
                        previewDelay.restart();
                    }
                    onClicked: root.choose(item.modelData)
                }
            }

            Txt {
                anchors.centerIn: parent
                visible: list.count === 0 && root.families.length > 0
                text: "No font matches"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSm + 1
            }
        }

        // Preview of the font under the mouse (or the current one)
        Item {
            id: preview

            x: 1
            y: parent.height - height - 1
            width: parent.width - 2
            height: 40

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.hairline
            }

            Txt {
                x: 14
                width: parent.width - 28
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1
                readonly property string fam: root.previewFamily !== "" ? root.previewFamily : root.value
                text: fam !== "" ? "The quick brown fox jumps over the lazy dog 0123" : ""
                color: Theme.textDim
                font.family: fam !== "" ? fam : Theme.font
                font.pixelSize: Theme.fontSm + 1
            }
        }
    }
}
