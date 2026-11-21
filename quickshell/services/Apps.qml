pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// App search for the launcher: matches by name, words, keywords, fuzzy.
// Frequently launched apps move up.
Singleton {
    id: root

    property var counts: ({})

    readonly property var all: {
        const out = [];
        for (const e of DesktopEntries.applications.values) {
            if (!e.noDisplay)
                out.push(e);
        }
        out.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
        return out;
    }

    function fuzzy(str, q) {
        let i = 0;
        for (let k = 0; k < str.length && i < q.length; k++) {
            if (str[k] === q[i])
                i++;
        }
        return i === q.length;
    }

    function score(e, q) {
        const name = (e.name || "").toLowerCase();
        let s = 0;
        if (name === q)
            s = 100;
        else if (name.startsWith(q))
            s = 80;
        else if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            s = 65;
        else if (name.includes(q))
            s = 50;
        else {
            const keywords = e.keywords ? Array.from(e.keywords).join(" ") : "";
            const extra = [e.genericName || "", e.comment || "", keywords, e.id || ""].join(" ").toLowerCase();
            if (extra.includes(q))
                s = 30;
            else if (root.fuzzy(name, q))
                s = 15;
        }
        if (s > 0)
            s += Math.min(25, (root.counts[e.id] || 0) * 2);
        return s;
    }

    function query(text) {
        const q = (text || "").trim().toLowerCase();
        if (q === "") {
            return root.all.slice().sort((a, b) => {
                const d = (root.counts[b.id] || 0) - (root.counts[a.id] || 0);
                return d !== 0 ? d : (a.name || "").localeCompare(b.name || "");
            });
        }
        const scored = [];
        for (const e of root.all) {
            const s = root.score(e, q);
            if (s > 0)
                scored.push({
                    e: e,
                    s: s
                });
        }
        scored.sort((a, b) => b.s - a.s || (a.e.name || "").localeCompare(b.e.name || ""));
        return scored.map(x => x.e);
    }

    function launch(entry) {
        const c = Object.assign({}, root.counts);
        c[entry.id] = (c[entry.id] || 0) + 1;
        root.counts = c;
        countsFile.setText(JSON.stringify(c));
        if (entry.runInTerminal)
            root.exec([Config.opts.terminal, "-e"].concat(Array.from(entry.command)), entry.workingDirectory);
        else
            root.exec(Array.from(entry.command), entry.workingDirectory);
    }

    function runCommand(cmd) {
        if (cmd.trim() !== "")
            root.exec(["sh", "-c", cmd], "");
    }

    // Quickshell itself runs without MangoHud, lsfg-vk and LD_PRELOAD (~/.local/bin/qs-start). Everything the
    // launcher started used to inherit that: Steam from the launcher, and with it every game, ran without MangoHud
    // (no FPS limit, no vsync), and so did a terminal from the launcher. qs-start saves the
    // original values as QS_APP_*, programs started from here get them back.
    // null = was not set in the session -> remove it for the program.
    readonly property var appEnv: {
        if (Quickshell.env("QS_APP_SAVED") == null)
            return {};
        const env = {
            QS_APP_SAVED: null
        };
        for (const n of ["MANGOHUD", "LD_PRELOAD", "DISABLE_LSFGVK", "DISABLE_VKBASALT", "QSG_RHI_BACKEND", "QSG_USE_SIMPLE_ANIMATION_DRIVER", "QT_LOGGING_RULES"]) {
            const v = Quickshell.env("QS_APP_" + n);
            env[n] = v == null ? null : v;
            env["QS_APP_" + n] = null;
        }
        return env;
    }

    // Starts a program detached from Quickshell, with the session's normal environment
    function exec(command, dir) {
        const ctx = {
            command: command,
            environment: root.appEnv
        };
        if (dir)
            ctx.workingDirectory = dir;
        Quickshell.execDetached(ctx);
    }

    // Small calculator without eval: + - * / % ^ ( ) and decimals
    function calc(input) {
        const src = input.replace(/,/g, ".").replace(/\s+/g, "");
        if (src === "" || !/^[0-9+\-*\/%^().]+$/.test(src))
            return null;
        let pos = 0;
        const eat = ch => {
            if (src[pos] === ch) {
                pos++;
                return true;
            }
            return false;
        };
        let expr = null;
        const number = () => {
            const start = pos;
            while (pos < src.length && /[0-9.]/.test(src[pos]))
                pos++;
            if (start === pos)
                throw new Error("num");
            const v = Number(src.slice(start, pos));
            if (isNaN(v))
                throw new Error("num");
            return v;
        };
        const unary = () => {
            if (eat("-"))
                return -unary();
            if (eat("+"))
                return unary();
            if (eat("(")) {
                const v = expr();
                if (!eat(")"))
                    throw new Error("paren");
                return v;
            }
            return number();
        };
        const power = () => {
            const base = unary();
            if (eat("^"))
                return Math.pow(base, power());
            return base;
        };
        const term = () => {
            let v = power();
            for (;;) {
                if (eat("*"))
                    v *= power();
                else if (eat("/"))
                    v /= power();
                else if (eat("%"))
                    v %= power();
                else
                    return v;
            }
        };
        expr = () => {
            let v = term();
            for (;;) {
                if (eat("+"))
                    v += term();
                else if (eat("-"))
                    v -= term();
                else
                    return v;
            }
        };
        try {
            const v = expr();
            if (pos !== src.length || !isFinite(v))
                return null;
            return Math.round(v * 1e10) / 1e10;
        } catch (e) {
            return null;
        }
    }

    FileView {
        id: countsFile

        path: Quickshell.statePath("launcher-counts.json")
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.counts = parsed && typeof parsed === "object" ? parsed : {};
            } catch (e) {
                root.counts = {};
            }
        }
    }
}
