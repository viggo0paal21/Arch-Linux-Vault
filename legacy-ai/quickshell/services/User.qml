pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Profile (Settings > System > Profile, control center header, corner of the settings, hyprlock).
// Picture: the account picture that KDE Plasma, SDDM and the shell share (AccountsService, otherwise ~/.face.icon / ~/.face).
// The shell sets a new picture through AccountsService (busctl SetIconFile, no password for your own account).
// It is cropped beforehand in the settings (modules/settings/CropDialog.qml, finished 256 x 256 PNG). The previous
// picture is backed up the first time (face-original in the shell's state folder, "Restore original").
// Name: own name from the settings, otherwise the full account name (GECOS), otherwise the login name. It is
// also written to <state folder>/user-name, which hyprlock reads.
Singleton {
    id: root

    readonly property string login: Quickshell.env("USER") || "user"
    property string fullName: ""
    property string host: ""
    readonly property string systemName: root.fullName !== "" ? root.fullName : root.login
    readonly property string name: Config.opts.userName.trim() !== "" ? Config.opts.userName.trim() : root.systemName

    // Found account picture and its change time (seconds). rev counts own changes, so the new picture
    // also loads when it was created within the same second.
    property string face: ""
    property real faceStamp: 0
    property int rev: 0
    readonly property string faceUrl: root.face === "" ? "" : "file://" + root.face + "?v=" + root.faceStamp + "-" + root.rev
    // Backup of the original picture exists
    property bool hasOriginal: false

    // Setting in progress (source file it was cropped from), error message from the last attempt
    property bool busy: false
    property string busyPath: ""
    property string error: ""

    // Folders from ~/.config/user-dirs.dirs (for the picture picker)
    property string picturesDir: Quickshell.env("HOME") + "/Pictures"
    property string downloadsDir: Quickshell.env("HOME") + "/Downloads"

    readonly property string stateDir: Quickshell.statePath("")

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    // New account picture: file = finished cropped picture, from = picture it came from (marker in the picker)
    function setPicture(file, from) {
        if (root.busy || !file)
            return;
        root.run(file, from || "", false);
    }

    // Picture from before the first change back
    function restorePicture() {
        if (root.busy || !root.hasOriginal)
            return;
        root.run(root.stateDir.replace(/\/$/, "") + "/face-original", "", true);
    }

    function run(file, from, restore) {
        root.busy = true;
        root.busyPath = from;
        root.error = "";
        setter.restore = restore;
        setter.command = ["sh", "-c", root.setScript, "sh", file, root.stateDir.replace(/\/$/, ""), restore ? "1" : "0"];
        setter.running = true;
    }

    // Detection: GECOS name, host name, first existing account picture (like KDE: AccountsService before ~/.face.icon),
    // backup exists. Lines: "gecos <name>", "host <name>", "face <mtime> <path>", "orig".
    readonly property string readScript: [
        "st=$1; u=$(id -un)",
        "printf 'gecos %s\\n' \"$(getent passwd \"$u\" | cut -d: -f5 | cut -d, -f1)\"",
        "printf 'host %s\\n' \"$(uname -n)\"",
        "for f in \"/var/lib/AccountsService/icons/$u\" \"$HOME/.face.icon\" \"$HOME/.face\"; do",
        "  if [ -r \"$f\" ] && [ -s \"$f\" ]; then printf 'face %s %s\\n' \"$(stat -L -c %Y \"$f\")\" \"$f\"; break; fi",
        "done",
        "[ -s \"$st/face-original\" ] && echo orig",
        "exit 0"
    ].join("\n")

    // Setting: copy the picture to the cache, back up the old picture the first time, hand it to AccountsService. If
    // ~/.face.icon or ~/.face exist as real files (not links), they get the same picture (backed up once as .bak-qs).
    readonly property string setScript: [
        "src=$1; st=$2; restore=$3; u=$(id -un)",
        "d=\"${XDG_CACHE_HOME:-$HOME/.cache}/quickshell\"; mkdir -p \"$d\" \"$st\" || { echo 'ERR Could not create the cache folder'; exit 1; }",
        "out=\"$d/face.png\"; tmp=\"$d/face.tmp.png\"; rm -f \"$tmp\"",
        "cp -f \"$src\" \"$tmp\" 2>/dev/null",
        "[ -s \"$tmp\" ] || { rm -f \"$tmp\"; echo 'ERR This image could not be read'; exit 1; }",
        "mv -f \"$tmp\" \"$out\"",
        "cur=\"/var/lib/AccountsService/icons/$u\"",
        "if [ \"$restore\" != 1 ] && [ ! -e \"$st/face-original\" ] && [ -s \"$cur\" ]; then cp \"$cur\" \"$st/face-original\"; fi",
        "obj=$(busctl call org.freedesktop.Accounts /org/freedesktop/Accounts org.freedesktop.Accounts FindUserByName s \"$u\" 2>/dev/null | sed -n 's/^o \"\\(.*\\)\"$/\\1/p')",
        "[ -n \"$obj\" ] || { echo 'ERR AccountsService is not running'; exit 1; }",
        "if ! e=$(timeout 60 busctl call org.freedesktop.Accounts \"$obj\" org.freedesktop.Accounts.User SetIconFile s \"$out\" 2>&1); then echo \"ERR $e\" | head -n 1; exit 1; fi",
        "for f in \"$HOME/.face.icon\" \"$HOME/.face\"; do",
        "  if [ -f \"$f\" ] && [ ! -L \"$f\" ]; then [ -e \"$f.bak-qs\" ] || cp -p \"$f\" \"$f.bak-qs\"; cp -f \"$out\" \"$f\"; fi",
        "done",
        "echo OK"
    ].join("\n")

    Component.onCompleted: root.refresh()

    // Look again when the settings or the control center open (e.g. picture changed in KDE)
    Connections {
        target: Ui

        function onPanelChanged() {
            if (Ui.panel === "settings" || Ui.panel === "control")
                root.refresh();
        }
    }

    Process {
        id: reader

        command: ["sh", "-c", root.readScript, "sh", root.stateDir.replace(/\/$/, "")]
        stdout: StdioCollector {
            onStreamFinished: {
                let face = "";
                let stamp = 0;
                let orig = false;
                for (const line of this.text.split("\n")) {
                    if (line.startsWith("gecos "))
                        root.fullName = line.slice(6).trim();
                    else if (line.startsWith("host "))
                        root.host = line.slice(5).trim();
                    else if (line.startsWith("face ")) {
                        const rest = line.slice(5);
                        const i = rest.indexOf(" ");
                        if (i > 0) {
                            stamp = Number(rest.slice(0, i)) || 0;
                            face = rest.slice(i + 1);
                        }
                    } else if (line.trim() === "orig")
                        orig = true;
                }
                root.face = face;
                root.faceStamp = stamp;
                root.hasOriginal = orig;
                // First detection after setting: remember the change time of the new picture (marker in the picker)
                if (root.stampNext) {
                    root.stampNext = false;
                    Config.opts.userPictureStamp = stamp;
                }
            }
        }
    }

    property bool stampNext: false

    // Evaluate once the script has printed everything (last line "OK" or "ERR <reason>")
    Process {
        id: setter

        property bool restore: false

        stdout: StdioCollector {
            onStreamFinished: root.finishSet(this.text)
        }
    }

    function finishSet(out) {
        const lines = String(out).split("\n").map(l => l.trim());
        const err = lines.find(l => l.startsWith("ERR "));
        const ok = lines.indexOf("OK") >= 0;
        root.error = ok ? "" : (err ? err.slice(4).trim() : "Could not set the picture");
        if (ok) {
            root.rev++;
            Config.opts.userPictureFrom = setter.restore ? "" : root.busyPath;
            root.stampNext = true;
        }
        root.busy = false;
        root.busyPath = "";
        root.refresh();
    }

    // Name for hyprlock (Pango markup, therefore escaped), debounced
    onNameChanged: nameWrite.restart()

    Timer {
        id: nameWrite

        interval: 400
        running: true
        onTriggered: nameFile.setText(root.name.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") + "\n")
    }

    FileView {
        id: nameFile

        path: Quickshell.statePath("user-name")
        preload: false
        printErrors: false
    }

    // Pictures and downloads folders (XDG_PICTURES_DIR / XDG_DOWNLOAD_DIR)
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/user-dirs.dirs"
        printErrors: false
        onLoaded: {
            const home = Quickshell.env("HOME");
            const get = key => {
                const m = new RegExp("^\\s*" + key + "=\"([^\"]*)\"", "m").exec(text());
                return m ? m[1].replace(/^\$HOME/, home) : "";
            };
            const p = get("XDG_PICTURES_DIR");
            const d = get("XDG_DOWNLOAD_DIR");
            if (p !== "")
                root.picturesDir = p;
            if (d !== "")
                root.downloadsDir = d;
        }
    }
}
