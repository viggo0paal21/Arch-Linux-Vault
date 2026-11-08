pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.config

// Wallpaper picker (Settings > Wallpaper): images from the waypaper folder, thumbnails in the cache,
// Set via waypaper (uses its backend awww, fill mode and transition, and remembers the image).
// The current image comes from WallColors (awww cache, awww query, waypaper).
Singleton {
    id: root

    // Folder from waypaper (folder = ~/Wallpapers), otherwise ~/Wallpapers
    property string folder: Quickshell.env("HOME") + "/Wallpapers"
    readonly property string current: WallColors.file
    readonly property alias model: folderModel
    property string sortBy: "time"
    // Image that is being set right now (until awww reports it)
    property string pending: ""

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/wallthumbs"

    // A thumbnail is ready (path of the file in the cache)
    signal thumbReady(string thumb)

    // Thumbnails that are already done (for tiles created later, e.g. after re-sorting)
    property var ready: ({})

    function isReady(thumb) {
        return root.ready[thumb] === true;
    }

    function expand(p) {
        return p.replace(/^~(?=\/|$)/, Quickshell.env("HOME"));
    }

    function fileName(p) {
        return p.replace(/^.*\//, "");
    }

    // Name in the cache: depends on path and modification time, a replaced image gets a new thumbnail
    function thumbFor(path, modified, size) {
        const t = modified ? Math.floor(new Date(modified).getTime() / 1000) : 0;
        return root.cacheDir + "/" + Qt.md5(path + "|" + t + "|" + size) + ".jpg";
    }

    function set(path) {
        if (!path || path === root.current)
            return;
        root.pending = path;
        setter.command = ["sh", "-c", "command -v waypaper >/dev/null && exec waypaper --wallpaper \"$1\" || exec awww img \"$1\" --transition-type fade --transition-fps 60", "sh", path];
        setter.running = true;
        pendingReset.restart();
    }

    function random() {
        const n = folderModel.count;
        if (n < 2)
            return;
        let i = Math.floor(Math.random() * n);
        if (folderModel.get(i, "filePath") === root.current)
            i = (i + 1 + Math.floor(Math.random() * (n - 1))) % n;
        root.set(folderModel.get(i, "filePath"));
    }

    onCurrentChanged: {
        if (root.current === root.pending)
            root.pending = "";
    }

    Timer {
        id: pendingReset

        interval: 8000
        onTriggered: root.pending = ""
    }

    Process {
        id: setter
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/waypaper/config.ini"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const m = /^\s*folder\s*=\s*(.+?)\s*$/m.exec(text());
            if (m)
                root.folder = root.expand(m[1]);
        }
    }

    FolderListModel {
        id: folderModel

        folder: "file://" + root.folder
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.bmp", "*.jxl", "*.avif"]
        caseSensitive: false
        showDirs: false
        showHidden: false
        sortField: root.sortBy === "name" ? FolderListModel.Name : FolderListModel.Time
        sortCaseSensitive: false
    }

    // ---------- Thumbnails ----------
    // Create missing images in one go, 4 at a time. vipsthumbnail reads even huge PNGs
    // (60 MB upscales) with little memory, otherwise ImageMagick. Every finished file reports "OK <path>".
    // Into a temporary file first, so an interrupted run never leaves half an image behind.
    readonly property string genScript: [
        "w=$1; h=$2; d=$3; shift 3; mkdir -p \"$d\"; n=0",
        "while [ $# -ge 2 ]; do src=$1; dst=$2; shift 2",
        "  if [ -s \"$dst\" ]; then echo \"OK $dst\"; continue; fi",
        "  ( tmp=\"$dst.tmp.jpg\"",
        "    vipsthumbnail \"$src\" --size \"$w\"x\"$h\" --smartcrop centre -o \"$tmp[Q=88,strip]\" 2>/dev/null \\",
        "      || magick \"$src[0]\" -thumbnail \"$w\"x\"$h\"^ -gravity center -extent \"$w\"x\"$h\" -quality 88 \"$tmp\" 2>/dev/null",
        "    if [ -s \"$tmp\" ]; then mv -f \"$tmp\" \"$dst\"; echo \"OK $dst\"; else rm -f \"$tmp\"; echo \"FAIL $dst\"; fi ) &",
        "  n=$((n+1)); if [ $n -ge 4 ]; then wait -n; n=$((n-1)); fi",
        "done; wait"
    ].join("\n")

    property var queue: []

    // items: [[image, thumbnail], ...]
    function ensure(items, w, h) {
        if (items.length === 0)
            return;
        root.queue.push({ items: items, w: w, h: h });
        root.pump();
    }

    function pump() {
        if (gen.running || root.queue.length === 0)
            return;
        const job = root.queue.shift();
        const args = ["bash", "-c", root.genScript, "bash", String(job.w), String(job.h), root.cacheDir];
        for (const it of job.items)
            args.push(it[0], it[1]);
        gen.command = args;
        gen.running = true;
    }

    Process {
        id: gen

        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("OK ")) {
                    root.ready[line.slice(3)] = true;
                    root.thumbReady(line.slice(3));
                }
            }
        }
        onExited: Qt.callLater(root.pump)
    }

    // Grid: all images of the folder, whenever the folder changes (new downloads)
    property bool wanted: false
    readonly property int tileW: 480
    readonly property int tileH: 270

    function scan() {
        if (!root.wanted || folderModel.status !== FolderListModel.Ready)
            return;
        const items = [];
        for (let i = 0; i < folderModel.count; i++) {
            const p = folderModel.get(i, "filePath");
            items.push([p, root.thumbFor(p, folderModel.get(i, "fileModified"), root.tileW)]);
        }
        root.ensure(items, root.tileW, root.tileH);
    }

    onWantedChanged: rescan.restart()

    Connections {
        target: folderModel

        function onCountChanged() {
            rescan.restart();
        }

        function onStatusChanged() {
            rescan.restart();
        }
    }

    Timer {
        id: rescan

        interval: 150
        onTriggered: root.scan()
    }
}
