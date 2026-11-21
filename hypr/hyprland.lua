-- ==========================================================
--  _  ___   _____ ___ _      _   _  _ ___    _   _   _  _
-- | || \ \ / / _ \ _ \ |    /_\ | \| |   \  | | | | | |/_\
-- | __ |\ V /|  _/   / |__ / _ \| .` | |) | | |_| |_| / _ \
-- |_||_| |_| |_| |_|_\____/_/ \_\_|\_|___/  |____\___/_/ \_\
-- ==========================================================


-- ==== REQUIREMENTS ==== --
require("system") --Background stuff
require("performance") --Gaming, Mangohud, Latency, etc.



-- ==== VARIABLES ==== --
local mod = "SUPER"
local terminal = "kitty"
local filemanager = "nautilus"
local menu = "rofi -show drun"
local tempo = 0.5




-- ==== MONITOR ==== --
hl.monitor({ output = "DP-1", mode = "2560x1440@170", position = "auto", scale = "auto" })


-- ==== AUTOSTART ==== --
hl.on("hyprland.start", function()
hl.exec_cmd("waybar")
hl.exec_cmd("swaync")
hl.exec_cmd("awww-daemon")
hl.exec_cmd("sleep 1 && waypaper --restore")
hl.exec_cmd("blueman-applet")
end)



-- ==== WINDOW RULES ==== --
hl.window_rule({ match = { title  = "Noctis Mini Player" }, border_size = 0, })



-- ==== SETTINGS ==== --
hl.config({
    input = {
        kb_layout = "de"
    },
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 1,
        col = {
            active_border   = "rgba(ffffffff)",
            inactive_border = "rgba(444444ff)",
        },
        --==== FLOATING WINDOW SNAPPING ====--
        snap = {
            enabled      = true,
            window_gap   = 15,
            monitor_gap  = 15,
            respect_gaps = true,
        },
    },

    decoration = {
        rounding = 10,
        shadow = {
            enabled = false,
        },
        blur = {
            enabled = true,
            size = 2,
            passes = 2,}
    }
})


-- ==== KEYBINDS ==== --
hl.bind(mod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(filemanager))
hl.bind(mod .. " + C", hl.dsp.window.close())
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("special1"))
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
--hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + M", hl.dsp.exit())
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.window.kill())

hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- Mit dem Nachbarn tauschen
hl.bind(mod .. " + CTRL + left",  hl.dsp.window.swap({ direction = "left" }))
hl.bind(mod .. " + CTRL + right", hl.dsp.window.swap({ direction = "right" }))

for i = 1, 10 do 
    local key = i% 10
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i}))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end


-- ==== ANIMATIONS ==== --
hl.curve("snap", { type = "bezier", points = { {0.16, 1}, {0.3, 1} }})
hl.curve("linear", {type = "bezier", points = {{0, 0}, {1, 1} } })


hl.animation({ leaf = "global", enabled = true, speed = 2 / tempo, bezier = "snap" })
hl.animation({ leaf = "windows", enabled = true, speed = 2 / tempo, bezier = "snap" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2 / tempo, bezier = "snap", style = "popin 95%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed =1.2 / tempo, bezier = "linear", style = "popin 95%" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.5 / tempo, bezier = "snap" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1 / tempo, bezier = "linear" })
hl.animation({ leaf = "layers", enabled = true, speed = 1.5 / tempo, bezier = "snap", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1 / tempo, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1 / tempo, bezier = "linear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2 / tempo, bezier = "snap", style = "slidefade 10%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2 / tempo, bezier = "snap", style = "slidefadevert 10%" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 3 / tempo, bezier = "snap" })



--====LAYER RULES====--
hl.layer_rule({ match = { namespace = "rofi" }, blur = true, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "waybar" }, blur = true, blur_popups = true,ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "swaync-.*" }, blur = true, ignore_alpha = 0 })

--====================================================================================--
--====================================================================================--

-- ===== Super + V: float the window, the first time at 5:3 in the center =====
local FLOAT_SHARE = 0.5      -- width = 50 % of the screen width
local already_floated = {}   -- memory: which windows have floated before

local function toggle_float()
    local w = hl.get_active_window()
    if not w then return end

    -- already floating -> back to normal tiling
    if w.floating then
        hl.dispatch(hl.dsp.window.float({ action = "unset" }))
        return
    end

    -- make it float
    hl.dispatch(hl.dsp.window.float({ action = "set" }))

    -- floated before? then do nothing else, Hyprland restores size and position by itself
    if already_floated[w.address] then return end
    already_floated[w.address] = true

    -- first time: resize to 5:3 and center it
    local m      = w.monitor
    local width  = math.floor(m.width / m.scale * FLOAT_SHARE)
    local height = math.floor(width * 3 / 5)

    hl.dispatch(hl.dsp.window.resize({ x = width, y = height, relative = false }))
    hl.dispatch(hl.dsp.window.center())
end

-- window closed -> remove it from memory
hl.on("window.close", function(w) already_floated[w.address] = nil end)

hl.bind(mod .. " + V", toggle_float)
--====================================================================================--
--====================================================================================--







--====================================================================================--
--====================================================================================--
-- ==== SMART GAPS: only 1 tiled window = no gaps, no border ==== --
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })

hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, rounding = 0,border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]" }, rounding = 0, border_size = 0 })
--====================================================================================--
--====================================================================================--

hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]" }, border_size = 0 })
