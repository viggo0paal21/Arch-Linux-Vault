-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- HYPRLAND CONFIG (Lua)                                 --
-- Docs: https://wiki.hypr.land/Configuring/Start/       --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- If your monitor doesn't run at its full refresh rate, set the mode explicitly,
-- e.g. mode = "2560x1440@144" (see the values with: hyprctl monitors)
hl.monitor({
    output   = "DP-1",
    mode     = "2560x1440@170",
    position = "auto",
    scale    = "auto",
})


---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "kitty"
local fileManager = "nautilus"
local menu        = "pkill rofi || rofi -show drun"


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd GDK_WAYLAND_DISABLE")
    --hl.exec_cmd("waybar &")   -- ersetzt durch Quickshell
    --hl.exec_cmd("swaync &")   -- Quickshell hat eigene Benachrichtigungen
    -- Quickshell without MangoHud, on Vulkan with a stable 170 fps
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/qs-start")
    --hl.exec_cmd("swaybg -m fill -i /home/viggo/Wallpapers/wallpaperflare.com_wallpaper.jpg &")
    hl.exec_cmd("swww-daemon &")
    hl.exec_cmd("waypaper --restore &")
    hl.exec_cmd("sleep 3 && arch-update --tray")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
-- Note: changes here only apply after restarting Hyprland.

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GDK_WAYLAND_DISABLE", "ext_background_effect_manager_v1")
--hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
--hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("GTK_APPLICATION_PREFER_DARK_THEME", "1")
hl.env("ADW_DISABLE_PORTAL", "1")
hl.env("GDK_WAYLAND_DISABLE", "ext_background_effect_manager_v1")
-- MangoHud as a global Vulkan layer. The FPS limit is in ~/.config/MangoHud/MangoHud.conf
hl.env("MANGOHUD", "1")

hl.env("GTK_USE_PORTAL", "1")

-- Optional (low latency for OpenGL): only enable once everything else works.
-- hl.env("__GL_MaxFramesAllowed", "1")


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        -- top: 10 + 10 for the floating Quickshell bar ("Dynamic" only reserves the bar height,
        -- the gap below it comes from Hyprland).
        gaps_out = { top = 20, right = 10, bottom = 10, left = 10 },
        --gaps_out = { top = 0, right = 15, bottom = 15, left = 15 },
        border_size = 1,

        -- Subtle grey for the active window, inactive windows without a visible border
        col = {
            active_border = "rgba(a8a8a8ff)",
            inactive_border = "rgba(00000000)",
            
        },

        resize_on_border = true,
        allow_tearing    = true,
        layout           = "dwindle",

        -- Floating windows snap to the same gaps as tiled ones while dragging/resizing:
        -- to other windows gaps_in (2 x 5 = 10 px), to the screen edge gaps_out (20 below the bar, 10 elsewhere).
        -- window_gap / monitor_gap = how close (in px) a window has to be before it snaps.
        snap = {
            enabled      = true,
            window_gap   = 15,
            monitor_gap  = 15,
            respect_gaps = true,
        },
    },

    decoration = {
        -- Fully square
        rounding = 8,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        -- Shadows off for a flat, minimal look
        shadow = {
            enabled = false,
        },

        blur = {
                enabled = true,
                size = 8,
                passes = 2,
        },
    },

    animations = {
        enabled = true,
    },
})


-- Curves
hl.curve("linear",        { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("md3_standard",  { type = "bezier", points = { {0.2, 0},     {0, 1}       } })
hl.curve("md3_decel",     { type = "bezier", points = { {0.05, 0.7},  {0.1, 1}     } })
-- evenly decelerating (easeOutQuint): gentle start, soft landing without a long creep at the end.
-- Used for windows; the Quickshell bar has its own curve setting (Settings > Animations).
hl.curve("smooth_out",    { type = "bezier", points = { {0.22, 1},    {0.36, 1}    } })
hl.curve("md3_accel",     { type = "bezier", points = { {0.3, 0},     {0.8, 0.15}  } })
hl.curve("overshot",      { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.1}   } })
hl.curve("crazyshot",     { type = "bezier", points = { {0.1, 1.5},   {0.76, 0.92} } })
hl.curve("hyprnostretch", { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.0}   } })
hl.curve("menu_decel",    { type = "bezier", points = { {0.1, 1},     {0, 1}       } })
hl.curve("menu_accel",    { type = "bezier", points = { {0.38, 0.04}, {1, 0.07}    } })
hl.curve("easeInOutCirc", { type = "bezier", points = { {0.85, 0},    {0.15, 1}    } })
hl.curve("easeOutCirc",   { type = "bezier", points = { {0, 0.55},    {0.45, 1}    } })
hl.curve("easeOutExpo",   { type = "bezier", points = { {0.16, 1},    {0.3, 1}     } })
hl.curve("softAcDecel",   { type = "bezier", points = { {0.26, 0.26}, {0.15, 1}    } })
hl.curve("md2",           { type = "bezier", points = { {0.4, 0},     {0.2, 1}     } }) -- use with .2s duration



