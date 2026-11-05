# Quickshell Stutter Guide

Warum eine Quickshell-Shell ruckelt, wie man herausfindet, **welche** Art Ruckler es ist, und wie ich jede davon in meiner Shell (`quickshell/`, NVIDIA RTX 3060 Ti, 2560x1440 @ 170 Hz, Hyprland mit Lua-Config) behoben habe.

> Kurzfassung: Fast jeder "Ruckler" ist eine von drei Sachen. **(1)** Quickshell zeichnet zu selten oder ungleichmäßig (Backend, Animationstakt). **(2)** Quickshell zeichnet gleichmäßig, aber die Bewegung selbst ist schlecht (Subpixel, Kurve, Animation startet neu). **(3)** Quickshell steht kurz komplett still (Hänger), weil sein Hauptthread blockiert ist. Für (3) war bei mir die Ursache eine Datei im Home-Ordner (siehe [Abschnitt 6](#6-hänger-bei-jedem-terminal-befehl-die-hauptursache)).

## Inhalt

1. [Werkzeuge zum Messen](#1-werkzeuge-zum-messen)
2. [Zu wenig FPS auf NVIDIA](#2-zu-wenig-fps-auf-nvidia)
3. [Animationen wirken "interpoliert" / wabbelig](#3-animationen-wirken-interpoliert--wabbelig)
4. [Pixel-Wackeln, Zickzack, "Einrasten"](#4-pixel-wackeln-zickzack-einrasten)
5. [Animation "snappt", bricht ab oder steht am Ende still](#5-animation-snappt-bricht-ab-oder-steht-am-ende-still)
6. [Hänger bei jedem Terminal-Befehl (die Hauptursache)](#6-hänger-bei-jedem-terminal-befehl-die-hauptursache)
7. [Hänger beim Öffnen von Panels, Benachrichtigungen, Workspace-Wechsel](#7-hänger-beim-öffnen-von-panels-benachrichtigungen-workspace-wechsel)
8. [Andere Programme, die Quickshell einfrieren](#8-andere-programme-die-quickshell-einfrieren)
9. [Sackgassen: was es NICHT war](#9-sackgassen-was-es-nicht-war)
10. [Checkliste](#10-checkliste)

---

## 1. Werkzeuge zum Messen

Erst messen, dann fixen. Ohne Messung habe ich stundenlang an der falschen Stelle gesucht.

| Werkzeug | Was es zeigt |
|---|---|
| **FPS-Counter** (Settings > Behavior > FPS counter, `FpsOverlay.qml`) | fps und den **längsten Frame** pro Sekunde. 170 Hz = ~6 ms. Normal im Leerlauf: max 7–23 ms. Alles ab ~50 ms ist ein sichtbarer Hänger |
| **Bildschirmvideo Frame für Frame** | Bei Bewegungsproblemen: Video aufnehmen, mit `ffmpeg -i clip.mp4 f%04d.png` zerlegen und pro Frame die Position eines Icons messen. Zeigt sofort, ob die Leiste gleichmäßig läuft, stehen bleibt oder springt |
| `qs log` | Quickshell-Log. Mit `qs log --rules "kategorie*=true"` sieht man auch die **Debug-Meldungen**, die sonst versteckt sind (z. B. `quickshell.desktopentry`) |
| `strace -tt -T -p PID -o /tmp/qs.trace` | Jeden Systemaufruf des Hauptthreads mit Dauer. Zeigt, ob Quickshell auf etwas **wartet** (lange Aufrufe) oder **beschäftigt** ist (sehr viele kurze Aufrufe) |
| `perf record -g -p PID` | In welchen Funktionen die CPU-Zeit landet. Flaches Profil = Quickshell rechnet nicht viel, das Problem ist Warten oder kurze Arbeitsschübe |
| `inotifywait -m -e create,delete,move ~` | Welche Dateien gerade im Home-Ordner angelegt, gelöscht oder umbenannt werden (wichtig für [Abschnitt 6](#6-hänger-bei-jedem-terminal-befehl-die-hauptursache)) |

**Zeitstempel-Trick:** Wer einen Hänger einem Ereignis zuordnen will, loggt beides mit `Date.now() % 100000`: im FPS-Overlay jede Frame-Lücke > 25 ms, in `Hypr.qml` jedes Hyprland-Ereignis (`onRawEvent`). Bei mir begann jeder Hänger **genau ~100 ms** nach einem Ereignis. Diese feste Verzögerung war der entscheidende Hinweis.

**Hauptthread oder Zeichnen?** Ein zweiter `Timer { interval: 4 }`, der Lücken > 25 ms loggt, zeigt, ob der Hauptthread (QML/JS) selbst blockiert ist. Bei mir hingen beide gleichzeitig: Der Hauptthread war blockiert.

PID der laufenden Shell: `pgrep -o -x qs || pgrep -o -x quickshell`

---

## 2. Zu wenig FPS auf NVIDIA

**Symptom:** Shell läuft mit 60 oder ~85 fps statt 170, Animationen haken.

**Ursache:** Qt nutzt auf NVIDIA mit OpenGL den "basic" Render-Loop und kommt nicht auf die volle Bildwiederholrate.

**Fix** (in `home/.local/bin/qs-start` und den Wrappern `qs` / `quickshell`, siehe [Quickshell Guide](Quickshell%20Guide.md#3-why-the-start-script-exists-nvidia)):

```bash
export QSG_RHI_BACKEND=vulkan          # Vulkan statt OpenGL
export MANGOHUD=0 DISABLE_LSFGVK=1 DISABLE_VKBASALT=1   # keine Vulkan-Layer in der Shell
unset LD_PRELOAD
```

und in `shell.qml`: `//@ pragma Env QSG_RENDER_LOOP=threaded`

Wichtig: Nur **eine** Instanz starten (`qs kill` vorher). Zwei Instanzen gleichzeitig haben Vulkan bei mir einfrieren lassen.

---

## 3. Animationen wirken "interpoliert" / wabbelig

**Symptom:** Bewegungen sehen aus wie Frame-Generation (30 fps auf 120 hochgerechnet), Kanten wabern, Tempo ungleichmäßig. Nur in der Shell, nicht bei Fenstern.

**Ursache:** Qts Standard-Animationstreiber rechnet in festen Zeitschritten pro Frame. Schwanken die Frame-Zeiten (NVIDIA + Vulkan), passt die Animationszeit nicht mehr zur echten Zeit.

**Fix:** `export QSG_USE_SIMPLE_ANIMATION_DRIVER=1` im Startskript und in beiden Wrappern. Animationen laufen dann nach der echten Uhrzeit.

Prüfen, ob es aktiv ist:

```bash
tr '\0' '\n' < /proc/$(pgrep -xo 'qs|quickshell')/environ | grep SIMPLE
```

---

## 4. Pixel-Wackeln, Zickzack, "Einrasten"

**Symptom:** Die Leiste wackelt beim Andocken 1–2 px hin und her, Icons und Hintergrund verschieben sich gegeneinander, die Leiste läuft im Zickzack statt gerade schräg, oder der letzte Pixel "klickt" am Ende nach.

**Ursache:** Positionen zwischen zwei Pixeln (Subpixel).
- Text und Icons werden auf ganze Pixel gerundet, ein Rechteck mit Kantenglättung nicht. Laufen beide mit, verschieben sie sich ständig um bis zu 1 px gegeneinander.
- Werden x und y **getrennt** gerundet, springt die Leiste mal nur seitlich, mal nur nach oben: Zickzack.
- Werden Ober- und Unterkante getrennt gerundet, ist die Leiste für einzelne Frames 1 px dünner oder dicker.

**Fix: alles auf ganze Pixel, aus EINEM Zähler** (`quickshell/modules/bar/Bar.qml`):

```qml
// Hoehe ueber dem Rand in ganzen Pixeln; der Seitenabstand wird daraus abgeleitet,
// damit Seite und Hoehe immer im selben Frame springen
readonly property int offset: Math.round(Config.opts.barFloatOffset * frame.progress)
readonly property int edge: Math.round(bar.offset * Theme.gap / Config.opts.barFloatOffset)
readonly property int bottomEdge: bar.offset + Theme.barHeight + bar.dockExtra
```

Für alle anderen Animationen gilt dasselbe Muster: **intern weich animieren, auf ganze Pixel zeichnen.**

```qml
property real w: isActive ? 26 : 10   // wird animiert
width: Math.round(w)                  // wird gezeichnet
Behavior on w { Anim {} }             // NICHT "Behavior on width"
```

So umgebaut: Workspace-Pillen, Schalter-Knopf, Slider-Knopf, Fortschrittsbalken, Launcher-Höhe. `Theme.px()` rundet immer (vorher nur ohne "Smooth text"). Benachrichtigungskarten zeichnen sich per Gegen-Versatz immer auf ganzen Pixeln (`transform: Translate { x: Math.round(root.x) - root.x }`).

"Smooth text" (Text auf Subpixeln, `Text.QtRendering`) wäre die Alternative, sieht aber unscharf aus.

---

## 5. Animation "snappt", bricht ab oder steht am Ende still

### 5a. Doppelte Animation auf demselben Wert

**Symptom:** Die Leiste springt in den letzten Frames, vor allem wenn Fenster gleichzeitig animieren. Im Log steht:

```
WARN: Attempting to set another interceptor on QQuickItem_QML_46 property progress - unsupported
```

**Ursache:** Zwei `Behavior on progress` auf demselben Wert (bei mir durch einen hineinkopierten Codeblock). Dazu wurde ein `Behavior` bei jeder Neuberechnung der Fensterzahl neu angestoßen. Hyprland meldet beim Öffnen und Schließen mehrere Ereignisse kurz nacheinander.

**Fix:** Kein `Behavior` mehr, sondern eine eigene Animation, die **nur startet, wenn sich das Ziel wirklich ändert**. Alle Ereignisse eines Durchlaufs werden mit `Qt.callLater` zusammengefasst:

```qml
function syncDock() {
    const target = bar.floatingNow ? 1 : 0;
    if (dockTicker.running && bar.dockTo === target) return;           // laeuft schon dorthin
    if (!dockTicker.running && frame.progress === target) return;      // ist schon da
    bar.dockFrom = frame.progress; bar.dockTo = target; bar.dockElapsed = 0;
    dockTicker.running = true;
}
onFloatingNowChanged: Qt.callLater(bar.syncDock)
```

### 5b. Sprung nach einem Hänger

**Symptom:** Die Leiste bleibt mitten in der Animation 4–5 Frames stehen und springt dann 2–3 px auf einmal.

**Ursache:** Eine normale Animation läuft nach der Uhr. Zeichnet Quickshell 70 ms lang nicht (siehe [Abschnitt 6](#6-hänger-bei-jedem-terminal-befehl-die-hauptursache)), holt sie die verpasste Zeit danach in einem Frame nach.

**Fix:** Die Animation als `FrameAnimation` selbst rechnen, wobei jeder Frame höchstens 1/60 s zählt. Nach einem Hänger geht sie dort weiter, wo sie stand:

```qml
FrameAnimation {
    id: dockTicker
    onTriggered: {
        bar.dockElapsed += Math.min(dockTicker.frameTime, 1 / 60) * 1000;
        const u = Math.min(1, bar.dockElapsed / Config.opts.barDockDuration);
        frame.progress = bar.dockFrom + (bar.dockTo - bar.dockFrom) * bar.curveAt(Theme.curveOf(Config.opts.animBarCurve), u);
        if (u >= 1) dockTicker.running = false;
    }
}
```

(`curveAt` rechnet eine Bezier-Kurve aus, siehe `Bar.qml`.)

### 5c. Die Kurve passt nicht zu ganzen Pixeln

**Symptom:** Die Leiste ist nach ~45 % der Animationszeit fertig und steht dann still, während das Fenster noch gleitet. Die ersten Schritte kommen im Millisekundenabstand, die letzten erst nach ~100 ms.

**Ursache:** Die Leiste bewegt sich nur 8–10 px, also nur 8–10 Pixelschritte. "Smooth out" (easeOutQuint) legt fast alle davon an den Anfang. Hyprland zeichnet Fenster auf Subpixeln, deshalb sieht dieselbe Kurve dort weich aus. Mit ganzen Pixeln zählt nur, wie gleichmäßig die Schritte über die Zeit verteilt sind.

**Fix:** Leisten-Kurve auf **"Ease in-out"** (inOutSine): Bei 300 ms kommt etwa alle 20–30 ms ein Schritt, am Anfang und Ende etwas langsamer. "Linear" verteilt sie exakt gleichmäßig. Das Fenster ist am Anfang trotzdem schneller als die Leiste, beim Andocken schiebt es sich also immer **unter** die Leiste. Deshalb blitzt keine Linie auf.

---

## 6. Hänger bei jedem Terminal-Befehl (die Hauptursache)

**Symptom:**
- Der FPS-Counter springt auf **60–130 ms**, wenn man kitty öffnet oder schließt und bei **jedem Befehl** im Terminal (sogar bei `command not found`), manchmal auch beim Fokuswechsel.
- Andere Programme (Nautilus, OpenGL-Testprogramme) lösen es nicht aus.
- foot ruckelt mit starship, ohne nicht.

**Was die Messung gezeigt hat:**
1. Jeder Hänger beginnt **~100 ms** nach dem Ereignis, immer gleich.
2. Auch der Hauptthread steht still, nicht nur das Zeichnen. Mit OpenGL statt Vulkan war es genauso, Vulkan und Treiber scheiden also aus.
3. `strace`: kein langer Systemaufruf, aber Schübe von ~1000 Aufrufen in 50 ms, darunter **genau 194× `newfstatat("/etc/localtime")` + 194× `write` auf ein eventfd**. Das ist das Muster von 194 Log-Meldungen (Zeitstempel + Log-Thread wecken).
4. `qs log --rules "*=true"`: Die Meldungen sind `quickshell.desktopentry: Found desktop entry …` bzw. `Replacing old entry …`. Quickshell liest **alle ~194 `.desktop`-Dateien** neu ein.

**Ursache (im Quickshell-Quellcode, `src/core/desktopentrymonitor.cpp`):**
- `DesktopEntries` (die App-Liste für den Launcher) beobachtet die `applications`-Ordner **und alle ihre Elternordner**: `~/.local/share`, `~/.local`, **`~`**, `/home`, `/`.
- Sobald in einem davon eine Datei **angelegt, gelöscht oder umbenannt** wird, wartet Quickshell 100 ms (Debounce) und liest dann alle `.desktop`-Dateien neu.
- zsh macht genau das bei jedem Befehl und beim Öffnen und Schließen einer Shell: Es legt `~/.zsh_history.LOCK` an und ersetzt die History-Datei per Umbenennen.

Darum hat es nur bei Terminals mit zsh geruckelt.

**Fix:** Die History aus `~` heraus in einen Ordner, den Quickshell nicht beobachtet:

```bash
mkdir -p ~/.local/state/zsh
mv ~/.zsh_history ~/.local/state/zsh/history
sed -i 's|^HISTFILE=~/.zsh_history|HISTFILE=~/.local/state/zsh/history|' ~/.zshrc
# alle Terminals schliessen, neu oeffnen
```

Ergebnis: Hänger von 60–130 ms → max ~13 ms (ein normaler etwas längerer Frame beim Fenster-Öffnen).

**Prüfen, ob noch etwas in `~` schreibt:**

```bash
inotifywait -m -e create,delete,move ~
```

Läuft das ruhig, während man arbeitet, ist alles gut. Taucht eine Datei ständig auf (z. B. `.lesshst`, `.python_history`, `.wget-hsts`), verschiebt man sie genauso per Umgebungsvariable nach `~/.local/state` oder `~/.cache`.

**Nebenbei:** Unterordner wie `~/.local/share/sddm/` lösen nichts aus. Beobachtet werden nur die Einträge der Elternordner selbst, nicht ihr Inhalt. Dateien, die nur *beschrieben* werden (ohne Anlegen oder Umbenennen), lösen auch nichts aus.

---

## 7. Hänger beim Öffnen von Panels, Benachrichtigungen, Workspace-Wechsel

### Neue Fenster sind teuer

**Symptom:** 40–120 ms Hänger beim Öffnen eines Panels, beim Erscheinen einer Benachrichtigung oder beim Öffnen des Tray-Menüs.

**Ursache:** Jedes neue Quickshell-Fenster bekommt eine neue Wayland-Fläche und mit Vulkan eine neue Swapchain. Das Anlegen dauert auf NVIDIA spürbar lange. Eine **Größenänderung** des Fensters baut die Swapchain ebenfalls neu auf.

**Fix:** Fenster nie schließen, sondern **gemappt lassen und aus dem Bildschirm schieben** (gleiche Größe, nur Position ändern). Siehe `components/OverlayPanel.qml` und `modules/notifications/NotifPopups.qml`:

```qml
visible: win.mapped || !win.fullscreenActive   // nur bei Vollbild-Spielen ganz weg (Direct Scanout)
margins.top: win.mapped ? win.topOffset : -(win.implicitHeight + 64)
mask: Region { item: win.open ? stage : null } // geschlossen: Klicks gehen durch
```

Offen: Das Tray-Kontextmenü ist ein echtes Popup (`PopupWindow` mit `grabFocus`). Wayland schließt so ein Popup, wenn man es unsichtbar offen hält. Es müsste als eigenes Overlay-Fenster neu gebaut werden.

### Unsichtbare Panels mit Blur

**Symptom:** FPS-Einbruch (~140 fps) bei jedem Workspace-Wechsel.

**Ursache:** Geschlossene Panels lagen unsichtbar, aber bildschirmgroß **über** dem Bildschirm. Hyprland hat für jedes davon bei jedem Wechsel den ganzen Bildschirm geblurrt (`layer_rule` mit `blur = true`).

**Fix:** Dieselbe Lösung wie oben: Geschlossene Panels liegen außerhalb des Bildschirms, dort gibt es nichts zu blurren.

---

## 8. Andere Programme, die Quickshell einfrieren

**fastfetch mit GPU-Temperatur:** `"temp": true` im GPU-Modul fragt die Temperatur über NVML beim NVIDIA-Treiber ab. Das ließ Quickshell bei jedem Aufruf ~70 ms hängen. Fix in `fastfetch/config.jsonc`:

```jsonc
{ "type": "gpu", "temp": false, "detectionMethod": "pci" }
```

Dasselbe gilt für alles, was regelmäßig `nvidia-smi` oder NVML abfragt. Die Shell fragt `nvidia-smi` deshalb nur bei offenem Dashboard ab (`SysInfo.qml`, Settings > GPU monitor).

**Ausgabe ins Session-Log:** Alles, was Programme der Hyprland-Sitzung auf die Konsole schreiben, landet unter SDDM in `~/.local/share/sddm/wayland-session.log`. Das war nicht die Ursache aus Abschnitt 6, ist aber unnötig. `qs-start` leitet die Ausgabe nach `/dev/null` um, das eigene Log gibt es weiter mit `qs log`.

---

## 9. Sackgassen: was es NICHT war

Damit man diese Wege nicht noch einmal geht. Bei meinen Terminal-Hängern (Abschnitt 6) war es nicht:

| Verdacht | Wie ausgeschlossen |
|---|---|
| Vulkan / NVIDIA-Treiber | Mit `QSG_RHI_BACKEND=opengl` dieselben Hänger |
| Blur hinter transparentem kitty | Nautilus mit gleicher Transparenz und Blur ruckelt nicht |
| Neuer OpenGL-Kontext pro Fenster | `es2gears_wayland` allein auf leerem Workspace: 0 ms; `kitty -1` (eine Instanz) half nicht |
| Größenänderung von kitty | kitty neben Nautilus, nur Nautilus öffnen/schließen: 0 ms |
| Fenstertitel / Text-Layout | Titel per `printf '\e]2;test\a'` setzen: kein Hänger |
| starship / zsh-Plugins | starship schreibt nichts nach `~`; der Auslöser ist die History-Datei von zsh selbst. (foot mit `zsh -f` ruckelte nicht, weil zsh ohne `.zshrc` gar keine History-Datei schreibt) |
| Priorität (`nice`) | `renice -n 0` auf alle Threads: keine Änderung |
| GPU-Takt | GPU läuft schon fest auf Maximum (`nvidia-maxperf-setup.sh`) |

---

## 10. Checkliste

Wenn die Shell wieder ruckelt, in dieser Reihenfolge:

1. **FPS-Counter an.** Dauerhaft niedrige fps → [Abschnitt 2](#2-zu-wenig-fps-auf-nvidia)/[3](#3-animationen-wirken-interpoliert--wabbelig). Einzelne Spitzen ≥ 50 ms → Hänger, weiter mit 2.
2. **Wann genau?** Nur beim Öffnen eigener Panels oder Popups → [Abschnitt 7](#7-hänger-beim-öffnen-von-panels-benachrichtigungen-workspace-wechsel). Bei Aktionen in anderen Programmen → 3.
3. `inotifywait -m -e create,delete,move ~` laufen lassen und die Aktion wiederholen. Taucht etwas auf → [Abschnitt 6](#6-hänger-bei-jedem-terminal-befehl-die-hauptursache).
4. `qs log --rules "*=true" | tail -3000 | sed 's/^ *[A-Z]* *//' | cut -c1-90 | sort | uniq -c | sort -rn | head` zeigt, welche Meldung gerade massenhaft erzeugt wird.
5. Bewegung sieht falsch aus, aber keine Spitzen im Counter → Video Frame für Frame vermessen → [Abschnitt 4](#4-pixel-wackeln-zickzack-einrasten)/[5](#5-animation-snappt-bricht-ab-oder-steht-am-ende-still).
6. Im Log nach `another interceptor` suchen (doppelte `Behavior`).
