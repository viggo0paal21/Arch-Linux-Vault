# Low Latency Gaming (Hyprland + NVIDIA)

Short reference for my setup: RTX 3060 Ti, 170 Hz G-Sync monitor, Hyprland, games through Proton / Xwayland, MangoHud loaded for every game (see [README → Global MangoHud](README.md#global-mangohud-system-wide)).

---

## 1. Lowest latency without tearing (my setup)

| Where | Setting |
|---|---|
| `hyprland.lua` | `misc.vrr = 2` (G-Sync in fullscreen) |
| `hyprland.lua` | **no** catch-all `immediate` rule |
| `hyprland.lua` | `general.allow_tearing = false` (or `true` if you use section 2) |
| `~/.config/MangoHud/MangoHud.conf` | `fps_limit=162`, `fps_limit_method=late`, `vsync=3`, `gl_vsync=1` |
| In every game | V-Sync off, frame limiter off (MangoHud does both) |

**Why it works:** G-Sync makes the monitor wait for the GPU and show each frame the moment it's ready. The cap (8 below 170 Hz) keeps every game inside the G-Sync range. V-Sync then only holds back the rare frame that comes too early, so there is no tearing and practically the same latency as V-Sync off.

If a game can't hold 162 and the GPU sits at ~99 %, give that game a lower cap in its own profile. A maxed-out GPU adds more latency than anything else.

---

## 2. Alternative: `tearing-all` + exceptions

Every fullscreen game gets Hyprland's direct path (each frame is flipped the moment it arrives), and the 162 cap + G-Sync keeps the tearing out of sight. It felt the same as section 1 for me. Section 1 is the safer default.

Needs `general.allow_tearing = true`. In `hyprland.lua`:

```lua
-- 1. Every fullscreen window may tear
hl.window_rule({
    name  = "tearing-all",
    match = { class = ".*" },
    immediate = true,
})

-- 2. Exceptions: MUST come below tearing-all (the lower rule wins)

-- Video apps: no tearing AND no VRR (VRR makes them flicker)
hl.window_rule({
    name  = "no-tearing-video",
    match = { class = "crunchyroll|firefox" },   -- add more apps with |
    no_vrr = true,
    immediate = false,
})

-- Apps that should never tear but can keep VRR (replace someclass)
hl.window_rule({
    name  = "no-tearing",
    match = { class = "someclass" },
    immediate = false,
})
```

Keep in mind:

- **The FPS cap is the only protection.** With the rule, MangoHud's `vsync` holds nothing back, so every game must stay at 162 (global `fps_limit=162`).
- **Games without MangoHud** (e.g. Flatpak games, check with Shift_R+F12) run uncapped and tear. Set 162 in the game itself or add it as an exception.
- **Anything with `no_vrr` must also get `immediate = false`**, otherwise it tears all the time (that was the Crunchyroll bug).
- **Find a class:** `hyprctl clients | rg -i class`
- **Want one game to really tear** for competitive play? Give it its own MangoHud profile with `fps_limit=0` (`<exe>.conf` for native, `wine-<exe>.conf` for Proton games).

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
| `true` | yes (section 2) | Every fullscreen window can tear, MangoHud's vsync can't stop it. At 162 + G-Sync almost never visible. Video apps need an exception rule. |
| `false` | doesn't matter | Nothing can tear, not even with a rule. |

### The other settings

| Setting | What it does |
|---|---|
| `misc.vrr` | `0` off, `1` always (flickers on grey areas here), **`2` fullscreen only**, `3` fullscreen with game/video content type |
| `no_vrr = true` (rule) | VRR off for one app. Video apps flicker with VRR. Such apps must **never** get `immediate`, or they tear all the time. |
| `render.direct_scanout` | The fullscreen game image goes straight to the screen, one copy less. Doesn't change *when* frames are flipped. |
| Rule order | Top to bottom, the lower rule wins. Exceptions go **below** the rule they override. |

Exception rules for tearing and VRR: see section 2.

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
