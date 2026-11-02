-- ============================================================
--  Quickshell OLED S/W – Bausteine für ~/.config/hypr/hyprland.lua
--  (Hyprland >= 0.55, Lua-Config). Einfach unten in deine
--  hyprland.lua kopieren und die alten Zeilen für waybar,
--  dunst/swaync, swaybg und hyprlauncher entfernen.
-- ============================================================

-- Autostart: Quickshell statt waybar + dunst + swaybg
-- (Wenn du schon einen hyprland.start-Block hast: nur die Zeile hl.exec_cmd("qs") dort rein.)
hl.on("hyprland.start", function()
    hl.exec_cmd("qs")
end)

-- Panels per Tastenkürzel (IPC)
hl.bind("SUPER + SPACE",  hl.dsp.exec_cmd("qs ipc call launcher toggle"))
hl.bind("SUPER + A",      hl.dsp.exec_cmd("qs ipc call control toggle"))
hl.bind("SUPER + D",      hl.dsp.exec_cmd("qs ipc call dashboard toggle"))
hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("qs ipc call power toggle"))
hl.bind("SUPER + COMMA",  hl.dsp.exec_cmd("qs ipc call settings toggle"))
hl.bind("SUPER + N",      hl.dsp.exec_cmd("qs ipc call notifs dnd"))

-- Lautstärke-Tasten (OSD erscheint automatisch, egal ob wpctl oder Quickshell)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

-- Quickshell animiert selbst: Hyprlands Ebenen-Animation für die Shell aus,
-- sonst wird doppelt animiert und es ruckelt.
hl.layer_rule({ match = { namespace = "qs-.*" }, no_anim = true })
