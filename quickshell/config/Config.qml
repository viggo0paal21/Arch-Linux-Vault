pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Persistente Einstellungen. Gespeichert unter
// ~/.local/state/quickshell/by-shell/oled-bw/settings.json
// Aenderungen im Einstellungs-Panel werden sofort geschrieben.
Singleton {
    id: root

    property alias opts: adapter

    readonly property var defaults: ({
        radius: 8,
        barHeight: 37,
        barDockedExtra: 2,
        barDockDuration: 300,
        smoothText: false,
        barFloatOffset: 8,
        barFloating: false,
        barFloatingDynamic: false,
        barBorder: true,
        barShowTitle: false,
        barAutoTransparent: true,
        barShowSysmon: true,
        barShowDate: false,
        clockSeconds: false,
        clock24h: true,
        workspaceCount: 5,
        uiFont: "Inter",
        uiIconFont: "JetBrainsMono Nerd Font Propo",
        uiFontSize: 15,
        uiFontWeight: 700,
        animations: true,
        transparency: "off",
        glassOpacity: 80,
        popupsSolidWithWindows: false,
        barSolidWithWindows: false,
        barSolidOnlySingle: false,
        barExcludeKitty: false,
        animScale: 0.5,
        animBarCurve: "smoothOut",
        animPanelSpeed: 1.0,
        animPanelOpen: "outCubic",
        animPanelClose: "inCubic",
        animOverlaySpeed: 1.0,
        animOverlayOpen: "outCubic",
        animOverlayClose: "inCubic",
        animNotifSpeed: 1.0,
        animNotifCurve: "outCubic",
        animOsdSpeed: 1.0,
        animWsSpeed: 1.0,
        animWsCurve: "outCubic",
        animCtlSpeed: 1.0,
        animCtlCurve: "standard",
        monochromeIcons: true,
        dnd: false,
        notifTimeout: 5,
        osdEnabled: true,
        volumeStep: 5,
        oledBackground: true,
        wallpaper: "",
        screenCorners: false,
        gpuMonitor: true,
        fpsCounter: false,
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
            property int barDockDuration: root.defaults.barDockDuration
            property bool smoothText: root.defaults.smoothText
            property int barFloatOffset: root.defaults.barFloatOffset
            property bool barFloating: root.defaults.barFloating
            property bool barFloatingDynamic: root.defaults.barFloatingDynamic
            property bool barBorder: root.defaults.barBorder
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
            property bool dnd: root.defaults.dnd
            property int notifTimeout: root.defaults.notifTimeout
            property bool osdEnabled: root.defaults.osdEnabled
            property int volumeStep: root.defaults.volumeStep
            property bool oledBackground: root.defaults.oledBackground
            property string wallpaper: root.defaults.wallpaper
            property bool screenCorners: root.defaults.screenCorners
            property bool gpuMonitor: root.defaults.gpuMonitor
            property bool fpsCounter: root.defaults.fpsCounter
            property string terminal: root.defaults.terminal
            property string lockCommand: root.defaults.lockCommand
        }
    }
}
