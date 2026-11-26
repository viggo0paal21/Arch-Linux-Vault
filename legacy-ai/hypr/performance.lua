-- ==========================================================================
--  performance.lua - gaming, latency and MangoHud
--  Taken out of the old AI hyprland.lua (as of 19.11.2026).
--
--  Include it: put this line at the very top of your hyprland.lua:
--      require("performance")
--  Hyprland looks for the file in the same folder as hyprland.lua.
--  If a setting is here AND in your hyprland.lua, the one that comes
--  later wins (so yours, if require is at the very top).
-- ==========================================================================


-----------------
---- MANGOHUD ----
-----------------

-- MangoHud runs in every Vulkan game (global layer).
-- What it shows and the FPS limit (162): ~/.config/MangoHud/MangoHud.conf
-- Settings per game: ~/.config/MangoHud/<game>.conf (e.g. cs2.conf)
-- Only takes effect after the next login.
hl.env("MANGOHUD", "1")

-- Optional (low latency in OpenGL): only turn on once everything else works.
-- hl.env("__GL_MaxFramesAllowed", "1")


--------------------------------------
---- LATENCY, G-SYNC/VRR, TEARING ----
--------------------------------------

hl.config({
    general = {
        allow_tearing = true,       -- games may tear if they want to (less input lag)
    },
    render = {
        direct_scanout = true,      -- fullscreen games go straight to the monitor, bypassing Hyprland
        cm_auto_hdr    = 0,         -- no automatic HDR
    },
    misc = {
        vrr = 2,                    -- G-Sync/VRR: 0 = off, 1 = always, 2 = fullscreen only
    },
    cursor = {
        no_break_fs_vrr     = 1,    -- moving the mouse doesn't break VRR in fullscreen
        no_hardware_cursors = 0,    -- hardware cursor on (faster)
        min_refresh_rate    = 48,   -- lower limit for VRR
    },
    input = {
        accel_profile = "flat",     -- no mouse acceleration (mouse moves 1:1)
        sensitivity   = 0,
    },
})


-----------------------------------
---- RULES FOR VIDEOS/GAMES ----
-----------------------------------

-- videos: no tearing, no VRR (otherwise it flickers)
hl.window_rule({
    name      = "no-tearing-video",
    match     = { class = "crunchyroll|firefox" },
    no_vrr    = true,
    immediate = false,
})

-- DOOM (Steam app 379720) in real fullscreen
hl.window_rule({
    name             = "doom-fullscreen",
    match            = { class = "steam_app_379720" },
    fullscreen_state = "2 2",
})


------------------
---- TOOLS ----
------------------

-- Super + Home: shows whether direct scanout is active right now
hl.bind("SUPER + Home", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/check-direct-scanout"))
