pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Active media player: the one playing, otherwise the first one.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    readonly property var player: {
        const ps = root.players;
        for (const p of ps) {
            if (p.isPlaying)
                return p;
        }
        return ps.length > 0 ? ps[0] : null;
    }

    function fmt(sec) {
        if (!isFinite(sec) || sec < 0)
            return "0:00";
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }
}
