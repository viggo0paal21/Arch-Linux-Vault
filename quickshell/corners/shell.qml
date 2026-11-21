// ==========================================================
//  SCREEN CORNERS
//  Draws small black rounded corners at the screen edges
//  (right under the bar), so the screen looks rounded like
//  the windows.
//
//  You never have to edit this file:
//   - size + shape come live from Hyprland
//     (decoration.rounding and decoration.rounding_power)
//   - the bar height is handled by Wayland itself: the corners
//     always sit right under the space Waybar reserves
//   - on/off switch: "screen-corners" in ~/.config/waybar/config.jsonc
//       true  = all 4 corners
//       "top" = only the 2 corners under the bar
//       false = off
//
//  The corners sit under the windows (above the wallpaper), so they
//  never cover an app; they only show behind rounded window corners.
//
//  Started by hyprland.lua with:  qs -n -p ~/.config/quickshell/corners
// ==========================================================

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

ShellRoot {
    id: root

    // ---- values, filled in automatically ----
    property int radius: 10     // decoration.rounding
    property real power: 2.0    // decoration.rounding_power (2 = circle, 4 = squircle)
    readonly property string mode: readSwitch(waybarConfig.text())

    // which corners to draw (t/b = top/bottom, l/r = left/right)
    readonly property var corners: {
        if (mode === "false" || radius <= 0) return [];
        if (mode === "top") return ["tl", "tr"];
        return ["tl", "tr", "bl", "br"];
    }

    // ---- the switch in Waybar's config ----
    FileView {
        id: waybarConfig
        path: Quickshell.env("HOME") + "/.config/waybar/config.jsonc"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    function readSwitch(text) {
        // finds:  "screen-corners": true / false / "top"
        // (a line commented out with // is ignored)
        const m = /^\s*"screen-corners"\s*:\s*("top"|true|false)/m.exec(text);
        return m ? m[1].replace(/"/g, "") : "true";
    }

    // ---- read rounding from Hyprland ----
    // prints e.g. "10 2.0"; tries the new and the old option names
    readonly property string readScript: `
get() {
  for k in decoration.$1 decoration:$1; do
    v=$(hyprctl -j getoption "$k" 2>/dev/null | grep -oE '"(int|float|value)"[[:space:]]*:[[:space:]]*"?-?[0-9]+([.][0-9]+)?' | grep -oE -- '-?[0-9]+([.][0-9]+)?$' | head -n1)
    [ -n "$v" ] && { echo "$v"; return; }
  done
  hyprctl repl "hl.get_config('decoration.$1')" 2>/dev/null | grep -oE '^-?[0-9]+([.][0-9]+)?$' | head -n1
}
echo "$(get rounding) $(get rounding_power)"
`

    Process {
        id: hyprReader
        running: true
        command: ["sh", "-c", root.readScript]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(/\s+/);
                const r = parseInt(parts[0]);
                const p = parseFloat(parts[1]);
                if (!isNaN(r)) root.radius = r;
                if (!isNaN(p) && p >= 1) root.power = p;
            }
        }
    }

    // read again whenever hyprland.lua is saved / reloaded
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") hyprReader.running = true;
        }
    }

    // ---- the corners: one tiny window per corner and screen ----
    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property var modelData

            Variants {
                model: root.corners

                PanelWindow {
                    id: corner
                    required property string modelData
                    readonly property bool isTop: modelData.charAt(0) === "t"
                    readonly property bool isLeft: modelData.charAt(1) === "l"

                    screen: perScreen.modelData
                    anchors {
                        top: corner.isTop
                        bottom: !corner.isTop
                        left: corner.isLeft
                        right: !corner.isLeft
                    }
                    implicitWidth: root.radius
                    implicitHeight: root.radius
                    exclusiveZone: 0              // stay in the free area = right under Waybar
                    aboveWindows: false           // drawn UNDER the windows, above the wallpaper
                    color: "transparent"
                    mask: Region {}               // clicks go straight through
                    WlrLayershell.namespace: "screen-corners"

                    Canvas {
                        id: canvas
                        anchors.fill: parent
                        antialiasing: true
                        property real shape: root.power
                        onShapeChanged: requestPaint()
                        onWidthChanged: requestPaint()

                        // draw the top-left corner, mirror it for the others
                        transform: Scale {
                            origin.x: canvas.width / 2
                            origin.y: canvas.height / 2
                            xScale: corner.isLeft ? 1 : -1
                            yScale: corner.isTop ? 1 : -1
                        }

                        onPaint: {
                            const ctx = getContext("2d");
                            const r = width;
                            ctx.reset();
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = "#000000";
                            ctx.beginPath();
                            ctx.moveTo(0, 0);
                            ctx.lineTo(0, r);
                            // same curve Hyprland uses for windows: |x|^p + |y|^p = r^p
                            for (let i = 0; i <= 90; i++) {
                                const t = i / 90 * Math.PI / 2;
                                ctx.lineTo(r - r * Math.pow(Math.cos(t), 2 / shape),
                                           r - r * Math.pow(Math.sin(t), 2 / shape));
                            }
                            ctx.closePath();
                            ctx.fill();
                        }
                    }
                }
            }
        }
    }
}
