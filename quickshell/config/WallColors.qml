pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

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

    // Result. Theme only reads these values (set by the fade below).
    // Deliberately only the accent (everything that used to be highlighted in white) and the text on it. Text, borders and
    // surfaces stay black and white: every color change rebuilds, in all windows (including the closed panels,
    // which stay alive invisibly) every affected text. For text and surface colors that was
    // thousands of elements per frame and 40-70 ms hitches when switching. The accent is only used in a few.
    property color accent: root.original.accent
    property color accentFg: root.original.accentFg

    // Accent for windows that are not visible right now (closed, invisibly mapped panels): jumps straight to the
    // target when fading instead of following every frame. Otherwise every fullscreen panel redraws on every frame
    // for the whole fade (stutter when opening windows / switching workspaces). live = a panel is
    // open (set by services/Ui.qml): then everything gets the running fade as before.
    property color accentStatic: root.original.accent
    property color accentFgStatic: root.original.accentFg
    property bool live: false

    function expand(p) {
        return p.replace(/^~(?=\/|$)/, Quickshell.env("HOME"));
    }

    // ---------- Transition ----------

    // Like awww: waypaper passes type and duration (swww_transition_type / _duration), the curve is the one awww uses
    // (default --transition-bezier .54,0,.34,.99). "simple" goes in fixed steps (about 0.7 s), "none" instantly.
    property string transType: "fade"
    property real transDuration: 2
    readonly property int wallFadeMs: root.transType === "none" ? 250 : root.transType === "simple" ? 700 : Math.round(Math.max(0.3, root.transDuration) * 1000)
    readonly property var wallFadeCurve: [0.54, 0.0, 0.34, 0.99]
    // Switching on/off or another style: short and calm
    readonly property int quickFadeMs: 450
    readonly property var quickFadeCurve: [0.25, 0.46, 0.45, 0.94]
    // Time at which awww reported the new image
    property real changedAt: 0

    // No fade at startup (the colors are usually there before anything is visible)
    property bool animate: false

    Timer {
        running: true
        interval: 2500
        onTriggered: root.animate = true
    }

    property var fadeFrom: null     // OKLab [L, a, b] per color
    property var fadeTo: null
    property var fadeCurve: root.quickFadeCurve
    property real fadeMs: 0
    property real fadeElapsed: 0

    // Is a fade running right now (CAnim then follows instantly, see components/CAnim.qml)
    readonly property bool fading: fade.running

    // "Black & white with 1 window" (Settings > Appearance): the same rule as the dynamic bar.
    // Exactly 1 tiled window on the active workspace = normal black & white. No windows,
    // 2 or more, or only floating windows (no matter how many) = wallpaper colors.
    // Counted like the bar does (focused monitor, lastIpcObject, refreshed by services/Hypr.qml
    // on window events), so the switch starts at the same moment as the docking.
    readonly property int tiledCount: {
        // try: while the shell reloads, Hyprland is briefly gone in the old instance
        try {
            const mon = Hyprland.focusedMonitor;
            const ws = mon ? mon.activeWorkspace : null;
            if (!ws)
                return 0;
            let n = 0;
            for (const t of ws.toplevels.values) {
                const o = t.lastIpcObject;
                if (o && o.floating === false)
                    n++;
            }
            return n;
        } catch (e) {
            return 0;
        }
    }
    readonly property bool mono: Config.opts.wallColorsDynamic && root.tiledCount === 1
    onMonoChanged: root.startFade()

    // The target is the palette (or the original when off / no image / black & white because of 1 window)
    function target(name) {
        return root.enabled && root.palette && !root.mono ? root.palette[name] : root.original[name];
    }

    function startFade() {
        const toA = target("accent"), toF = target("accentFg");
        if (!root.animate || !Config.opts.animations) {
            fade.running = false;
            root.accent = toA;
            root.accentFg = toF;
            root.accentStatic = toA;
            root.accentFgStatic = toF;
            return;
        }
        // If the change came from the wallpaper (awww just got a new image), the fade ends together with the one
        // of the image. The colors are only known after the image is analyzed, the time until then is subtracted.
        const since = Date.now() - root.changedAt;
        if (since < root.wallFadeMs + 1000) {
            root.fadeMs = Math.max(350, root.wallFadeMs - since);
            root.fadeCurve = root.wallFadeCurve;
        } else {
            root.fadeMs = root.quickFadeMs;
            root.fadeCurve = root.quickFadeCurve;
        }
        root.fadeFrom = [toLab(root.accent), toLab(root.accentFg)];
        root.fadeTo = [toLab(toA), toLab(toF)];
        root.fadeElapsed = 0;
        fade.running = true;
        // Only after fade.running: CAnim then follows instantly (duration 0), no own animation in closed panels
        root.accentStatic = toA;
        root.accentFgStatic = toF;
    }

    FrameAnimation {
        id: fade

        running: false
        onTriggered: {
            root.fadeElapsed += Math.max(0, Math.min(fade.frameTime, 1 / 60)) * 1000;
            const u = Math.min(1, root.fadeElapsed / Math.max(1, root.fadeMs));
            const p = root.curveAt(root.fadeCurve, u);
            root.accent = root.mixLab(root.fadeFrom[0], root.fadeTo[0], p);
            root.accentFg = root.mixLab(root.fadeFrom[1], root.fadeTo[1], p);
            if (u >= 1) {
                fade.running = false;
                // End exactly on the target (no rounding leftover)
                root.accent = root.target("accent");
                root.accentFg = root.target("accentFg");
                root.accentStatic = root.accent;
                root.accentFgStatic = root.accentFg;
            }
        }
    }

    onPaletteChanged: root.startFade()
    onStyleChanged: root.recalc()
    onEnabledChanged: {
        if (root.enabled) {
            root.makeThumb();
            // If the existing colors already match the current image, right away; otherwise they come with the new image
            if (root.thumbFor === root.file)
                root.recalc();
        } else {
            root.recalc();
        }
        root.startFade();
    }

    // Value of the bezier curve (x1, y1, x2, y2) at position u (0..1)
    function curveAt(c, u) {
        if (u <= 0)
            return 0;
        if (u >= 1)
            return 1;
        let lo = 0, hi = 1, t = u;
        for (let i = 0; i < 24; i++) {
            const x = 3 * (1 - t) * (1 - t) * t * c[0] + 3 * (1 - t) * t * t * c[2] + t * t * t;
            if (Math.abs(x - u) < 0.00001)
                break;
            if (x < u)
                lo = t;
            else
                hi = t;
            t = (lo + hi) / 2;
        }
        return 3 * (1 - t) * (1 - t) * t * c[1] + 3 * (1 - t) * t * t * c[3] + t * t * t;
    }

    // Mix two OKLab colors (p = 0: a, 1: b)
    function mixLab(a, b, p) {
        const c = fromLab(a[0] + (b[0] - a[0]) * p, a[1] + (b[1] - a[1]) * p, a[2] + (b[2] - a[2]) * p);
        return Qt.rgba(Math.max(0, Math.min(1, c[0])), Math.max(0, Math.min(1, c[1])), Math.max(0, Math.min(1, c[2])), 1);
    }

    // ---------- Find the image ----------

    // awww remembers the image per screen in ~/.cache/awww/<version>/<screen> ("\0crop:center\0Lanczos3\0/path").
    // The file changes on every switch, whether via waypaper, the settings or "awww img" in a terminal.
    // Wait briefly before reading it: awww rewrites it, reading too early would see it empty or half written.
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
        id: awwwCache

        path: root.awwwVersion !== "" && Quickshell.screens.length > 0 ? (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/awww/" + root.awwwVersion + "/" + Quickshell.screens[0].name : ""
        watchChanges: true
        printErrors: false
        onFileChanged: cacheSettle.restart()
        onLoaded: {
            const parts = text().split("\u0000");
            const p = parts[parts.length - 1].trim();
            if (p.startsWith("/") && /\.[A-Za-z0-9]{2,5}$/.test(p))
                root.daemonFile = p;
        }
    }

    Timer {
        id: cacheSettle

        interval: 40
        onTriggered: awwwCache.reload()
    }

    // waypaper: image (fallback if awww reports nothing) and the transition's type/duration. waypaper writes the file
    // in two steps: a half-written state without the entry is ignored instead of clearing the value.
    FileView {
        path: Quickshell.env("HOME") + "/.config/waypaper/config.ini"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            const m = /^\s*wallpaper\s*=\s*(.+?)\s*$/m.exec(t);
            if (m)
                root.waypaperFile = root.expand(m[1]);
            const tt = /^\s*swww_transition_type\s*=\s*(\S+)\s*$/m.exec(t);
            if (tt)
                root.transType = tt[1];
            const td = /^\s*swww_transition_duration\s*=\s*([\d.]+)\s*$/m.exec(t);
            if (td)
                root.transDuration = parseFloat(td[1]);
            if (m) {
                root.queryDaemon();
                // awww only reports the new image once the switch has started: ask again shortly after
                requery.restart();
            }
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
                if (m)
                    root.daemonFile = m[1];
            }
        }
    }

    onFileChanged: {
        root.changedAt = Date.now();
        root.makeThumb();
    }

    // ---------- Small image for the colors ----------
    // ColorQuantizer reads the image at full size. Huge images (60 MB upscales) need hundreds of MB for that
    // and fail at Qt's limit. So first a small image (256 px) in the cache, made with vipsthumbnail
    // (else ImageMagick, else the original). An image that was used before is there instantly.
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/wallcolors"
    property string quantFile: ""
    // Image the small image is being (or was last) made for
    property string thumbFor: ""
    property string thumbDst: ""

    function makeThumb() {
        if (!root.enabled || root.file === "")
            return;
        if (thumbProc.running)
            return;   // already running, afterwards it checks again with the then current image
        root.thumbFor = root.file;
        root.thumbDst = root.thumbDir + "/" + Qt.md5(root.file) + ".jpg";
        thumbProc.command = ["sh", "-c", ["src=$1; dst=$2; mkdir -p \"${dst%/*}\"", "if [ ! -s \"$dst\" ] || [ \"$src\" -nt \"$dst\" ]; then", "  tmp=\"$dst.tmp.jpg\"", "  vipsthumbnail \"$src\" --size 256x256 -o \"$tmp[Q=90,strip]\" 2>/dev/null || magick \"$src[0]\" -thumbnail 256x256 -quality 90 \"$tmp\" 2>/dev/null", "  if [ -s \"$tmp\" ]; then mv -f \"$tmp\" \"$dst\"; else rm -f \"$tmp\"; fi", "fi", "[ -s \"$dst\" ] && echo OK || echo FAIL"].join("\n"), "sh", root.thumbFor, root.thumbDst];
        thumbProc.running = true;
    }

    Process {
        id: thumbProc

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.thumbFor === root.file)
                    root.quantFile = text.indexOf("OK") >= 0 ? root.thumbDst : root.thumbFor;
                else
                    Qt.callLater(root.makeThumb);   // a different image by now: do not use the old result
            }
        }
    }

    ColorQuantizer {
        id: quant

        source: root.enabled && root.quantFile !== "" ? "file://" + root.quantFile : ""
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
        if (!root.enabled) {
            root.palette = null;
            root.colorfulness = 0;
            return;
        }
        // No colors (or no new ones) yet: keep the current ones, nothing briefly jumps to white
        const cols = quant.colors;
        if (!cols || cols.length === 0)
            return;
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