-- Animation configs
hl.animation({ leaf = "windows",       enabled = true, speed = 3,   bezier = "smooth_out", style = "popin 60%" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 3,   bezier = "smooth_out", style = "popin 60%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 3,   bezier = "md3_accel",  style = "popin 60%" })
hl.animation({ leaf = "border",        enabled = true, speed = 2.5,  bezier = "default" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3,   bezier = "md3_decel" })
-- hl.animation({ leaf = "layers",     enabled = true, speed = 2,   bezier = "md3_decel",  style = "slide" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 3,   bezier = "menu_decel", style = "popin 60%" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5, bezier = "menu_accel", style = "popin 0%" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2,   bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 4.5, bezier = "menu_accel" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 4,   bezier = "menu_decel", style = "slide" })
-- hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "softAcDecel", style = "slide" })
-- hl.animation({ leaf = "workspaces", enabled = true, speed = 7,   bezier = "menu_decel", style = "slidefade 15%" })
-- hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "md3_decel", style = "slidefadevert 15%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "md3_decel", style = "slidevert" })

hl.layer_rule({ match = { namespace = "qs-.*" }, no_anim = true, blur = true, ignore_alpha = 0.5 }) 
-- Popups without a dimmed background (dashboard, control center, notifications, OSD):
-- blur even below 50 % opacity (the slider goes down to 25 %). Settings, launcher and power menu stay at 0.5,
-- otherwise their dimmed background would be blurred too. Their cards sit on the dimming, so they are always above 0.5.
-- The bar stays at 0.5: with 0.2 a line flickers between bar and window while docking.
hl.layer_rule({ match = { namespace = "qs-(dashboard|control|notifications|osd)" }, ignore_alpha = 0.2 })

hl.layer_rule({
    match = { namespace = "swaync-notification-window" },
    animation = "slide right",
})

hl.layer_rule({
  match = { namespace = "rofi" },
  name = "rofi-blur",
  blur = true,
  ignore_alpha = 0,
})

-- Bar: only blur the wallpaper, not windows (otherwise a dark edge at the bottom from the window below)
hl.layer_rule({ match = { namespace = "qs-bar" }, xray = true })

--hl.window_rule({
    --name  = "tearing-all",
    --match = { class = ".*" },
    --immediate = true,
--})

--hl.window_rule({
    --name  = "tearing-games",
    --match = { class = "cs2" },
    --immediate = true,
--})

-- Exceptions: have to be BELOW tearing-all
hl.window_rule({
    name  = "no-tearing-video",
    match = { class = "crunchyroll|firefox" },
    no_vrr = true,
    immediate = false,
})

hl.window_rule({
    name  = "doom-fullscreen",
    match = { class = "steam_app_379720" },
    fullscreen_state = "2 2",
})

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"

hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",    gaps_out = 0, gaps_in = 0 })

hl.window_rule({
    name  = "no-gaps-wtv1",
    match = { float = false, workspace = "w[tv1]" },
    -- border_size = 0 is already set in "smart-border-single-tiled" further down, don't set it twice here
    --border_size = 0,
    rounding    = 0,
})

hl.window_rule({
    name  = "no-gaps-f1",
    match = { float = false, workspace = "f[1]" },
    border_size = 0,
    rounding    = 0,
})

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

hl.config({
    render = {
        cm_auto_hdr = 0,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    render = {
        direct_scanout = true, -- enable direct scanout here
    },
    misc = {
        force_default_wallpaper = -1,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = false, -- If true disables the random hyprland logo / anime girl background. :(
        vrr                     = 2,     -- G-Sync/VRR only for fullscreen apps (1 = always on)
    },
    cursor = {
        no_break_fs_vrr = 1,
        no_hardware_cursors = 0,
        min_refresh_rate = 48,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "de",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        -- Disable mouse acceleration
        accel_profile = "flat",
        sensitivity   = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + C", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
--see SUPER + V at the end --hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
-- before: rofi (local menu above)
--hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("qs ipc call launcher toggle"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only
hl.bind("SUPER + Page_Up", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/waybar/scripts/toggle-transparency.sh"))

hl.bind("SUPER + Home", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/check-direct-scanout"))
hl.bind("SUPER + Page_Down", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/waybar/scripts/toggle-hardened.sh"))
-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})
-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

------------------------
---- SMART BORDERS ----
------------------------

-- 1. Removes the border when exactly 1 tiled window is visible on the workspace
hl.window_rule({
    name = "smart-border-single-tiled",
    match = { float = false, workspace = "w[tv1]" },
    border_size = 0,
})

-- 2. IMPORTANT: makes sure floating windows ALWAYS keep their border
hl.window_rule({
    name = "smart-border-floating-override",
    match = { float = true },
    border_size = 1,
})

-- ── Floating windows in 16:9 ──────────────────────
local FLOAT_SHARE     = 0.6    -- width = 60 % of the monitor width
local ONLY_FIRST_TIME = true  -- true = afterwards Hyprland remembers your own size

local already_floated = {}

local function toggle_float_16_9()
  local w = hl.get_active_window()
  if not w then return end

  -- already floating → back to tiling
  if w.floating then
    hl.dispatch(hl.dsp.window.float({ action = "unset" }))
    return
  end

  hl.dispatch(hl.dsp.window.float({ action = "set" }))

  if ONLY_FIRST_TIME and already_floated[w.address] then return end
  already_floated[w.address] = true

  local m      = w.monitor
  local width  = math.floor(m.width / m.scale * FLOAT_SHARE)
  local height = math.floor(width * 9 / 16)

  hl.dispatch(hl.dsp.window.resize({ x = width, y = height, relative = false }))
  hl.dispatch(hl.dsp.window.center())
end

-- Clean up memory when windows close
hl.on("window.close", function(w) already_floated[w.address] = nil end)

hl.bind("SUPER + V", toggle_float_16_9)




