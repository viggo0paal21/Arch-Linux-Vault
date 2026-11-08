pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// "Wallpaper colors" (Settings > Appearance): accents in the colors of the wallpaper, similar to Caelestia.
// The image is reduced to 16 typical colors (ColorQuantizer, median cut). From them the hue with
// the most saturated color is picked and turned into the accent for a black background (buttons, switches,
// sliders, active workspace, graphs, selection) with matching text on it.
// The math is done in OKLCH (uniform lightness), so contrast and readability stay like the original.
// Black-and-white images stay black and white: the less color the image has, the closer to the original.
// Off (or no image): exactly the old colors. Changes fade smoothly (ColorAnimation).
Singleton {
    id: root

    readonly property bool enabled: Config.opts.wallColors
    readonly property string style: Config.opts.wallColorStyle

    // Image: own background image (OLED background), otherwise the current image of awww/swww,
    // falling back to the entry from waypaper. Always tracked (also for Settings > Wallpaper).
    property string waypaperFile: ""
    property string daemonFile: ""
    readonly property string file: Config.opts.oledBackground && Config.opts.wallpaper !== "" ? root.expand(Config.opts.wallpaper) : (root.daemonFile !== "" ? root.daemonFile : root.waypaperFile)

    // The 16 colors of the image (for the preview in the settings)
    readonly property var sourceColors: quant.colors
    // 0 = black-and-white image (palette = original), 1 = colorful image
    property real colorfulness: 0
    // Computed target colors, null = original
    property var palette: null

    readonly property var original: ({
            accent: Qt.rgba(1, 1, 1, 1),
            accentFg: Qt.rgba(0, 0, 0, 1)
        })

    function pick(name) {
        return root.palette ? root.palette[name] : root.original[name];
    }

    // Palette, animated smoothly (wallpaper change, switching on/off)
    property color palAccent: root.pick("accent")
    property color palAccentFg: root.pick("accentFg")

    // Result. Theme only reads these values.
    // Deliberately only the accent (everything that used to be highlighted in white) and the text on it. Text, borders and
    // surfaces stay black and white: every color change rebuilds, in all windows (including the closed panels,
    // which stay alive invisibly) every affected text. For text and surface colors that was
    // thousands of elements per frame and 40-70 ms hitches when switching. The accent is only used in a few.
    readonly property color accent: root.palAccent
    readonly property color accentFg: root.palAccentFg

    // No fade at startup (the colors are usually there before anything is visible)
    property bool animate: false
    readonly property int animMs: root.animate && Config.opts.animations ? 600 : 0

    component Fade: ColorAnimation {
        duration: root.animMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.25, 0.46, 0.45, 0.94]
    }

    Behavior on palAccent { Fade {} }
    Behavior on palAccentFg { Fade {} }

    Timer {
        running: true
        interval: 2500
        onTriggered: root.animate = true
    }

    onEnabledChanged: root.recalc()
    onStyleChanged: root.recalc()

    function expand(p) {
        return p.replace(/^~(?=\/|$)/, Quickshell.env("HOME"));
    }

    // ---------- Find the image ----------

    // awww remembers the image per screen in ~/.cache/awww/<version>/<screen> ("\0crop:center\0Lanczos3\0/path").
    // The file changes on every switch, whether via waypaper, the settings or "awww img" in a terminal.
    property string awwwVersion: ""

    Process {
        running: true
        command: ["awww", "--version"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /(\d+\.\d+\.\d+)/.exec(text);
                root.awwwVersion = m ? m[1] : "";
            }
        }
    }

    FileView {
        path: root.awwwVersion !== "" && Quickshell.screens.length > 0 ? (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/awww/" + root.awwwVersion + "/" + Quickshell.screens[0].name : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const parts = text().split("\u0000");
            const p = parts[parts.length - 1].trim();
            if (p.startsWith("/"))
                root.daemonFile = p;
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/waypaper/config.ini"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const m = /^\s*wallpaper\s*=\s*(.+?)\s*$/m.exec(text());
            root.waypaperFile = m ? root.expand(m[1]) : "";
            root.queryDaemon();
            // awww only reports the new image once the switch has started: ask again shortly after
            requery.restart();
        }
    }

    Timer {
        id: requery

        interval: 1500
        onTriggered: root.queryDaemon()
    }

    function queryDaemon() {
        if (!query.running)
            query.running = true;
    }

    // "DP-1: 2560x1440, scale: 1, currently displaying: image: /path/image.jpg"
    Process {
        id: query

        command: ["sh", "-c", "awww query 2>/dev/null || swww query 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /image:\s*(.+?)\s*$/m.exec(text);
                root.daemonFile = m ? m[1] : "";
            }
        }
    }

    ColorQuantizer {
        id: quant

        source: root.enabled && root.file !== "" ? "file://" + root.file : ""
        depth: 4
        rescaleSize: 128
        onColorsChanged: root.recalc()
    }

    // ---------- Color math (OKLab / OKLCH) ----------

    function toLin(c) {
        return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    }

    function fromLin(c) {
        return c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(Math.max(c, 0), 1 / 2.4) - 0.055;
    }

    function toLab(col) {
        const r = toLin(col.r), g = toLin(col.g), b = toLin(col.b);
        const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
        const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
        const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
        return [0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s];
    }

    function fromLab(L, a, b) {
        const l = Math.pow(L + 0.3963377774 * a + 0.2158037573 * b, 3);
        const m = Math.pow(L - 0.1055613458 * a - 0.0638541728 * b, 3);
        const s = Math.pow(L - 0.0894841775 * a - 1.2914855480 * b, 3);
        return [fromLin(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s), fromLin(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s), fromLin(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)];
    }

    // Color from lightness, chroma, hue. Outside of sRGB the chroma is reduced.
    function lch(L, C, h) {
        let rgb = [L, L, L];
        for (let i = 0; i < 40; i++) {
            rgb = fromLab(L, C * Math.cos(h), C * Math.sin(h));
            if (rgb.every(v => v >= -0.0001 && v <= 1.0001))
                break;
            C *= 0.92;
        }
        return rgb.map(v => Math.max(0, Math.min(1, v)));
    }

    // Mix original and target in OKLab (t = 0: original)
    function mix(orig, target, t) {
        const o = toLab(orig);
        const g = toLab({ r: target[0], g: target[1], b: target[2] });
        const c = fromLab(o[0] + (g[0] - o[0]) * t, o[1] + (g[1] - o[1]) * t, o[2] + (g[2] - o[2]) * t);
        return Qt.rgba(Math.max(0, Math.min(1, c[0])), Math.max(0, Math.min(1, c[1])), Math.max(0, Math.min(1, c[2])), 1);
    }

    function recalc() {
        const cols = quant.colors;
        if (!root.enabled || !cols || cols.length === 0) {
            root.palette = null;
            root.colorfulness = 0;
            return;
        }
        const labs = [];
        for (let i = 0; i < cols.length; i++)
            labs.push(toLab(cols[i]));

        // Pick the hue: 36 bins, every color counts with its chroma (all 16 stand for the same number of
        // pixels). Very dark and grey colors don't count.
        const bins = new Array(36).fill(0);
        const binOf = (a, b) => Math.floor(((Math.atan2(b, a) + 2 * Math.PI) % (2 * Math.PI)) / (2 * Math.PI) * 36) % 36;
        for (const [L, a, b] of labs) {
            const C = Math.hypot(a, b);
            if (C < 0.02 || L < 0.12)
                continue;
            const w = C * (0.4 + 0.6 * Math.min(1, L / 0.6));
            const k = binOf(a, b);
            bins[(k + 35) % 36] += w * 0.5;
            bins[k] += w;
            bins[(k + 1) % 36] += w * 0.5;
        }
        let best = 0;
        for (let i = 1; i < 36; i++)
            if (bins[i] > bins[best])
                best = i;
        let srcC = 0, srcL = 0.8, hue = 0;
        if (bins[best] > 0) {
            // The most saturated color of the image in this range
            for (const [L, a, b] of labs) {
                const C = Math.hypot(a, b);
                const d = Math.abs(((binOf(a, b) - best + 54) % 36) - 18);
                if (C >= 0.02 && d <= 1 && C > srcC) {
                    srcC = C;
                    srcL = L;
                    hue = Math.atan2(b, a);
                }
            }
        }
        const t = Math.max(0, Math.min(1, (srcC - 0.01) / 0.025));

        // Style: Tonal (hue from the image, calm fixed chroma like Material You), Vibrant (strong),
        // Exact (color as colorful as in the image)
        let pL = 0.82, pC = 0.09;
        if (root.style === "vibrant") {
            pL = 0.78;
            pC = Math.max(0.14, Math.min(srcC * 1.5, 0.20));
        } else if (root.style === "exact") {
            pL = Math.max(0.72, Math.min(0.88, srcL));
            pC = srcC;
        }
        const o = root.original;
        root.colorfulness = t;
        root.palette = {
            accent: root.mix(o.accent, root.lch(pL, pC, hue), t),
            accentFg: root.mix(o.accentFg, root.lch(0.2, 0.045, hue), t)
        };
    }
}
