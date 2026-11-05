pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

// Notification daemon (replaces dunst/swaync). History + popups + do not disturb.
Singleton {
    id: root

    readonly property var list: server.trackedNotifications.values
    readonly property int count: root.list.length
    readonly property bool dnd: Config.opts.dnd
    property var popups: []
    property var times: ({})
    property var pending: []

    function removePopup(n) {
        root.popups = root.popups.filter(p => p !== n);
    }

    // Fade out first, then really close (so the animation runs cleanly)
    function dismiss(n) {
        if (!n)
            return;
        root.removePopup(n);
        root.pending = root.pending.concat([n]);
        dismissTimer.restart();
    }

    function clearAll() {
        root.popups = [];
        const all = Array.from(root.list);
        for (const n of all)
            n.dismiss();
    }

    function timeOf(n) {
        const t = n ? root.times[n.id] : undefined;
        return t ? Qt.formatDateTime(new Date(t), "HH:mm") : "";
    }

    function toggleDnd() {
        Config.opts.dnd = !Config.opts.dnd;
    }

    function timeoutFor(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        if (n.expireTimeout > 0)
            return Math.round(n.expireTimeout * 1000);
        return Math.max(1, Config.opts.notifTimeout) * 1000;
    }

    function iconFor(n) {
        if (n.image && n.image !== "")
            return n.image;
        return n.appIcon || "";
    }

    NotificationServer {
        id: server

        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;
            const t = Object.assign({}, root.times);
            t[notif.id] = Date.now();
            root.times = t;
            notif.closed.connect(() => root.removePopup(notif));
            if (!root.dnd || notif.urgency === NotificationUrgency.Critical) {
                const next = [notif].concat(root.popups);
                root.popups = next.slice(0, 5);
            }
        }
    }

    Timer {
        id: dismissTimer

        interval: 420
        onTriggered: {
            const items = root.pending;
            root.pending = [];
            for (const n of items) {
                if (n)
                    n.dismiss();
            }
        }
    }
}
