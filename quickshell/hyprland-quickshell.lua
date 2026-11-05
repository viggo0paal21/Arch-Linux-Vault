-- ============================================================
--  Quickshell OLED B/W – building blocks for ~/.config/hypr/hyprland.lua
--  (Hyprland >= 0.55, Lua config). Just copy them to the end of your
--  hyprland.lua and remove the old lines for waybar,
--  dunst/swaync, swaybg and hyprlauncher.
-- ============================================================

-- Autostart: Quickshell instead of waybar + dunst + swaybg
-- (If you already have a hyprland.start block: just put the hl.exec_cmd("qs") line in there.)
hl.on("hyprland.start", function()
    hl.exec_cmd("qs")
end)

-- Panels via keyboard shortcuts (IPC)
hl.bind("SUPER + SPACE",  hl.dsp.exec_cmd("qs ipc call launcher toggle"))
hl.bind("SUPER + A",      hl.dsp.exec_cmd("qs ipc call control toggle"))
hl.bind("SUPER + D",      hl.dsp.exec_cmd("qs ipc call dashboard toggle"))
hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("qs ipc call power toggle"))
hl.bind("SUPER + COMMA",  hl.dsp.exec_cmd("qs ipc call settings toggle"))
hl.bind("SUPER + N",      hl.dsp.exec_cmd("qs ipc call notifs dnd"))

-- Volume keys (the OSD shows up automatically, whether via wpctl or Quickshell)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

-- Quickshell animates itself: turn off Hyprland's layer animation for the shell,
-- otherwise it animates twice and stutters.
hl.layer_rule({ match = { namespace = "qs-.*" }, no_anim = true })

-- With transparency (Settings > Appearance > Transparency): blur behind the shell.
-- Replaces the line above, details in the Quickshell Guide.
-- hl.layer_rule({ match = { namespace = "qs-.*" }, no_anim = true, blur = true, ignore_alpha = 0.5 })
-- Bar: only blur the wallpaper, not windows (otherwise a dark edge at the bottom from the window below)
-- hl.layer_rule({ match = { namespace = "qs-bar" }, xray = true })
