pragma Singleton

import QtQuick
import Quickshell

// OLED Schwarz/Weiss. Alles hier ist abgeleitet, eingestellt wird in Config.
Singleton {
    id: root

    // Farben: echtes Schwarz als Basis, Graustufen nur fuer Tiefe und Hover
    readonly property color bg: "#000000"
    readonly property color layer1: "#000000"
    readonly property color layer2: "#0d0d0d"
    readonly property color layer3: "#171717"
    readonly property color hover: "#141414"
    readonly property color pressed: "#222222"
    readonly property color border: "#1c1c1c"
    readonly property color borderStrong: "#2e2e2e"
    readonly property color fg: "#ffffff"
    readonly property color fgDim: "#a8a8a8"
    readonly property color fgMuted: "#5c5c5c"
    readonly property color accent: "#ffffff"
    readonly property color accentFg: "#000000"

    // Rundungen: leicht, alles skaliert mit einem Wert
    readonly property int radius: Config.opts.radius
    readonly property int radiusSm: Math.round(radius * 0.6)
    readonly property int radiusLg: Math.round(radius * 1.4)

    // Schrift (wie die Waybar: Inter 15px Bold, Icons aus JetBrainsMono Nerd Font Propo;
    // fehlende Zeichen holt Qt automatisch per fontconfig, z. B. aus Symbols Nerd Font)
    readonly property string font: Config.opts.uiFont
    readonly property string iconFont: Config.opts.uiIconFont
    readonly property int fontSize: Config.opts.uiFontSize
    readonly property int weight: Config.opts.uiFontWeight
    readonly property int weightStrong: Math.min(900, weight + 100)
    readonly property int fontSm: fontSize - 2
    readonly property int fontLg: fontSize + 3
    readonly property int iconSize: fontSize + 4
    readonly property int barIconSize: fontSize

    // Abstaende
    readonly property int barHeight: Config.opts.barHeight
    readonly property int barBottom: (Config.opts.barFloating ? gap : 0) + barHeight
    readonly property int gap: 8
    readonly property int pad: 14

    // Animationen
    readonly property real animScale: Config.opts.animations ? Config.opts.animScale : 0
    readonly property int durFast: Math.round(130 * animScale)
    readonly property int durMed: Math.round(240 * animScale)
    readonly property int durSlow: Math.round(420 * animScale)
    readonly property list<real> curve: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    // Reinkommen: easeOutCubic, Rausgehen: easeInCubic. Gleichmaessige Schritte pro Frame
    // (die alte M3-Kurve sprang im ersten Frame um >100 px, das wirkte ruckelig).
    readonly property list<real> curveEmph: [0.33, 1.0, 0.68, 1.0, 1.0, 1.0]
    readonly property list<real> curveAccel: [0.32, 0.0, 0.67, 0.0, 1.0, 1.0]
}
