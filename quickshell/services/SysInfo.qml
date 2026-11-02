pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Systemmonitor: CPU, RAM, Temperatur, Netz, Laufwerke, NVIDIA-GPU.
// Teure Abfragen (GPU, Laufwerke) laufen nur, solange das Dashboard offen ist.
Singleton {
    id: root

    readonly property bool detailed: Ui.panel === "dashboard"
    readonly property int historySize: 60

    property real cpu: 0
    property real cpuTemp: 0
    property real memUsed: 0
    property real memTotal: 0
    readonly property real mem: root.memTotal > 0 ? root.memUsed / root.memTotal : 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real uptime: 0
    property real rxRate: 0
    property real txRate: 0

    property bool gpuAvailable: false
    property real gpu: 0
    property real gpuTemp: 0
    property real vramUsed: 0
    property real vramTotal: 0
    property string gpuName: ""

    property var disks: []
    property var cpuHistory: []
    property var gpuHistory: []
    property var rxHistory: []
    property var txHistory: []

    property string tempPath: ""
    property var lastCpu: null
    property var lastNet: null

    function push(arr, v) {
        const out = arr.slice(Math.max(0, arr.length - root.historySize + 1));
        out.push(v);
        return out;
    }

    function formatBytes(b) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let v = Math.max(0, b);
        let i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return (v >= 100 || i === 0 ? v.toFixed(0) : v.toFixed(1)) + " " + units[i];
    }

    function formatRate(b) {
        return root.formatBytes(b) + "/s";
    }

    function formatUptime(sec) {
        const d = Math.floor(sec / 86400);
        const h = Math.floor((sec % 86400) / 3600);
        const m = Math.floor((sec % 3600) / 60);
        if (d > 0)
            return d + "d " + h + "h";
        if (h > 0)
            return h + "h " + m + "m";
        return m + "m";
    }

    function parseStat(text) {
        const line = text.split("\n")[0];
        if (!line.startsWith("cpu "))
            return;
        const n = line.trim().split(/\s+/).slice(1).map(Number);
        const idle = n[3] + (n[4] || 0);
        let total = 0;
        for (let i = 0; i < Math.min(n.length, 8); i++)
            total += n[i];
        if (root.lastCpu) {
            const dt = total - root.lastCpu.total;
            const di = idle - root.lastCpu.idle;
            if (dt > 0)
                root.cpu = Math.max(0, Math.min(1, 1 - di / dt));
        }
        root.lastCpu = {
            idle: idle,
            total: total
        };
        root.cpuHistory = root.push(root.cpuHistory, root.cpu);
    }

    function parseMem(text) {
        const get = key => {
            const m = text.match(new RegExp("^" + key + ":\\s+(\\d+)", "m"));
            return m ? Number(m[1]) * 1024 : 0;
        };
        const total = get("MemTotal");
        const avail = get("MemAvailable");
        root.memTotal = total;
        root.memUsed = Math.max(0, total - avail);
        root.swapTotal = get("SwapTotal");
        root.swapUsed = Math.max(0, root.swapTotal - get("SwapFree"));
    }

    function parseNet(text) {
        let rx = 0;
        let tx = 0;
        const lines = text.split("\n").slice(2);
        for (const l of lines) {
            const parts = l.trim().split(/[:\s]+/);
            if (parts.length < 10 || parts[0] === "lo")
                continue;
            rx += Number(parts[1]) || 0;
            tx += Number(parts[9]) || 0;
        }
        const now = Date.now();
        if (root.lastNet) {
            const dt = (now - root.lastNet.t) / 1000;
            if (dt > 0) {
                root.rxRate = Math.max(0, (rx - root.lastNet.rx) / dt);
                root.txRate = Math.max(0, (tx - root.lastNet.tx) / dt);
            }
        }
        root.lastNet = {
            rx: rx,
            tx: tx,
            t: now
        };
        root.rxHistory = root.push(root.rxHistory, root.rxRate);
        root.txHistory = root.push(root.txHistory, root.txRate);
    }

    function parseGpu(line) {
        const p = line.split(",").map(s => s.trim());
        if (p.length < 5)
            return;
        root.gpu = (Number(p[0]) || 0) / 100;
        root.gpuTemp = Number(p[1]) || 0;
        root.vramUsed = (Number(p[2]) || 0) * 1024 * 1024;
        root.vramTotal = (Number(p[3]) || 0) * 1024 * 1024;
        root.gpuName = p.slice(4).join(", ");
        root.gpuAvailable = true;
        root.gpuHistory = root.push(root.gpuHistory, root.gpu);
    }

    function parseDisks(text) {
        const out = [];
        const lines = text.trim().split("\n").slice(1);
        for (const l of lines) {
            const p = l.trim().split(/\s+/);
            if (p.length < 3)
                continue;
            const mount = p[0];
            if (mount === "/" || mount === "/home" || mount.startsWith("/mnt/") || mount.startsWith("/run/media/")) {
                out.push({
                    mount: mount,
                    size: Number(p[1]) || 0,
                    used: Number(p[2]) || 0
                });
            }
        }
        root.disks = out;
    }

    Timer {
        interval: root.detailed ? 1000 : 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            netdev.reload();
            uptimeFile.reload();
            if (root.tempPath !== "")
                tempFile.reload();
        }
    }

    FileView {
        id: stat

        path: "/proc/stat"
        onLoaded: root.parseStat(text())
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        onLoaded: root.parseMem(text())
    }

    FileView {
        id: netdev

        path: "/proc/net/dev"
        onLoaded: root.parseNet(text())
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        onLoaded: root.uptime = Number(text().split(" ")[0]) || 0
    }

    FileView {
        id: tempFile

        path: root.tempPath
        onLoaded: root.cpuTemp = (Number(text().trim()) || 0) / 1000
    }

    // CPU-Temperatursensor einmalig suchen (Intel coretemp, AMD k10temp, ...)
    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do n=$(cat \"$d/name\" 2>/dev/null); case \"$n\" in coretemp|k10temp|zenpower|cpu_thermal) [ -r \"$d/temp1_input\" ] && echo \"$d/temp1_input\" && exit 0;; esac; done; for z in /sys/class/thermal/thermal_zone*; do case \"$(cat \"$z/type\" 2>/dev/null)\" in x86_pkg_temp|cpu*|acpitz) echo \"$z/temp\"; exit 0;; esac; done; exit 0"]
        stdout: StdioCollector {
            onStreamFinished: root.tempPath = this.text.trim()
        }
    }

    // NVIDIA: ein dauerhafter nvidia-smi-Prozess (alle 2 s), nur bei offenem Dashboard
    Process {
        id: gpuProc

        running: root.detailed && Config.opts.gpuMonitor
        command: ["sh", "-c", "command -v nvidia-smi >/dev/null 2>&1 || exit 0; exec nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,name --format=csv,noheader,nounits -l 2"]
        stdout: SplitParser {
            onRead: data => root.parseGpu(data)
        }
    }

    Process {
        id: diskProc

        command: ["df", "-B1", "--output=target,size,used"]
        stdout: StdioCollector {
            onStreamFinished: root.parseDisks(this.text)
        }
    }

    Timer {
        interval: 30000
        running: root.detailed
        repeat: true
        triggeredOnStart: true
        onTriggered: diskProc.running = true
    }
}
