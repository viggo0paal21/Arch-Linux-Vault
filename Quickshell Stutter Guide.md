# Quickshell Stutter Guide

Why a Quickshell shell stutters, how to find out **which kind** of stutter it is, and how I fixed each one in my shell (`quickshell/`, NVIDIA RTX 3060 Ti, 2560x1440 @ 170 Hz, Hyprland with Lua config).

> Short version: almost every "stutter" is one of three things. **(1)** Quickshell draws too rarely or unevenly (backend, animation timing). **(2)** Quickshell draws evenly, but the motion itself is bad (subpixels, animation restarting). **(3)** Quickshell stops completely for a moment (a freeze) because its main thread is blocked. For (3) the cause in my case was a file in the home folder (see [section 6](#6-freezes-on-every-terminal-command-the-main-cause)).

## Contents

1. [Measuring tools](#1-measuring-tools)
2. [Low FPS on NVIDIA](#2-low-fps-on-nvidia)
3. [Animations look "interpolated" / wobbly](#3-animations-look-interpolated--wobbly)
4. [Pixel wobble, zigzag, "snapping in"](#4-pixel-wobble-zigzag-snapping-in)
5. [Animation snaps or jumps](#5-animation-snaps-or-jumps) (incl. optional subpixel glide)
6. [Freezes on every terminal command (the main cause)](#6-freezes-on-every-terminal-command-the-main-cause)
7. [Freezes when opening panels, notifications, switching workspaces](#7-freezes-when-opening-panels-notifications-switching-workspaces)
8. [Other programs that freeze Quickshell](#8-other-programs-that-freeze-quickshell)
9. [Dead ends: what it was NOT](#9-dead-ends-what-it-was-not)
10. [Checklist](#10-checklist)

---

## 1. Measuring tools

Measure first, then fix. Without measuring I spent hours looking in the wrong place.

| Tool | What it shows |
|---|---|
| **FPS counter** (Settings > Behavior > FPS counter, `FpsOverlay.qml`) | fps and the **longest frame** per second. 170 Hz = ~6 ms. Normal when idle: max 7–23 ms. Anything from ~50 ms up is a visible freeze |
| **Screen recording, frame by frame** | For motion problems: record a video, split it with `ffmpeg -i clip.mp4 f%04d.png` and measure the position of an icon in every frame. Shows right away whether the bar moves evenly, stops or jumps |
| `qs log` | Quickshell log. `qs log --rules "category*=true"` also shows the **debug messages** that are hidden otherwise (e.g. `quickshell.desktopentry`) |
| `strace -tt -T -p PID -o /tmp/qs.trace` | Every system call of the main thread with its duration. Shows whether Quickshell is **waiting** for something (long calls) or **busy** (very many short calls) |
| `perf record -g -p PID` | Which functions the CPU time goes to. A flat profile = Quickshell isn't computing much, the problem is waiting or short bursts of work |
| `inotifywait -m -e create,delete,move ~` | Which files are being created, deleted or renamed in the home folder right now (important for [section 6](#6-freezes-on-every-terminal-command-the-main-cause)) |

**Timestamp trick:** to match a freeze to an event, log both with `Date.now() % 100000`: in the FPS overlay every frame gap > 25 ms, in `Hypr.qml` every Hyprland event (`onRawEvent`). In my case every freeze started **exactly ~100 ms** after an event. That fixed delay was the decisive clue.

**Main thread or drawing?** A second `Timer { interval: 4 }` that logs gaps > 25 ms shows whether the main thread (QML/JS) itself is blocked. In my case both stopped at the same time: the main thread was blocked.

PID of the running shell: `pgrep -o -x qs || pgrep -o -x quickshell`

---

## 2. Low FPS on NVIDIA

**Symptom:** the shell runs at 60 or ~85 fps instead of 170, animations stutter.

**Cause:** with OpenGL on NVIDIA, Qt uses the "basic" render loop and doesn't reach the full refresh rate.

**Fix** (in `home/.local/bin/qs-start` and the wrappers `qs` / `quickshell`, see the [Quickshell Guide](Quickshell%20Guide.md#3-why-the-start-script-exists-nvidia)):

```bash
export QSG_RHI_BACKEND=vulkan          # Vulkan instead of OpenGL
export MANGOHUD=0 DISABLE_LSFGVK=1 DISABLE_VKBASALT=1   # no Vulkan layers in the shell
unset LD_PRELOAD
```

and in `shell.qml`: `//@ pragma Env QSG_RENDER_LOOP=threaded`

Important: only start **one** instance (`qs kill` first). Two instances at the same time made Vulkan freeze for me.

---

## 3. Animations look "interpolated" / wobbly

**Symptom:** motion looks like frame generation (30 fps upscaled to 120), edges wobble, uneven speed. Only in the shell, not with windows.

**Cause:** Qt's default animation driver advances in fixed time steps per frame. If frame times vary (NVIDIA + Vulkan), the animation time no longer matches the real time.

**Fix:** `export QSG_USE_SIMPLE_ANIMATION_DRIVER=1` in the start script and both wrappers. Animations then follow the real clock.

Check that it's active:

```bash
tr '\0' '\n' < /proc/$(pgrep -xo 'qs|quickshell')/environ | grep SIMPLE
```

---

## 4. Pixel wobble, zigzag, "snapping in"

**Symptom:** the bar wobbles 1–2 px back and forth while docking, icons and background shift against each other, the bar moves in a zigzag instead of a straight diagonal, or the last pixel "clicks" in at the end.

**Cause:** positions between two pixels (subpixels).
- Text and icons are rounded to whole pixels, an antialiased rectangle isn't. If both move together, they constantly shift against each other by up to 1 px.
- If x and y are rounded **separately**, the bar jumps sideways only, then upward only: zigzag.
- If the top and bottom edges are rounded separately, the bar is 1 px thinner or thicker for single frames.

**Fix: everything on whole pixels, from ONE counter** (`quickshell/modules/bar/Bar.qml`):

```qml
// height above the edge in whole pixels; the side gap is derived from it,
// so side and height always step in the same frame
readonly property int offset: Math.round(Config.opts.barFloatOffset * frame.progress)
readonly property int edge: Math.round(bar.offset * Theme.gap / Config.opts.barFloatOffset)
readonly property int bottomEdge: bar.offset + Theme.barHeight + bar.dockExtra
```

The same pattern applies to all other animations: **animate smoothly internally, draw on whole pixels.**

```qml
property real w: isActive ? 26 : 10   // gets animated
width: Math.round(w)                  // gets drawn
Behavior on w { Anim {} }             // NOT "Behavior on width"
```

Rebuilt this way: workspace pills, switch knob, slider knob, progress bars, launcher height. `Theme.px()` always rounds (it used to only round without "Smooth text"). Notification cards always draw on whole pixels with a counter offset (`transform: Translate { x: Math.round(root.x) - root.x }`).

"Smooth text" (text on subpixels, `Text.QtRendering`) would be the alternative, but it looks blurry.

---

## 5. Animation snaps or jumps

### 5a. Two animations on the same value

**Symptom:** the bar jumps in the last frames, especially when windows animate at the same time. The log says:

```
WARN: Attempting to set another interceptor on QQuickItem_QML_46 property progress - unsupported
```

**Cause:** two `Behavior on progress` on the same value (in my case from a pasted-in code block). On top of that, a `Behavior` got re-triggered every time the window count was recalculated. Hyprland reports several events in quick succession when a window opens or closes.

**Fix:** no `Behavior` anymore, but an animation of its own that **only starts when the target really changes**. All events of one pass are merged with `Qt.callLater`:

```qml
function syncDock() {
    const target = bar.floatingNow ? 1 : 0;
    if (dockTicker.running && bar.dockTo === target) return;           // already heading there
    if (!dockTicker.running && frame.progress === target) return;      // already there
    bar.dockFrom = frame.progress; bar.dockTo = target; bar.dockElapsed = 0;
    dockTicker.running = true;
}
onFloatingNowChanged: Qt.callLater(bar.syncDock)
```

### 5b. Jump after a freeze

**Symptom:** the bar stops for 4–5 frames in the middle of the animation and then jumps 2–3 px at once.

**Cause:** a normal animation runs by the clock. If Quickshell doesn't draw for 70 ms (see [section 6](#6-freezes-on-every-terminal-command-the-main-cause)), it catches up on the missed time in a single frame afterwards.

**Fix:** compute the animation yourself as a `FrameAnimation`, where every frame counts at most 1/60 s. After a freeze it continues where it was:

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

(`curveAt` evaluates a bezier curve, see `Bar.qml`.)

### 5c. Optional: subpixel glide

Whole pixels are crisp, but a bar that only moves ~10 px moves in ~10 visible steps. That's fine at normal speed, but visible in slow motion. Hyprland draws windows *between* pixels, which is why they look stepless.

**Settings > Bar > Subpixel glide** does the same for the bar, but only while the dock animation runs:
- The bar keeps its whole-pixel position; only the leftover to the exact position (below 1 px) is added.
- The background draws that leftover with antialiasing; the left and right content are each rendered as one image (`layer.enabled` + `layer.smooth`) and shifted by it. Since each side is a single image, nothing can wobble against each other.
- At rest everything is back on whole pixels and crisp. Off = exactly the whole-pixel behavior.

Two traps found by measuring a recording frame by frame:
- **The right side jumped 1 px at the start and end.** The right row was anchored to the right edge with a fractional width (text widths like "73%"), so it started between two pixels. Drawn as an image it landed 1 px further right than drawn normally. Fix: give both rows a whole-pixel position and width (`x: Math.round(...)`, `width: Math.ceil(implicitWidth)`).
- **A dark line under the bar while docking.** With the bottom edge between two pixels, the last row is only half covered. Hyprland only blurs behind pixels above `ignore_alpha` (0.5), so that row gets no blur and the window below shows through darkly. Fix: the bottom edge stays on whole pixels even with glide.

---

## 6. Freezes on every terminal command (the main cause)

**Symptom:**
- The FPS counter jumps to **60–130 ms** when opening or closing kitty and on **every command** in the terminal (even `command not found`), sometimes also when switching focus.
- Other programs (Nautilus, OpenGL test programs) don't trigger it.
- foot stutters with starship, but not without it.

**What the measurements showed:**
1. Every freeze starts **~100 ms** after the event, always the same.
2. The main thread stops too, not just drawing. With OpenGL instead of Vulkan it was the same, so Vulkan and the driver are ruled out.
3. `strace`: no long system call, but bursts of ~1000 calls in 50 ms, among them **exactly 194× `newfstatat("/etc/localtime")` + 194× `write` to an eventfd**. That's the pattern of 194 log messages (timestamp + waking the log thread).
4. `qs log --rules "*=true"`: the messages are `quickshell.desktopentry: Found desktop entry …` / `Replacing old entry …`. Quickshell re-reads **all ~194 `.desktop` files**.

**Cause (in the Quickshell source, `src/core/desktopentrymonitor.cpp`):**
- `DesktopEntries` (the app list for the launcher) watches the `applications` folders **and all their parent folders**: `~/.local/share`, `~/.local`, **`~`**, `/home`, `/`.
- As soon as a file is **created, deleted or renamed** in one of them, Quickshell waits 100 ms (debounce) and then re-reads every `.desktop` file.
- zsh does exactly that on every command and when a shell opens or closes: it creates `~/.zsh_history.LOCK` and replaces the history file with a rename.

That's why it only stuttered with terminals running zsh.

**Fix:** move the history out of `~` into a folder Quickshell doesn't watch:

```bash
mkdir -p ~/.local/state/zsh
mv ~/.zsh_history ~/.local/state/zsh/history
sed -i 's|^HISTFILE=~/.zsh_history|HISTFILE=~/.local/state/zsh/history|' ~/.zshrc
# close all terminals, open a new one
```

Result: freezes of 60–130 ms → max ~13 ms (a normal, slightly longer frame when a window opens).

**Check whether anything else writes to `~`:**

```bash
inotifywait -m -e create,delete,move ~
```

If it stays quiet while you work, you're fine. If a file keeps showing up (e.g. `.lesshst`, `.python_history`, `.wget-hsts`), move it to `~/.local/state` or `~/.cache` the same way with an environment variable.

**Side note:** subfolders like `~/.local/share/sddm/` don't trigger anything. Only the entries of the parent folders themselves are watched, not what's inside them. Files that are only *written to* (without being created or renamed) don't trigger anything either.

---

## 7. Freezes when opening panels, notifications, switching workspaces

### New windows are expensive

**Symptom:** 40–120 ms freezes when opening a panel, when a notification appears or when opening the tray menu.

**Cause:** every new Quickshell window gets a new Wayland surface and, with Vulkan, a new swapchain. Creating that takes noticeably long on NVIDIA. **Resizing** the window rebuilds the swapchain as well.

**Fix:** never close windows, **keep them mapped and move them off the screen** (same size, only the position changes). See `components/OverlayPanel.qml` and `modules/notifications/NotifPopups.qml`:

```qml
visible: win.mapped || !win.fullscreenActive   // only gone completely during fullscreen games (direct scanout)
margins.top: win.mapped ? win.topOffset : -(win.implicitHeight + 64)
mask: Region { item: win.open ? stage : null } // closed: clicks go through
```

Still open: the tray context menu is a real popup (`PopupWindow` with `grabFocus`). Wayland closes such a popup if you keep it open invisibly. It would have to be rebuilt as its own overlay window.

### Invisible panels with blur

**Symptom:** FPS drop (~140 fps) on every workspace switch.

**Cause:** closed panels lay invisible but screen-sized **over** the screen. Hyprland blurred the whole screen for each of them on every switch (`layer_rule` with `blur = true`).

**Fix:** the same solution as above: closed panels sit off the screen, where there's nothing to blur.

---

## 8. Other programs that freeze Quickshell

**fastfetch with GPU temperature:** `"temp": true` in the GPU module queries the temperature from the NVIDIA driver via NVML. That froze Quickshell for ~70 ms on every call. Fix in `fastfetch/config.jsonc`:

```jsonc
{ "type": "gpu", "temp": false, "detectionMethod": "pci" }
```

The same goes for anything that regularly queries `nvidia-smi` or NVML. That's why the shell only queries `nvidia-smi` while the dashboard is open (`SysInfo.qml`, Settings > GPU monitor).

**Output into the session log:** with SDDM, everything programs of the Hyprland session print to the console ends up in `~/.local/share/sddm/wayland-session.log`. That wasn't the cause from section 6, but it's unnecessary. `qs-start` redirects the output to `/dev/null`, the shell's own log is still available with `qs log`.

---

## 9. Dead ends: what it was NOT

So nobody walks these paths again. For my terminal freezes (section 6) it was not:

| Suspect | How it was ruled out |
|---|---|
| Vulkan / NVIDIA driver | Same freezes with `QSG_RHI_BACKEND=opengl` |
| Blur behind the transparent kitty | Nautilus with the same transparency and blur doesn't stutter |
| New OpenGL context per window | `es2gears_wayland` alone on an empty workspace: 0 ms; `kitty -1` (single instance) didn't help |
| kitty resizing | kitty next to Nautilus, only opening/closing Nautilus: 0 ms |
| Window title / text layout | Setting the title with `printf '\e]2;test\a'`: no freeze |
| starship / zsh plugins | starship doesn't write to `~`; the trigger is zsh's own history file. (foot with `zsh -f` didn't stutter because zsh without `.zshrc` doesn't write a history file at all) |
| Priority (`nice`) | `renice -n 0` on all threads: no change |
| GPU clock | The GPU already runs locked at maximum (`nvidia-maxperf-setup.sh`) |

---

## 10. Checklist

If the shell stutters again, in this order:

1. **Turn on the FPS counter.** Constantly low fps → [section 2](#2-low-fps-on-nvidia)/[3](#3-animations-look-interpolated--wobbly). Single spikes ≥ 50 ms → freezes, continue with 2.
2. **When exactly?** Only when opening the shell's own panels or popups → [section 7](#7-freezes-when-opening-panels-notifications-switching-workspaces). On actions in other programs → 3.
3. Run `inotifywait -m -e create,delete,move ~` and repeat the action. If something shows up → [section 6](#6-freezes-on-every-terminal-command-the-main-cause).
4. `qs log --rules "*=true" | tail -3000 | sed 's/^ *[A-Z]* *//' | cut -c1-90 | sort | uniq -c | sort -rn | head` shows which message is being produced in bulk.
5. Motion looks wrong but no spikes in the counter → measure a video frame by frame → [section 4](#4-pixel-wobble-zigzag-snapping-in)/[5](#5-animation-snaps-or-jumps).
6. Search the log for `another interceptor` (duplicate `Behavior`).
