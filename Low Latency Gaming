# Low Latency Gaming (Hyprland + NVIDIA)

Short reference for my setup: RTX 3060 Ti, 170 Hz G-Sync monitor, Hyprland, games through Proton / Xwayland, MangoHud loaded for every game (see [README → Global MangoHud](README.md#global-mangohud-system-wide)).

---

## 1. Lowest latency without tearing (my setup)

| Where | Setting |
|---|---|
| `hyprland.lua` | `misc.vrr = 2` (G-Sync in fullscreen) |
| `hyprland.lua` | **no** catch-all `immediate` rule |
| `hyprland.lua` | `general.allow_tearing = true` only if a game should tear (section 2), otherwise `false` |
| `~/.config/MangoHud/MangoHud.conf` | `fps_limit=162`, `fps_limit_method=late`, `vsync=3`, `gl_vsync=1` |
| In every game | V-Sync off, frame limiter off (MangoHud does both) |

**Why it works:** G-Sync makes the monitor wait for the GPU and show each frame the moment it's ready. The cap (8 below 170 Hz) keeps every game inside the G-Sync range. V-Sync then only holds back the rare frame that comes too early, so there is no tearing and practically the same latency as V-Sync off.

If a game can't hold 162 and the GPU sits at ~99 %, give that game a lower cap in its own profile. A maxed-out GPU adds more latency than anything else.

---

## 2. Lowest latency with tearing (competitive)

Needs `general.allow_tearing = true`. Then, per game:

```lua
hl.window_rule({
    name  = "tearing-games",
    match = { class = "cs2" },   -- more games: "cs2|otherclass"
    immediate = true,
})
```

MangoHud profile: `~/.config/MangoHud/<exe>.conf` (native game) or `wine-<exe>.conf` (Proton game, exe name without `.exe`):

```ini
fps_limit=0
fps_limit_method=late
vsync=1
```

**Why:** far above 170 FPS every frame is fresher, and Hyprland puts each one on screen immediately instead of waiting. That's the lowest latency, with visible tearing. With a cap of 162 instead of 0, G-Sync hides almost all of the tearing again.

---

## 3. How tearing works on Hyprland

```
Game ──(present mode = MangoHud vsync)──▶ Hyprland ──(page flip)──▶ Monitor
```

- MangoHud's `vsync` only controls the **first** arrow. Tearing happens on the **second** one, and Hyprland decides it.
- Hyprland tears a window only if **all** of these are true:
  1. `allow_tearing = true` (master switch)
  2. the window has an `immediate = true` rule, or the app asks for tearing itself
  3. the window is fullscreen and the only thing on screen

  → Desktop, normal windows and the bar **never** tear.
- **NVIDIA + Xwayland** (all Proton games, CS2): the driver never asks Hyprland for tearing. **So the window rule is the tearing switch, not MangoHud.**
- An `immediate` rule also cancels the game's V-Sync (there is nothing left to wait for). Then only the FPS cap + G-Sync keep it from tearing.
- Native Wayland apps on NVIDIA *can* ask for tearing when their V-Sync is off. The global `vsync=3` prevents that.

### The three modes

| `allow_tearing` | Catch-all rule (`class = ".*"`, `immediate = true`) | Result |
|---|---|---|
| `true` | no **(my setup)** | Only windows with a rule can tear. MangoHud's vsync can't change that. |
| `true` | yes | Every fullscreen window can tear, MangoHud's vsync can't stop it. At 162 + G-Sync almost never visible. Video apps need an exception rule. |
| `false` | doesn't matter | Nothing can tear, not even with a rule. |

### The other settings

| Setting | What it does |
|---|---|
| `misc.vrr` | `0` off, `1` always (flickers on grey areas here), **`2` fullscreen only**, `3` fullscreen with game/video content type |
| `no_vrr = true` (rule) | VRR off for one app. Video apps flicker with VRR. Such apps must **never** get `immediate`, or they tear all the time. |
| `render.direct_scanout` | The fullscreen game image goes straight to the screen, one copy less. Doesn't change *when* frames are flipped. |
| Rule order | Top to bottom, the lower rule wins. Exceptions go **below** the rule they override. |

My video rule:

```lua
hl.window_rule({
    name  = "no-tearing-video",
    match = { class = "crunchyroll|firefox" },
    no_vrr = true,
    immediate = false,
})
```

### MangoHud values

| Option | Values |
|---|---|
| `vsync` (Vulkan, all Proton games) | `0` adaptive, `1` off, `2` mailbox, `3` on |
| `gl_vsync` (OpenGL games) | `0` off, `1` on, `N` = refresh ÷ N |
| `fps_limit_method` | `late` = lowest latency (default), `early` = smoother frametimes, a bit more latency |
| `fps_limit` | `162` = cap, `0` = unlimited, `162,0` = switch in-game with Shift_L+F1 |

---

## 4. Check

Start the command, then switch to the fullscreen game within 10 seconds:

```bash
sleep 10; hyprctl monitors | rg -i 'tearing|vrr'
sleep 10; hyprctl activewindow | rg -i 'class|xwayland'
```

- `activelyTearing: true` → it tears. `tearingBlockedBy: … window settings` → no rule for this window.
- Monitor OSD at about 162 Hz in game → G-Sync works.
- After adding or removing a rule: `hyprctl reload` and restart the game. If it still doesn't match the config, log out and back in (old rules can stick around).
- My Hyprland is a rebuilt package with a tearing fix. If tearing stops working after `pacman -Syu`, the update probably overwrote it.
