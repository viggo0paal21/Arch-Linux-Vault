pragma Singleton

import QtQuick
import Quickshell

// OLED black/white. Everything here is derived, settings live in Config.
Singleton {
    id: root

    // "Smooth text" (Settings > Appearance): text can be placed on fractions of pixels, motion
    // without pixel steps. Off = crisp text.
    readonly property bool smooth: Config.opts.smoothText

    // Position for motion: always whole pixels (no jitter, sharp text in every frame)
    function px(v) {
        return Math.round(v);
    }

    // Colors: true black as the base, greys only for depth and hover
    readonly property color bg: "#000000"
    readonly property color layer1: "#000000"
    // Transparency (Settings > Appearance): "off" | "popups" | "everywhere"
    readonly property bool glassy: Config.opts.transparency === "popups" || Config.opts.transparency === "everywhere"
    // Opacity of the transparent surfaces (Settings > Appearance > Opacity), 100 = black
    readonly property real glassAlpha: Math.max(0, Math.min(100, Config.opts.glassOpacity)) / 100

    // On black the tints look exactly like the solid greys,
    // on transparent surfaces they let the blur shine through.
    readonly property color layer2: glassy ? Qt.rgba(1, 1, 1, 0.05) : "#0d0d0d"
    readonly property color layer3: glassy ? Qt.rgba(1, 1, 1, 0.09) : "#171717"
    readonly property color hover: glassy ? Qt.rgba(1, 1, 1, 0.08) : "#141414"
    readonly property color pressed: glassy ? Qt.rgba(1, 1, 1, 0.13) : "#222222"
    readonly property color border: "#1c1c1c"
    readonly property color borderStrong: "#2e2e2e"
    readonly property color fg: "#ffffff"
    readonly property color fgDim: "#a8a8a8"
    readonly property color fgMuted: "#5c5c5c"
    // Accent: white with black text, with "Wallpaper colors" in the color of the wallpaper (see WallColors)
    readonly property color accent: WallColors.accent
    readonly property color accentFg: WallColors.accentFg

    // Rounding: subtle, everything scales with one value
    readonly property int radius: Config.opts.radius
    readonly property int radiusSm: Math.round(radius * 0.6)
    readonly property int radiusLg: Math.round(radius * 1.4)

    // Font (like the Waybar: Inter 15px bold, icons from JetBrainsMono Nerd Font Propo;
    // Qt gets missing glyphs automatically via fontconfig, e.g. from Symbols Nerd Font)
    readonly property string font: Config.opts.uiFont
    readonly property string iconFont: Config.opts.uiIconFont
    readonly property int fontSize: Config.opts.uiFontSize
    readonly property int weight: Config.opts.uiFontWeight
    readonly property int weightStrong: Math.min(900, weight + 100)
    readonly property int fontSm: fontSize - 2
    readonly property int fontLg: fontSize + 3
    readonly property int iconSize: fontSize + 4
    readonly property int barIconSize: fontSize

    // Spacing
    readonly property int barHeight: Config.opts.barHeight
    readonly property int barBottom: (Config.opts.barFloating ? Config.opts.barFloatOffset : 0) + barHeight
    readonly property int gap: 8
    readonly property int pad: 14

    // Animations
    readonly property real animScale: Config.opts.animations ? Config.opts.animScale : 0
    readonly property int durFast: Math.round(130 * animScale)
    readonly property int durMed: Math.round(240 * animScale)
    readonly property int durSlow: Math.round(420 * animScale)
    // Curves to choose from (Settings > Animations)
    readonly property var curveKeys: ["standard", "outCubic", "inCubic", "smoothOut", "md3Decel", "inOutSine", "linear"]
    readonly property var curveNames: ["Standard", "Ease out cubic", "Ease in cubic", "Smooth out", "MD3 decelerate", "Ease in-out", "Linear"]
    readonly property var curvePoints: ({
            standard: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0],
            outCubic: [0.33, 1.0, 0.68, 1.0, 1.0, 1.0],
            inCubic: [0.32, 0.0, 0.67, 0.0, 1.0, 1.0],
            smoothOut: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0],
            md3Decel: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0],
            inOutSine: [0.37, 0.0, 0.63, 1.0, 1.0, 1.0],
            linear: [0.0, 0.0, 1.0, 1.0, 1.0, 1.0]
        })

    function curveOf(key) {
        return root.curvePoints[key] || root.curvePoints.standard;
    }

    // Controls (hover, switches, sliders, lists): curve and speed from Settings > Animations
    readonly property list<real> curve: root.curveOf(Config.opts.animCtlCurve)
    readonly property int ctlFast: Math.round(durFast * Config.opts.animCtlSpeed)
    readonly property int ctlMed: Math.round(durMed * Config.opts.animCtlSpeed)
    // Coming in: easeOutCubic, going out: easeInCubic. Even steps per frame
    // (the old M3 curve jumped >100 px in the first frame, which looked choppy).
    readonly property list<real> curveEmph: [0.33, 1.0, 0.68, 1.0, 1.0, 1.0]
    readonly property list<real> curveAccel: [0.32, 0.0, 0.67, 0.0, 1.0, 1.0]
    // Like the bar (Smooth out, decelerating evenly): motion outside the bar (switches,
    // sliders, meters, OSD, tab switch, launcher height)
    readonly property list<real> curveSmooth: root.curveOf("smoothOut")
}
