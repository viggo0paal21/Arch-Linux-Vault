pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Persistent settings. Stored in
// ~/.local/state/quickshell/by-shell/oled-bw/settings.json
// Changes in the settings panel are written immediately.
// The defaults (also used by "Reset to defaults" and the reset buttons) are exactly my own
// settings (as of Nov 18).
Singleton {
    id: root

    property alias opts: adapter

    readonly property var defaults: ({
        // Corners of the large surfaces (panels, cards, floating bar) in real pixels, like rounding in
        // hyprland.lua. Replaces the old "radius" (where 7 meant 10 px on the panels, see config/Theme.qml).
        cornerRadius: 10,
        barHeight: 35,
        barDockedHeight: 37,
        barDockDuration: 300,
        smoothText: false,
        barFloatOffset: 10,
        barFloatSide: 10,
        barGlide: true,
        barShellGlass: false,
        glassBlurSize: 1,
        glassBlurPasses: 2,
        glassBlurContrast: 0.8916,
        glassBlurBrightness: 1.0,
        glassBlurVibrancy: 0.1696,
        glassBlurVibrancyDarkness: 0.0,
        glassBlurNoise: 0.0117,
        barFloating: true,
        barFloatingDynamic: true,
        barBorder: false,
        launcherIcon: "arch",
        launcherIconSize: 22,
        barBoxes: false,
        barBoxColor: "#000000",
        barShowTitle: true,
        barAutoTransparent: false,
        barShowSysmon: true,
        barShowDate: true,
        clockSeconds: true,
        clock24h: true,
        workspaceCount: 1,
        uiFont: "Inter",
        uiIconFont: "JetBrainsMono Nerd Font Propo",
        uiFontSize: 15,
        uiFontWeight: 600,
        animations: true,
        transparency: "everywhere",
        glassOpacity: 65,
        appGlass: false,
        appOpacity: 65,
        // Settings > Apps > Opacity: -1 = like "All apps" (appOpacity) or App glass (appGlass)
        appOpacityKitty: -1,
        appOpacityTidal: -1,
        appOpacityNautilus: -1,
        appOpacityDialogs: -1,
        appOpacityVesktop: -1,
        appOpacityFirefox: -1,
        appGlassNautilus: -1,
        appGlassDialogs: 1,
        appGlassVesktop: -1,
        appGlassFirefox: -1,
        // Settings > Hyprland: -1 = value from hyprland.lua
        hyprBlurSize: 1,
        hyprBlurPasses: 2,
        hyprRounding: -1,
        hyprShadow: -1,
        hyprDirectScanout: -1,
        popupsSolidWithWindows: false,
        barSolidWithWindows: true,
        barSolidOnlySingle: true,
        barExcludeKitty: true,
        animScale: 1,
        animBarCurve: "smoothOut",
        animPanelSpeed: 0.85,
        animPanelOpen: "smoothOut",
        animPanelClose: "smoothOut",
        animOverlaySpeed: 2,
        animOverlayOpen: "smoothOut",
        animOverlayClose: "smoothOut",
        animNotifSpeed: 1,
        animNotifCurve: "smoothOut",
        animOsdSpeed: 1,
        animWsSpeed: 1,
        animWsCurve: "outCubic",
        animCtlSpeed: 1,
        animCtlCurve: "standard",
        monochromeIcons: false,
        wallColors: true,
        wallColorStyle: "vibrant",
        wallColorsDynamic: true,
        renderBackend: "opengl",
        hyprDynamic: true,
        dnd: false,
        notifTimeout: 5,
        osdEnabled: true,
        volumeStep: 5,
        screenCorners: true,
        gpuMonitor: true,
        fpsCounter: false,
        systemFontMenu: true,
        kittyFastfetch: false,
        fastfetchLogo1: "/home/viggo/.config/fastfetch/logos/1573730073Tux_Mono_wite.png",
        fastfetchLogo2: "/home/viggo/.config/fastfetch/logos/1573730073Tux_Mono_wite.png",
        fastfetchLogo3: "/home/viggo/.config/fastfetch/logos/1573730073Tux_Mono_wite.png",
        fastfetchLogo4: "/home/viggo/.config/fastfetch/logos/1573730073Tux_Mono_wite.png",
        terminal: "kitty",
        lockCommand: "hyprlock || loginctl lock-session"
    })

    function reset() {
        const d = root.defaults;
        for (const key in d)
            adapter[key] = d[key];
    }

    FileView {
        id: file

        path: Quickshell.statePath("settings.json")
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property int cornerRadius: root.defaults.cornerRadius
            property int barHeight: root.defaults.barHeight
            property int barDockedHeight: root.defaults.barDockedHeight
            property int barDockDuration: root.defaults.barDockDuration
            property bool smoothText: root.defaults.smoothText
            property int barFloatOffset: root.defaults.barFloatOffset
            property int barFloatSide: root.defaults.barFloatSide
            property bool barGlide: root.defaults.barGlide
            property bool barShellGlass: root.defaults.barShellGlass
            property int glassBlurSize: root.defaults.glassBlurSize
            property int glassBlurPasses: root.defaults.glassBlurPasses
            property real glassBlurContrast: root.defaults.glassBlurContrast
            property real glassBlurBrightness: root.defaults.glassBlurBrightness
            property real glassBlurVibrancy: root.defaults.glassBlurVibrancy
            property real glassBlurVibrancyDarkness: root.defaults.glassBlurVibrancyDarkness
            property real glassBlurNoise: root.defaults.glassBlurNoise
            property bool barFloating: root.defaults.barFloating
            property bool barFloatingDynamic: root.defaults.barFloatingDynamic
            property bool barBorder: root.defaults.barBorder
            property string launcherIcon: root.defaults.launcherIcon
            property int launcherIconSize: root.defaults.launcherIconSize
            property bool barBoxes: root.defaults.barBoxes
            property string barBoxColor: root.defaults.barBoxColor
            property bool barShowTitle: root.defaults.barShowTitle
            property bool barAutoTransparent: root.defaults.barAutoTransparent
            property bool barShowSysmon: root.defaults.barShowSysmon
            property bool barShowDate: root.defaults.barShowDate
            property bool clockSeconds: root.defaults.clockSeconds
            property bool clock24h: root.defaults.clock24h
            property int workspaceCount: root.defaults.workspaceCount
            property string uiFont: root.defaults.uiFont
            property string uiIconFont: root.defaults.uiIconFont
            property int uiFontSize: root.defaults.uiFontSize
            property int uiFontWeight: root.defaults.uiFontWeight
            property bool animations: root.defaults.animations
            property string transparency: root.defaults.transparency
            property int glassOpacity: root.defaults.glassOpacity
            property bool appGlass: root.defaults.appGlass
            property int appOpacity: root.defaults.appOpacity
            // Settings > Apps > Opacity (-1 = "All apps" / App glass, see qs-glass-apply and services/Hypr.qml)
            property int appOpacityKitty: root.defaults.appOpacityKitty
            property int appOpacityTidal: root.defaults.appOpacityTidal
            property int appOpacityNautilus: root.defaults.appOpacityNautilus
            property int appOpacityDialogs: root.defaults.appOpacityDialogs
            property int appOpacityVesktop: root.defaults.appOpacityVesktop
            property int appOpacityFirefox: root.defaults.appOpacityFirefox
            property int appGlassNautilus: root.defaults.appGlassNautilus
            property int appGlassDialogs: root.defaults.appGlassDialogs
            property int appGlassVesktop: root.defaults.appGlassVesktop
            property int appGlassFirefox: root.defaults.appGlassFirefox
            // Settings > Hyprland: applied at runtime on top of hyprland.lua (services/Hypr.qml), -1 = hyprland.lua
            property int hyprBlurSize: root.defaults.hyprBlurSize
            property int hyprBlurPasses: root.defaults.hyprBlurPasses
            property int hyprRounding: root.defaults.hyprRounding
            property int hyprShadow: root.defaults.hyprShadow
            property int hyprDirectScanout: root.defaults.hyprDirectScanout
            property bool popupsSolidWithWindows: root.defaults.popupsSolidWithWindows
            property bool barSolidWithWindows: root.defaults.barSolidWithWindows
            property bool barSolidOnlySingle: root.defaults.barSolidOnlySingle
            property bool barExcludeKitty: root.defaults.barExcludeKitty
            property real animScale: root.defaults.animScale
            property string animBarCurve: root.defaults.animBarCurve
            property real animPanelSpeed: root.defaults.animPanelSpeed
            property string animPanelOpen: root.defaults.animPanelOpen
            property string animPanelClose: root.defaults.animPanelClose
            property real animOverlaySpeed: root.defaults.animOverlaySpeed
            property string animOverlayOpen: root.defaults.animOverlayOpen
            property string animOverlayClose: root.defaults.animOverlayClose
            property real animNotifSpeed: root.defaults.animNotifSpeed
            property string animNotifCurve: root.defaults.animNotifCurve
            property real animOsdSpeed: root.defaults.animOsdSpeed
            property real animWsSpeed: root.defaults.animWsSpeed
            property string animWsCurve: root.defaults.animWsCurve
            property real animCtlSpeed: root.defaults.animCtlSpeed
            property string animCtlCurve: root.defaults.animCtlCurve
            property bool monochromeIcons: root.defaults.monochromeIcons
            property bool wallColors: root.defaults.wallColors
            property string wallColorStyle: root.defaults.wallColorStyle
            property bool wallColorsDynamic: root.defaults.wallColorsDynamic
            // Settings > Hyprland > "Dynamic Hyprland integration": hyprland.lua reads the value when loading (see the very top there)
            property bool hyprDynamic: root.defaults.hyprDynamic
            // Renderer (Settings > Quickshell > Performance): "vulkan" or "opengl", applies from the next start (render-env.sh)
            property string renderBackend: root.defaults.renderBackend
            property bool dnd: root.defaults.dnd
            property int notifTimeout: root.defaults.notifTimeout
            property bool osdEnabled: root.defaults.osdEnabled
            property int volumeStep: root.defaults.volumeStep
            property bool screenCorners: root.defaults.screenCorners
            property bool gpuMonitor: root.defaults.gpuMonitor
            property bool fpsCounter: root.defaults.fpsCounter
            // Settings > System > Font. qs-font-revert sets it to false (menu hidden)
            property bool systemFontMenu: root.defaults.systemFontMenu
            // Settings > Apps > kitty > "Fastfetch in kitty": ~/.local/bin/kitty-shell/zsh reads the value for every new kitty
            property bool kittyFastfetch: root.defaults.kittyFastfetch
            // Settings > Apps > kitty > "Fastfetch images": up to 4 images, one per new kitty in turn (~/.local/bin/fastfetch-logo).
            // All empty = every image in ~/.config/fastfetch/logos.
            property string fastfetchLogo1: root.defaults.fastfetchLogo1
            property string fastfetchLogo2: root.defaults.fastfetchLogo2
            property string fastfetchLogo3: root.defaults.fastfetchLogo3
            property string fastfetchLogo4: root.defaults.fastfetchLogo4
            property string terminal: root.defaults.terminal
            property string lockCommand: root.defaults.lockCommand
        }
    }
}
