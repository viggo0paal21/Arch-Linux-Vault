pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Persistent settings. Stored in
// ~/.local/state/quickshell/by-shell/oled-bw/settings.json
// Changes in the settings panel are written immediately.
Singleton {
    id: root

    property alias opts: adapter

    readonly property var defaults: ({
        radius: 7,
        barHeight: 35,
        barDockedExtra: 0,
        barDockedHeight: 37,
        barDockDuration: 300,
        smoothText: false,
        barFloatOffset: 10,
        barFloatSide: 10,
        barGlide: true,
        barShellGlass: false,
        glassBlurSize: 8,
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
        launcherIconSize: 20,
        barBoxes: false,
        barBoxColor: "#000000",
        barShowTitle: false,
        barAutoTransparent: false,
        barShowSysmon: true,
        barShowDate: true,
        clockSeconds: false,
        clock24h: true,
        workspaceCount: 1,
        uiFont: "Inter",
        uiIconFont: "JetBrainsMono Nerd Font Propo",
        uiFontSize: 15,
        uiFontWeight: 700,
        animations: true,
        transparency: "everywhere",
        glassOpacity: 55,
        appGlass: true,
        appOpacity: 65,
        kittyOpacity: 65,
        hyprBlurSize: 10,
        hyprBlurPasses: 3,
        popupsSolidWithWindows: false,
        barSolidWithWindows: true,
        barSolidOnlySingle: true,
        barExcludeKitty: true,
        animScale: 1,
        animBarCurve: "smoothOut",
        animPanelSpeed: 0.75,
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
        wallColorStyle: "exact",
        wallColorsDynamic: true,
        renderBackend: "opengl",
        hyprDynamic: true,
        dnd: false,
        notifTimeout: 5,
        osdEnabled: true,
        volumeStep: 5,
        oledBackground: false,
        wallpaper: "",
        screenCorners: false,
        gpuMonitor: true,
        fpsCounter: false,
        kittyFastfetch: false,
        fastfetchLogo1: "",
        fastfetchLogo2: "",
        fastfetchLogo3: "",
        fastfetchLogo4: "",
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

            property int radius: root.defaults.radius
            property int barHeight: root.defaults.barHeight
            property int barDockedExtra: root.defaults.barDockedExtra
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
            property int kittyOpacity: root.defaults.kittyOpacity
            property int hyprBlurSize: root.defaults.hyprBlurSize
            property int hyprBlurPasses: root.defaults.hyprBlurPasses
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
            // Settings > Bar > "Dynamic Hyprland integration": hyprland.lua reads the value when it loads (see the top of that file)
            property bool hyprDynamic: root.defaults.hyprDynamic
            // Renderer (Settings > Behavior): "vulkan" or "opengl", applies from the next start (render-env.sh)
            property string renderBackend: root.defaults.renderBackend
            property bool dnd: root.defaults.dnd
            property int notifTimeout: root.defaults.notifTimeout
            property bool osdEnabled: root.defaults.osdEnabled
            property int volumeStep: root.defaults.volumeStep
            property bool oledBackground: root.defaults.oledBackground
            property string wallpaper: root.defaults.wallpaper
            property bool screenCorners: root.defaults.screenCorners
            property bool gpuMonitor: root.defaults.gpuMonitor
            property bool fpsCounter: root.defaults.fpsCounter
            // Settings > Commands > "Fastfetch in kitty": ~/.local/bin/kitty-shell/zsh reads the value for every new kitty
            property bool kittyFastfetch: root.defaults.kittyFastfetch
            // Settings > Commands > "Fastfetch images": up to 4 images, one per new kitty in turn (~/.local/bin/fastfetch-logo).
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
