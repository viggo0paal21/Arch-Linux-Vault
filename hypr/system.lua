-- ==========================================================================
--  system.lua - background stuff so apps run and look right
--  Taken out of the old AI hyprland.lua (as of 19.11.2026).
--
--  Include it: put this line at the very top of your hyprland.lua:
--      require("system")
--  Without this file, e.g. password prompts for admin actions are missing,
--  and Qt apps lose their theme.
-- ==========================================================================


----------------------------
---- ENVIRONMENT VARIABLES ----
----------------------------

-- Only take effect after the next login.
hl.env("XCURSOR_THEME", "breeze_cursors")   -- Mauszeiger fuer Hyprland selbst und Nicht-GTK-Apps
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- GTK apps: blur protocol off (also passed to dbus/systemd at startup, see AUTOSTART)
hl.env("GDK_WAYLAND_DISABLE", "ext_background_effect_manager_v1")

-- Qt look: qt6ct sets colors, fonts and style for Qt apps.
-- Kvantum is off; uncomment the second line to use it instead:
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
-- hl.env("QT_STYLE_OVERRIDE", "kvantum")

-- GTK apps dark, file dialogs through the portal
-- GTK_THEME stays off: it forces a built-in theme and ignores ~/.config/gtk-4.0/gtk.css
--hl.env("GTK_THEME", "Adwaita:dark")
hl.env("GTK_APPLICATION_PREFER_DARK_THEME", "1")
hl.env("ADW_DISABLE_PORTAL", "1")
hl.env("GTK_USE_PORTAL", "1")


-------------------
---- AUTOSTART ----
-------------------

-- Only runs at login.
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd GDK_WAYLAND_DISABLE")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")  -- password prompt for admin actions
    hl.exec_cmd("sleep 3 && arch-update --tray")           -- update icon in the tray
end)


---------------
---- FIXES ----
---------------

hl.config({
    misc = {
        force_default_wallpaper = 0,   -- no Hyprland mascot as wallpaper
    },
})

-- apps can't maximize themselves
hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- fixes dragging issues under XWayland
hl.window_rule({
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
