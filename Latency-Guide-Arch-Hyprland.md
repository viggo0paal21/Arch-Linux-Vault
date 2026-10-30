# Low-Latency Gaming Guide: Arch Linux, Wayland / Hyprland, NVIDIA

A personal reference for this machine. It explains how a frame gets from a game to the screen, why tearing happens (or doesn't), and how **MangoHud** and **Hyprland window rules** control it.

Read section 1 once to understand the ideas. After that, the [TL;DR](#tldr-the-setup-i-use), the [cheat sheet](#3-behavior-cheat-sheet) and the [recipes](#8-recipes) are what you need day to day.

---

## Contents

1. [The basics in plain words](#1-the-basics-in-plain-words)
2. [What is different on Wayland](#2-what-is-different-on-wayland-vs-windows)
3. [Behavior cheat sheet](#3-behavior-cheat-sheet)
4. [MangoHud](#4-mangohud)
5. [Hyprland](#5-hyprland)
6. [The recommended config (copy & paste)](#6-the-recommended-config-copy--paste)
7. [All setups compared](#7-all-setups-compared)
8. [Recipes](#8-recipes)
9. [Troubleshooting](#9-troubleshooting)
10. [Glossary](#10-glossary)
11. [Sources](#11-sources)

---

## My hardware and software

| Part | What |
|---|---|
| GPU | NVIDIA GeForce RTX 3060 Ti (`nvidia-open` driver) |
| Monitor | ASUS TUF VG27AQL1A, 2560×1440, **170 Hz**, G-Sync compatible, on `DP-1` |
| Compositor | Hyprland 0.56.2 with a self-built tearing patch (see [9.6](#96-tearing-stopped-working-after-a-system-update)), Lua config at `~/.config/hypr/hyprland.lua` |
| FPS limiter / overlay | MangoHud, loaded for every game through `/etc/environment` |
| Games | Proton games (they run through **Xwayland**), CS2 (native Linux, also through Xwayland) |

---

## TL;DR: the setup I use

| Where | Setting | Why |
|---|---|---|
| Hyprland | `general.allow_tearing = true` | Master switch. Needed so CS2 *can* tear. |
| Hyprland | **No** catch-all `immediate` rule (no `tearing-all`) | Nothing tears unless I explicitly say so. |
| Hyprland | Rule `tearing-games`: `class = "cs2"`, `immediate = true` | CS2 tears on purpose for the lowest possible latency. |
| Hyprland | `misc.vrr = 2` | G-Sync (VRR) only for fullscreen windows. |
| Hyprland | Rule `no-tearing-video`: `crunchyroll\|firefox`, `no_vrr = true` | VRR makes video apps flicker. |
| Hyprland | `render.direct_scanout = true` | Skips one copy of the game image. |
| MangoHud (global) | `fps_limit=162`, `fps_limit_method=late`, `vsync=3`, `gl_vsync=1` | Stay inside the G-Sync range, V-Sync as a safety net. |
| MangoHud (`cs2.conf`) | `fps_limit=180`, `fps_limit_method=late`, `vsync=1` | Above 170 Hz and no V-Sync, so CS2 tears. |
| In every game | In-game V-Sync **off**, in-game FPS limiter off | MangoHud handles both. |

**Result:**

- Every normal game: **no tearing**, and practically the same latency as V-Sync off.
- CS2: tears, lowest possible latency.
- Desktop, terminals, browsers, waybar: **never tear**.

---

## 1. The basics in plain words

### 1.1 The monitor is a painter

Think of the monitor as a painter who repaints the whole picture **170 times per second**, always from **top to bottom**. One pass is called a **scanout** and takes 1/170 s ≈ **5.9 ms**. The GPU keeps handing the painter new pictures (frames).

### 1.2 Tearing

If a new frame is handed over while the painter is halfway down the screen, he keeps going with the new frame. The top half shows the old frame, the bottom half the new one. The visible line between them is a **tear**.

- **Downside:** It looks ugly, especially when the camera turns quickly.
- **Upside:** The new image reaches the lower part of the screen a few milliseconds sooner, so **latency is a little lower**.

### 1.3 V-Sync

**V-Sync** means: only switch to a new frame **between** two passes. The painter never mixes two frames, so there is no tearing.

The problem: if the game renders faster than 170 FPS, finished frames **wait in a queue** until the painter is ready. That adds **1 to 3 frames of extra latency** (at 170 Hz about 6 to 18 ms). This is the classic "V-Sync feels laggy" effect.

### 1.4 G-Sync / VRR

**VRR** (Variable Refresh Rate; NVIDIA calls it G-Sync) turns it around: **the painter waits for the GPU.** He starts a new pass as soon as a frame is ready.

- Frames are shown immediately and **never tear**.
- This only works **inside the VRR range**, below 170 Hz. At 170 FPS or more the painter can't go any faster, and you are back to normal V-Sync behavior (or tearing).

### 1.5 Why the FPS cap must be below the refresh rate

To keep G-Sync active, the frame rate must **always** stay below 170. Blur Busters recommends at least 3 FPS below the refresh rate.

Software limiters like MangoHud overshoot a little, and frametimes wobble, so a bit more margin is safer. **162 FPS on 170 Hz (8 below)** gives that margin. A common community rule of thumb, *refresh − refresh × refresh / 4096*, lands at about 163 for 170 Hz, so 162 is in the same range.

### 1.6 G-Sync + V-Sync (the Blur Busters combo)

Inside the G-Sync range, V-Sync almost never has anything to do. It only acts on the rare frame that arrives **too early** (a frametime spike): that one frame is held back for a tiny moment instead of tearing at the bottom of the screen.

Blur Busters measured this: **practically no added latency.** The only "advantage" of V-Sync off with G-Sync is the tearing itself.

> **Rule:** G-Sync on + V-Sync on + FPS cap below the refresh rate = **lowest latency without tearing.**

---

## 2. What is different on Wayland (vs. Windows)

### 2.1 Two steps instead of one

On Windows in fullscreen, a game hands its frames more or less directly to the driver. That's why one V-Sync setting in the NVIDIA Control Panel decides everything.

On Wayland the **compositor** (Hyprland) always sits in between:

```
Game  ──(step 1: present mode)──▶  Hyprland  ──(step 2: page flip)──▶  Monitor
```

- **Step 1, game → Hyprland:** *How* the game hands frames to Hyprland. This is what MangoHud's `vsync` setting changes, and what the `present_mode` line in the MangoHud HUD shows (FIFO, IMMEDIATE, …).
- **Step 2, Hyprland → monitor:** *When* Hyprland tells the GPU to switch the screen to the new frame (the **page flip**). Only Hyprland decides this.

> **Key idea:** MangoHud's V-Sync only controls step 1. Tearing happens in step 2. Hyprland decides it.

### 2.2 When does Hyprland tear?

By default Hyprland flips **synchronously**: it waits until the monitor is ready (with G-Sync that is usually right away, because the monitor is waiting for the frame). An **immediate flip** (= tearing) only happens when **all** of these are true:

1. `general.allow_tearing = true` (master switch)
2. The window **either** has an `immediate = true` window rule, **or** the app itself asks for tearing (through the Wayland "tearing-control" protocol)
3. The window is **fullscreen** and the **only thing visible** on that monitor. No bar, popup, notification or overlay may be on top of it.

You can check it while the game runs: `hyprctl monitors` shows `activelyTearing` and `tearingBlockedBy` (see [5.7](#57-useful-commands)).

**That's why the desktop never tears:** windows, terminals, waybar and workspace switches never meet point 3.

### 2.3 The NVIDIA + Xwayland catch

Who sends the "I want tearing" request from point 2? The **graphics driver**, when a game uses a no-V-Sync present mode.

On this machine (NVIDIA, games through Xwayland) **that request never arrives.** Measured: CS2 with MangoHud `vsync=1` (IMMEDIATE) and no rule still showed `tearingBlockedBy: next frame is not torn,window settings`.

So for Xwayland games, Hyprland **cannot tell** `vsync=1` from `vsync=3`.

> **For Xwayland games on NVIDIA, the window rule is the tearing switch, not MangoHud.**

Good to know:

- **AMD / Intel (Mesa driver):** There the driver *does* send the request. MangoHud's `vsync` alone would decide about tearing. Not the case here.
- **Native Wayland Vulkan apps on NVIDIA:** Since driver 555, NVIDIA supports the IMMEDIATE present mode on Wayland and sends the request. So a native Wayland game with V-Sync off could tear even without a rule, because `allow_tearing = true`. The global `vsync=3` prevents that. *(Not tested on this machine.)*
- **Future option:** GE-Proton with the launch option `PROTON_ENABLE_WAYLAND=1` runs Proton games as native Wayland apps. Then MangoHud's `vsync` could become the tearing switch. It is experimental, and early reports said it works worse on NVIDIA than on AMD.

### 2.4 What the `immediate` rule does to the game's V-Sync

Under Wayland, "V-Sync on" in a game really means: *"wait until Hyprland says the last frame was shown."*

With an `immediate` rule, Hyprland shows every frame at once and answers at once. The game's V-Sync has **nothing to wait for** anymore and basically acts like V-Sync off.

Measured: while a catch-all `immediate` rule was active, Half-Life 2 with MangoHud `vsync=3` (the HUD said FIFO) ran at 180 FPS and tore.

> **Only give the `immediate` rule to games that are supposed to tear.**

### 2.5 Direct scanout

Normally Hyprland **copies** the game image into its own frame (together with the bar, borders and so on) and sends that to the monitor.

With **direct scanout**, when a fullscreen game is the only thing on screen, Hyprland hands the game's own image straight to the display hardware. That saves one copy: a little less latency and GPU work.

Direct scanout does **not** change *when* the flip happens. Timing (and tearing) is still decided by Hyprland, so it works together with V-Sync and G-Sync just fine.

It doesn't activate for every app. On this machine it works everywhere except Sober (Roblox) and SuperTuxKart (which outputs a buffer format the monitor path doesn't accept). Check with `directScanoutTo` / `directScanoutBlockedBy` in `hyprctl monitors`.

---

## 3. Behavior cheat sheet

Xwayland games, G-Sync on (`misc.vrr = 2`), fullscreen, on this machine:

| MangoHud `vsync` | FPS cap | `immediate` rule? | What happens | Source |
|---|---|---|---|---|
| `3` (on) | 162 | no | ✅ G-Sync active, **no tearing**, ~162 FPS, lowest tear-free latency. **Recommended.** | measured |
| `3` (on) | 180 | no | Held at 170, no tearing, but the V-Sync queue adds latency. Avoid. | measured |
| `1` (off) | 180 | no | Game renders 180 FPS, Hyprland shows the newest frame each refresh. **No tearing.** | measured |
| `1` (off) | 180 | **yes** | ⚡ **Tears**, lowest possible latency. **This is CS2.** | measured |
| `3` (on) | 180 | **yes** | Tears anyway. The game's FIFO no longer holds it at 170. | measured |
| any | 162 | **yes** | Mostly clean thanks to G-Sync, but occasional small tears at the bottom on frametime spikes. No real latency gain. | expected (Blur Busters) |

Other cases:

- **Video apps with VRR off + `immediate` rule:** constant tearing. A 24 FPS video doesn't match the 170 Hz painter, so frames arrive mid-scan all the time. This was the original Crunchyroll problem, caused by a catch-all `tearing-all` rule.
- **Windowed games:** never tear, no matter what. (Not fullscreen → point 3 in [2.2](#22-when-does-hyprland-tear).)

---

## 4. MangoHud

MangoHud does two jobs here: it is the **FPS limiter** (like RTSS on Windows) and it **forces the V-Sync mode** of every game (like the NVIDIA Control Panel on Windows). The overlay itself is hidden by default.

### 4.1 Global loading through `/etc/environment`

The file `/etc/environment` contains:

```ini
MANGOHUD=1
MANGOHUD_DLSYM=1
LD_PRELOAD=/usr/$LIB/mangohud/libMangoHud_opengl.so
__GL_SYNC_TO_VBLANK=1
MANGOHUD_CONFIG=read_cfg,no_display,legacy_layout=1
```

**What `/etc/environment` is:** a plain list of `KEY=VALUE` lines. It is read at **login** (by PAM's `pam_env` module), and the variables apply to **every program in every session**: Hyprland, Steam, every game. That's why no Steam launch options are needed.

**Edit it:**

```bash
sudo nano /etc/environment
```

Save with **Ctrl+O**, then **Enter**. Quit with **Ctrl+X**. Changes only apply after **logging out and back in** (reboot to be safe).

**Check it worked** (in a terminal after logging in again):

```bash
env | rg -i 'mangohud|ld_preload|gl_sync'
```

#### Line by line

**`MANGOHUD=1`**
Turns on MangoHud's **Vulkan layer** for every Vulkan program. This covers native Vulkan games **and all Proton games**, because Proton translates DirectX to Vulkan (DXVK / VKD3D). So for Proton games, MangoHud's `vsync` and `fps_limit` always apply.

**`MANGOHUD_DLSYM=1`**
For **OpenGL** games. Some games don't link OpenGL normally but look up its functions at runtime with `dlsym()`. This makes MangoHud hook that path too, so it still catches those games. (According to the Arch wiki this hook is on by default nowadays; setting `1` just makes it explicit.)

**`LD_PRELOAD=/usr/$LIB/mangohud/libMangoHud_opengl.so`**
Vulkan has a layer system, OpenGL doesn't. `LD_PRELOAD` tells the dynamic linker to load MangoHud's OpenGL library **into every program before anything else**. That's how MangoHud can step in at the moment an OpenGL game swaps buffers, which is where the FPS limit and `gl_vsync` happen.

`$LIB` is **meant to stay literal**. It is not a shell variable. The dynamic linker replaces it per program, on Arch with `lib` for 64-bit and `lib32` for 32-bit programs. One line covers both (32-bit games need the `lib32-mangohud` package). Don't put quotes or `${}` around it.

**`__GL_SYNC_TO_VBLANK=1`**
An **NVIDIA OpenGL driver** option: OpenGL programs sync their buffer swaps to the monitor's refresh (V-Sync on) by default. It's a second safety layer next to `gl_vsync=1`. It only affects OpenGL, only on NVIDIA.

**`MANGOHUD_CONFIG=read_cfg,no_display,legacy_layout=1`**
Config options given as an environment variable. These override the config files.

- `read_cfg`: **still read the config files.** Without it, *only* the options in this variable would be used, and `MangoHud.conf` would be ignored!
- `no_display`: HUD hidden by default. The limiter and V-Sync still work. Show the HUD with **Shift_R+F12**.
- `legacy_layout=1`: use the classic default HUD layout.

#### Side effects to know about

- **The OpenGL library is loaded into every program**, including the terminal, the browser, Hyprland and Xwayland. Most of them simply ignore it. But any program that draws with OpenGL can be affected by MangoHud's limiter or `gl_vsync`. If a non-game program behaves oddly (capped, stuttering), add it to the **blacklist** in `MangoHud.conf`:
  ```ini
  blacklist=Hyprland,Xwayland
  ```
  These are process names, comma-separated. Find the exact name with `ps -eo comm | rg -i <name>`.
- **32-bit programs** without `lib32-mangohud` can print a message like *"object … cannot be preloaded … ignored"*. That's harmless.
- `hyprland.lua` also contains `hl.env("MANGOHUD", "1")`. That's redundant with `/etc/environment`, but harmless.
- **Turn MangoHud off for one Vulkan/Proton game:** Steam launch option `MANGOHUD=0 %command%`.

### 4.2 Config files: which one wins

| File | Used for |
|---|---|
| `~/.config/MangoHud/MangoHud.conf` | **Global**, every game |
| `~/.config/MangoHud/<exe>.conf` | One **native Linux** game, e.g. `cs2.conf` |
| `~/.config/MangoHud/wine-<exe>.conf` | One **Proton/Wine** game, e.g. `wine-hl2.conf` for `hl2.exe` |

- `<exe>` is the **executable name**, **case-sensitive**, and for Proton games **without** `.exe`.
- The per-game file wins over the global one.
- **Tip:** Put every setting the game needs into its own file (limit, method, vsync, HUD items). Don't rely on the global file filling gaps.
- After editing, reload in-game with **Shift_L+F4**, or restart the game.

### 4.3 `vsync`: Vulkan (and therefore all Proton games)

| Value | Vulkan present mode | What it does |
|---|---|---|
| *(not set)* | whatever the game asks for | In-game V-Sync setting decides. |
| `0` | FIFO_RELAXED | **Adaptive V-Sync:** V-Sync while the game is fast enough, but a late frame is handed over immediately instead of waiting for the next refresh. |
| `1` | IMMEDIATE | **V-Sync off.** Frames are handed over immediately. → used in `cs2.conf` |
| `2` | MAILBOX | **Unlimited FPS without tearing:** the game renders as fast as it can, only the newest frame is shown at each refresh, older ones are dropped. |
| `3` | FIFO | **V-Sync on.** Frames wait in a queue for the refresh. → **global setting** |

Notes:

- **Not every driver supports every mode.** If a mode isn't supported, the game falls back to another one. Check what your GPU offers:
  ```bash
  vulkaninfo 2>/dev/null | rg 'PRESENT_MODE'
  ```
  (`vulkaninfo` is in the `vulkan-tools` package.)
- **On this setup without an `immediate` rule**, none of these modes can tear (Hyprland only tears with the rule, see [2.3](#23-the-nvidia--xwayland-catch)). What changes is how many frames the game renders above the refresh rate, and how much queue latency builds up.
- **With the 162 cap and G-Sync**, all of them behave almost the same, because the game never reaches 170. `vsync=3` is the **safety net** for the moment the cap is exceeded (e.g. a per-game profile with a higher limit).
- MangoHud also has a `vulkan_present_mode=` option. It overrides `vsync=`. Use one or the other, not both.

### 4.4 `gl_vsync`: OpenGL games

| Value | What it does |
|---|---|
| *(not set)* | The game decides (plus `__GL_SYNC_TO_VBLANK` on NVIDIA). |
| `0` | **V-Sync off.** |
| `1` | **V-Sync on:** wait for 1 refresh before swapping. → **global setting** |
| `2`, `3`, … | Wait for N refreshes. Acts like an FPS limit of *refresh ÷ N* (`2` = 85 FPS on 170 Hz). |
| `-1` | Adaptive V-Sync. (Listed in older MangoHud docs; depends on the driver.) |

Which games are OpenGL? Native Linux games that don't use Vulkan, emulators, older engines. **Proton games are almost always Vulkan** (through DXVK), even if the game itself is DirectX 9/10/11. For those, `vsync` applies, not `gl_vsync`.

If an **OpenGL** game is supposed to tear (rule + `gl_vsync=0` in its profile) but stays stuck at the refresh rate, `__GL_SYNC_TO_VBLANK=1` may still be forcing V-Sync. Try the Steam launch option:

```
__GL_SYNC_TO_VBLANK=0 %command%
```

### 4.5 `fps_limit` and `fps_limit_method`

**`fps_limit=162`**
Caps the game at 162 FPS. `0` means unlimited.

You can give several values, e.g. `fps_limit=162,0`, and switch between them in-game with **Shift_L+F1**.

**`fps_limit_method`** decides **when** the limiter waits.

| Method | When it waits | Effect |
|---|---|---|
| `late` *(default)* | **after** the frame is presented | The next frame starts right after the wait, so the game reads your mouse input as late as possible. → **lowest latency.** Frame delivery is a little less even. |
| `early` | **before** the frame is presented | The finished frame is held back until its time slot. → frames come out evenly spaced, **smoothest frametimes**. But the input in that frame is older by the waiting time → slightly more latency (less than one frame time, at 162 FPS under 6.2 ms). |

- The method only matters when the limiter actually **waits**, i.e. when the game could run faster than the cap. If the GPU can't even reach 162, both behave the same.
- **Recommendation:** `late` everywhere (lowest latency). If one game's frametime graph looks jagged or it feels micro-stuttery, try `early` in that game's profile.

### 4.6 HUD and keys

| Key | Action |
|---|---|
| **Shift_R+F12** | Show / hide the HUD |
| **Shift_L+F1** | Switch between the values in `fps_limit` |
| **Shift_L+F2** | Start / stop logging |
| **Shift_L+F4** | Reload the config |

Useful HUD items for checking this setup (add them to the config, they only show when the HUD is visible):

```ini
# current FPS
fps
# frametime in ms
frametime
# frametime graph
frame_timing
# the active FPS limit
show_fps_limit
# the Vulkan present mode really in use (FIFO, IMMEDIATE, ...)
present_mode
```

(Keep comments on their own line. Don't put a `#` comment behind a value.)

---

## 5. Hyprland

### 5.1 `allow_tearing`

```lua
hl.config({ general = { allow_tearing = true } })
```

The **master switch**. With `false`, Hyprland ignores every `immediate` rule and nothing ever tears, not even CS2. With `true`, tearing is **allowed**, but it still only happens for windows that have the rule (or ask for it themselves, see [2.3](#23-the-nvidia--xwayland-catch)).

### 5.2 The `immediate` window rule

```lua
hl.window_rule({
    name  = "tearing-games",
    match = { class = "cs2" },
    immediate = true,
})
```

- Forces this window to tear when it is fullscreen and alone on screen.
- `class` is a **regular expression** that must match the **whole** class, and it is **case-sensitive**. `"cs2"` matches only `cs2`, not `steam_app_220`.
- Several games: `class = "cs2|othergame"`.
- **Find a window's class:** start the game, then in a terminal (5 seconds to switch back to the game):
  ```bash
  sleep 5; hyprctl activewindow | rg -i 'class|xwayland'
  ```
  Proton games are called `steam_app_<AppID>`, e.g. `steam_app_220` for Half-Life 2.

> **Never** add a catch-all rule like `match = { class = ".*" }, immediate = true`. It makes every fullscreen app tear, including videos, and it breaks the game's V-Sync (see [2.4](#24-what-the-immediate-rule-does-to-the-games-v-sync)).

### 5.3 Rule order

Rules are evaluated **from top to bottom**. If two rules set the same property for the same window, the **lower one wins**. Exceptions must therefore be placed **below** the general rule they override.

### 5.4 VRR (G-Sync)

```lua
hl.config({ misc = { vrr = 2 } })
```

| `misc.vrr` | Meaning |
|---|---|
| `0` | Off. Fixed refresh rate. |
| `1` | Always on, also on the desktop. (Made grey areas flicker slightly on this monitor.) |
| `2` | Only for **fullscreen** windows. → **used here** |
| `3` | Only for fullscreen windows with "game" or "video" content type. |

**Turn VRR off for one app** (only works with `vrr = 2` or `3`):

```lua
hl.window_rule({
    name  = "no-tearing-video",
    match = { class = "crunchyroll|firefox" },
    no_vrr = true,
    immediate = false,
})
```

`immediate = false` is not strictly needed without a catch-all rule, but it does no harm and makes the intent clear.

> **Rule of thumb:** anything you exclude from VRR must never get an `immediate` rule. Without VRR, its frames arrive at random moments, and with `immediate` every one of them tears.

Cursor settings in this config that belong to VRR:

```lua
hl.config({
    cursor = {
        no_break_fs_vrr  = 1,  -- moving the mouse doesn't force extra refreshes in fullscreen VRR games
        min_refresh_rate = 48, -- with the option above: the cursor still updates at least this often (Hz)
    },
})
```

**Check that G-Sync works:** open the monitor's on-screen menu (OSD) with the refresh-rate display. In a fullscreen game the Hz number should follow the FPS (about 162). On the desktop it stays at 170.

### 5.5 Direct scanout

```lua
hl.config({ render = { direct_scanout = true } })
```

`true` / `1` = on, `0` = off, `2` = auto (only for windows with the "game" content type). See [2.5](#25-direct-scanout) for what it does.

### 5.6 After changing tearing rules

On this machine, **leftovers of a deleted `immediate` rule stayed active** after `hyprctl reload`: a game kept tearing although no rule matched it anymore. Some time later it was gone.

So after adding or removing a tearing rule:

1. `hyprctl reload`
2. **Restart the game** completely.
3. If the behavior still doesn't match the config: **log out and back in** (fresh Hyprland start).

Also check for config errors (the red bar at the top of the screen), because with an error Hyprland doesn't load the new rules:

```bash
hyprctl configerrors
```

### 5.7 Useful commands

Run them with a delay, then switch to the fullscreen game within 10 seconds:

```bash
# Is the game tearing? What blocks it?
sleep 10; hyprctl monitors | rg -i 'tearing'

# Which window is it? Xwayland or native Wayland? Fullscreen?
sleep 10; hyprctl activewindow | rg -i 'class|xwayland|fullscreen'

# Is direct scanout active? VRR on?
sleep 10; hyprctl monitors | rg -i 'scanout|vrr|solitary'
```

How to read the fields:

| Field | Meaning |
|---|---|
| `activelyTearing: true` | Tearing is happening right now. |
| `tearingBlockedBy: null` | Nothing blocks tearing. |
| `tearingBlockedBy: … window settings` | The window has no `immediate` rule and didn't ask for tearing. Normal for every game without the rule. |
| `tearingBlockedBy: next frame is not torn` | The next frame isn't marked for tearing. Normal when not tearing. |
| `tearingBlockedBy: … HW_CURSOR` | The hardware mouse cursor blocks tearing (seen in a vkcube test, never in CS2). |
| `solitary: <address>` | This window is alone on the screen (a requirement for tearing and direct scanout). |
| `directScanoutTo: <address>` | Direct scanout is active for that window. |
| `vrr: true` | VRR is currently on for this monitor. |

---

## 6. The recommended config (copy & paste)

### 6.1 `~/.config/MangoHud/MangoHud.conf` (global)

Only the lines that matter for latency. Keep your other lines as they are.

```ini
### Limiter: stay inside the G-Sync range (170 Hz - 8)
fps_limit=162
fps_limit_method=late

### Sync: V-Sync as a safety net (Vulkan / OpenGL)
vsync=3
gl_vsync=1

### HUD hidden by default (Shift_R+F12 to show)
no_display
fps
frametime
show_fps_limit
present_mode
```

### 6.2 `~/.config/MangoHud/cs2.conf` (competitive, tears on purpose)

```ini
fps
frametime
show_fps_limit
present_mode

fps_limit=180
fps_limit_method=late
no_display
vsync=1
```

`180` keeps the GPU from running flat out. `fps_limit=0` (unlimited) gives even fresher frames and a bit less latency, but more heat and GPU load.

### 6.3 `~/.config/hypr/hyprland.lua` (the relevant parts)

These values can sit in different `hl.config({...})` blocks in the file. They just have to be there once.

```lua
hl.config({
    general = { allow_tearing = true },   -- master switch (needed for CS2)
    render  = { direct_scanout = true },
    misc    = { vrr = 2 },                -- G-Sync only in fullscreen
    cursor  = { no_break_fs_vrr = 1, min_refresh_rate = 48 },
})

-- Tearing ONLY for games that should tear (lowest latency, competitive)
hl.window_rule({
    name  = "tearing-games",
    match = { class = "cs2" },
    immediate = true,
})

-- Video apps: no VRR (flickers), never tear
hl.window_rule({
    name  = "no-tearing-video",
    match = { class = "crunchyroll|firefox" },
    no_vrr = true,
    immediate = false,
})

-- DO NOT add a catch-all tearing rule like this one:
-- hl.window_rule({ name = "tearing-all", match = { class = ".*" }, immediate = true })
```

### 6.4 In every game

- In-game **V-Sync: off.** MangoHud forces it.
- In-game **FPS limit: off / unlimited.** MangoHud limits. (If you prefer a game's own limiter, set it to 162 and set `fps_limit=0` in that game's MangoHud profile. Never stack two limiters.)
- **Fullscreen** or borderless fullscreen. Both are fullscreen for Hyprland.

---

## 7. All setups compared

On a 170 Hz monitor:

| Setup | Latency | Tearing | Verdict |
|---|---|---|---|
| **A.** G-Sync + `vsync=3` + cap 162, no rule | Very low. Practically the same as V-Sync off at 162. | None | ✅ **Default for every game** |
| **B.** `immediate` rule + `vsync=1` + cap 180 or unlimited | Lowest possible, especially in the lower part of the screen | Yes | ⚡ **Competitive (CS2)** |
| **C.** Catch-all `immediate` rule + cap 162 (= G-Sync + V-Sync off) | Same as A in practice | Occasional tears at the bottom, videos tear | ❌ No benefit over A |
| **D.** No rule + `vsync=1` + uncapped | Low, but frames are dropped by Hyprland; G-Sync sits at its 170 limit | None | 🤷 Works, but the GPU works for frames you never see |
| **E.** `vsync=3` + cap at or above 170 (or no cap) | **High:** the V-Sync queue adds 1 to 3 frames | None | ❌ Avoid |
| **F.** VRR off + `vsync=3` + cap 162 | Medium | None | ❌ Stutters: 162 FPS doesn't divide into 170 Hz, so some frames stay on screen longer |

---

## 8. Recipes

### 8.1 Make another game tear (competitive)

1. Start the game, find its class:
   ```bash
   sleep 5; hyprctl activewindow | rg -i 'class'
   ```
2. Add it to the rule in `hyprland.lua`:
   ```lua
   match = { class = "cs2|newclass" },
   ```
3. Create its MangoHud profile ([4.2](#42-config-files-which-one-wins)): `<exe>.conf` for native, `wine-<exe>.conf` for Proton. Find the executable name with:
   ```bash
   ps -eo comm | rg -i '<part of the game name>'
   ```
   Content:
   ```ini
   fps_limit=180
   fps_limit_method=late
   # Vulkan / Proton game:
   vsync=1
   # OpenGL game: use this line instead of vsync=1
   # gl_vsync=0
   no_display
   ```
4. `hyprctl reload`, restart the game, fullscreen, check: `activelyTearing: true`.

### 8.2 Stop a game from tearing again

Remove its class from `tearing-games`, delete or change its MangoHud profile, then follow [5.6](#56-after-changing-tearing-rules).

### 8.3 Stop a video or browser app from flickering

Add its class to the `no-tearing-video` rule (`no_vrr = true`). Find the class with `hyprctl clients | rg -i class`.

### 8.4 Quick sanity check of the whole setup

| Test | Expected |
|---|---|
| Normal game, fullscreen, `hyprctl monitors \| rg -i tearing` | `activelyTearing: false` |
| Monitor OSD during that game | about 162 Hz |
| MangoHud HUD (Shift_R+F12) in that game | ~162 FPS, `present_mode` FIFO |
| CS2, fullscreen, same command | `activelyTearing: true` |
| Crunchyroll / Firefox video in fullscreen | no tearing, OSD fixed at 170 Hz |

---

## 9. Troubleshooting

### 9.1 A game tears but shouldn't

1. `sleep 10; hyprctl activewindow | rg -i 'class|xwayland'` → is the class in `tearing-games`?
2. `rg -n 'immediate' ~/.config/hypr/hyprland.lua` → is there any other rule with `immediate = true` (e.g. a leftover `class = ".*"`)?
3. Leftovers after a rule change → [5.6](#56-after-changing-tearing-rules) (restart the game, log out / in).
4. `xwayland: 0` → it's a native Wayland app and may request tearing itself (V-Sync off in the app). Make sure MangoHud's `vsync=3` applies to it (HUD → `present_mode` should say FIFO). As a test, set `allow_tearing = false`: if the tearing stops, it came through Hyprland.

### 9.2 CS2 doesn't tear

- `tearingBlockedBy` shows `window settings` → the rule doesn't match (check class, `hyprctl configerrors`).
- Something else is on screen (notification, overlay, bar) → tearing needs the game to be alone on screen.
- `allow_tearing` is `false`.
- After a system update → [9.6](#96-tearing-stopped-working-after-a-system-update).

### 9.3 A game runs above 162 FPS

- Is MangoHud loaded? Press Shift_R+F12. If no HUD appears, check `/etc/environment` ([4.1](#41-global-loading-through-etcenvironment)).
- Does the game have its own MangoHud profile with a different `fps_limit`?
- Does it have an `immediate` rule? With the rule, V-Sync no longer holds anything back ([2.4](#24-what-the-immediate-rule-does-to-the-games-v-sync)).

### 9.4 A game is capped at a number you never set

An old environment variable may be forcing a DXVK limit. On KDE there once was `DXVK_CONFIG=dxgi.maxFrameRate=162;d3d9.maxFrameRate=162` in `~/.config/environment.d/fps_limit.conf`. Check:

```bash
env | rg -i dxvk
rg -n 'DXVK' ~/.config/environment.d/ 2>/dev/null
```

### 9.5 Video app tears or flickers

- **Tears:** it must not have an `immediate` rule (also no catch-all rule above it). See [5.4](#54-vrr-g-sync).
- **Flickers:** give it `no_vrr = true`.
- **Steps/judder on camera pans** (no tear line) is not tearing. 24 FPS video doesn't divide evenly into 170 Hz. That's normal and not fixable with these settings.

### 9.6 Tearing stopped working after a system update

On this machine, tearing only works because **Hyprland 0.56.2 was rebuilt from Arch's package with a one-line fix** (a self-blocking `isTearingBlocked` check in `commitWindow`). A regular `pacman -Syu` that installs a newer official `hyprland` package **overwrites** that build.

If CS2 suddenly stops tearing after an update (rule matches, `activelyTearing` stays `false`, nothing else changed), check whether the fix is included in the new version. If not, rebuild the package with the patch again.

---

## 10. Glossary

| Term | Meaning |
|---|---|
| **Refresh rate (Hz)** | How many times per second the monitor redraws the picture. Here 170. |
| **Scanout** | One top-to-bottom redraw of the screen (1/170 s ≈ 5.9 ms). |
| **Frametime** | How long one frame takes. 162 FPS = 6.2 ms per frame. |
| **Tearing** | Two frames visible at once, split by a horizontal line. |
| **V-Sync** | Only switch frames between two scanouts. No tearing, but queue latency above the refresh rate. |
| **VRR / G-Sync** | The monitor waits for the GPU and redraws when a frame is ready. Works below the max refresh rate. |
| **Present mode** | How a Vulkan game hands frames over: FIFO (V-Sync), IMMEDIATE (no V-Sync), MAILBOX, FIFO_RELAXED. |
| **Compositor** | The program that puts all windows together and sends the final picture to the monitor. Here: Hyprland. |
| **Page flip** | The moment the GPU switches the screen to a new frame. Synchronous = between scanouts, immediate = right away (tearing). |
| **Xwayland** | Runs X11 programs (most games, including all Proton games) on Wayland. |
| **Direct scanout** | The game's own image goes straight to the screen, without Hyprland copying it. |
| **Solitary** | A window that is the only thing visible on a monitor. |
| **Window class** | The name Hyprland uses to identify an app in window rules (`cs2`, `steam_app_220`, `firefox`, …). |
| **`LD_PRELOAD`** | Tells the dynamic linker to load a library into a program before everything else. |

---

## 11. Sources

- [Hyprland Wiki: Tearing](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/)
- [Hyprland Wiki: Window Rules](https://wiki.hypr.land/Configuring/Basics/Window-Rules/)
- [Blur Busters: G-SYNC 101, Range](https://www.blurbusters.com/gsync101/2/)
- [Blur Busters: G-SYNC 101, G-SYNC vs. V-SYNC OFF w/ FPS Limit](https://www.blurbusters.com/gsync/gsync101-input-lag-tests-and-settings/6/)
- [Blur Busters: G-SYNC 101, Closing FAQ](https://www.blurbusters.com/gsync/gsync101-input-lag-tests-and-settings/15/)
- [MangoHud: annotated example config (MangoHud.conf)](https://raw.githubusercontent.com/flightlessmango/MangoHud/master/data/MangoHud.conf)
- [MangoHud README: Vulkan / OpenGL V-Sync values (mirror)](https://git.blob42.xyz/Archives/MangoHud/src/commit/d9a09670d8c3b14d58e26ff093605656c5f68bc0)
- [MangoHud: wine-<application_name>.conf for Proton games (commit)](https://git.blob42.xyz/Archives/MangoHud/commit/161081b72531cd51613414917d98e126aeeb761e)
- [Arch Wiki: MangoHud (mirror)](https://wikipedia.jakami.de/content/archlinux_en_all_maxi_2026-04/MangoHud)
- [ld.so(8): `$LIB` and other tokens in `LD_PRELOAD`](https://man7.org/linux/man-pages/man8/ld.so.8.html)
- [pam_env(8): format of environment files](https://manpages.opensuse.org/Tumbleweed/pam-manpages/pam_env.8.en.html)
- [9to5Linux: NVIDIA 555.58 adds IMMEDIATE present mode for Vulkan on Wayland](https://9to5linux.com/nvidia-555-58-linux-graphics-driver-released-with-explicit-sync-on-wayland)
- [GE-Proton10-1 release notes (`PROTON_ENABLE_WAYLAND`)](https://scribe.disroot.org/post/2762004)
- [r/nvidia: FPS cap rule of thumb for G-Sync](https://reddit.zackpollard.pro/r/nvidia/comments/1lokih2/putting_misconceptions_about_optimal_fps_caps/n0np855)
