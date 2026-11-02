# Quickshell auf NVIDIA mit stabilen 170 fps

Setup: Arch Linux, Hyprland 0.56 (Lua-Config), RTX 3060 Ti (nvidia-open),
2560x1440 @ 170 Hz, eigene Quickshell-Shell "oled-bw".

## Problem
Shell-Animationen fuehlten sich nicht nach 170 Hz an. Gemessen: 85 fps,
beim Oeffnen von Panels Ruckler von 90-100 ms.

## Ursachen
1. MangoHud in der Shell: /etc/environment laedt MangoHud per LD_PRELOAD in jedes
   OpenGL-Programm (globaler FPS-Cap fuer Spiele), also auch in Quickshell.
2. Qt + OpenGL auf NVIDIA: Qt schaltet threaded Rendering auf dem NVIDIA-Treiber ab
   (basic-Modus, Animationen mit ~60-Hz-Timer). threaded erzwungen ergab exakt 85 fps
   (VSync doppelt gewartet).
3. Panels wurden bei jedem Oeffnen als neues Fenster angelegt (Wayland-Flaeche +
   Swapchain), das blockierte die Shell ~90 ms.

## Loesung
- Vulkan statt OpenGL (QSG_RHI_BACKEND=vulkan): threaded ist dort Standard, der
  Treiber macht VSync wie bei Spielen -> stabil 170 fps.
- Startskript haelt MangoHud, lsfg-vk und vkBasalt aus der Shell raus
  (Spiele unveraendert).
- Panels bleiben unsichtbar + durchklickbar gemappt, ausser ein Vollbild-Fenster ist
  aktiv (sonst blockiert die Overlay-Ebene Direct Scanout/Tearing in Spielen).
Ergebnis: konstant 170 fps, laengste Frame-Luecke ~7 ms, auch beim Oeffnen.

## Dateien
- bin/qs-start                         Startskript (Vulkan, ohne MangoHud/lsfg-vk/vkBasalt)
- bin/qs, bin/quickshell               optionale Wrapper: Fix fuer jede Quickshell-Config
- hypr/hyprland.lua                    Autostart: qs-start statt waybar + swaync
- quickshell/FpsOverlay.qml            FPS-Zaehler (Settings > FPS counter)
- quickshell/components/OverlayPanel.qml   Panels bleiben gemappt, Vollbild-Ausnahme
- quickshell/components/DropdownSlot.qml   Dashboard/Control Center sliden unter der Bar hervor
- quickshell/modules/dashboard/Dashboard.qml   Uhr nur aktiv wenn offen
- quickshell/config/Config.qml + modules/settings/SettingsPanel.qml   Einstellung FPS counter

## Installation
  cp -r quickshell ~/.config/
  cp hypr/hyprland.lua ~/.config/hypr/
  mkdir -p ~/.local/bin && cp bin/* ~/.local/bin/ && chmod +x ~/.local/bin/*
Danach ab- und wieder anmelden. Pruefen (muss 0 ergeben):
  for p in $(pgrep -x 'qs|quickshell'); do echo "$p: $(grep -ci mangohud /proc/$p/maps)"; done

## Andere Quickshell-Configs
Startskript mit Argumenten: ~/.local/bin/qs-start -c <name>
Shells mit eigenem Starter:
  env -u LD_PRELOAD MANGOHUD=0 DISABLE_LSFGVK=1 DISABLE_VKBASALT=1 QSG_RHI_BACKEND=vulkan <starter>
Panel-Trick, Slide-Animation und FPS-Zaehler sind Code dieser Shell und muessen
pro Shell eingebaut werden.

Quelle zur NVIDIA-Ursache: https://github.com/omacom/omarchy/issues/7268
