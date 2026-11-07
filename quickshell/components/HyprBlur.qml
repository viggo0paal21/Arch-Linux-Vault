import QtQuick
import Quickshell

// Hyprland's dual kawase blur (decoration:blur) as a shader chain, stage by stage like in Hyprland:
// contrast curve -> halve passes times (with vibrancy) -> double passes times -> noise.
// Every stage is its own 8-bit texture like Hyprland's buffers. The GPU rounds when writing there
// exactly like in Hyprland (measured), so the shaders keep computing unrounded like the original.
// It is only computed when the source or a value changes; after that they are finished images (it costs
// nothing per frame).
// Shaders: shaders/hypr*.frag (Hyprland's shaders 1:1, without color management), compiled to .frag.qsb.
Item {
    id: root

    // Source: item with layer.enabled (the wallpaper strip)
    property Item source: null
    property bool active: true
    // Like in hyprland.lua: decoration:blur size / passes / contrast / brightness / vibrancy / vibrancy_darkness
    property real size: 8
    property int passes: 2
    property real contrast: 0.8916
    property real brightness: 1.0
    property real vibrancy: 0.1696
    property real vibrancyDarkness: 0.0
    // decoration:blur noise
    property real noise: 0.0117
    // Screen size in pixels (the noise depends on the screen position); the source starts at 0,0
    property vector2d screenSize: Qt.vector2d(root.width, root.height)
    // Hyprland takes 1 to 8 passes
    readonly property int usedPasses: Math.max(1, Math.min(8, root.passes))
    // Finished blur with noise (same size as the source)
    readonly property Item output: fin

    // Version number in the address: Qt remembers loaded shaders per address and would only load a changed
    // .qsb file after restarting Quickshell otherwise. Increase it when a shader changes.
    readonly property int shaderVersion: 6

    function shader(name) {
        return "file://" + Quickshell.shellDir + "/shaders/" + name + ".frag.qsb?v=" + root.shaderVersion;
    }

    visible: false
    width: root.source ? root.source.width : 0
    height: root.source ? root.source.height : 0

    // Contrast as a gain curve (Hyprland blurprepare)
    ShaderEffect {
        id: prep

        property var source: root.source
        property real contrast: root.contrast
        property real brightness: root.brightness

        visible: false
        width: root.width
        height: root.height
        layer.enabled: root.active
        layer.smooth: true
        fragmentShader: root.active ? root.shader("hyprprepare") : ""
    }

    // Halve with vibrancy (Hyprland blur1). Offset = size texels of the source.

    ShaderEffect {
        id: down1

        property var source: prep
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(1 / source.width, 1 / source.height)
        property real passes: root.usedPasses
        property real vibrancy: root.vibrancy
        property real vibrancy_darkness: root.vibrancyDarkness

        visible: false
        width: root.width / 2
        height: root.height / 2
        layer.enabled: root.active && root.usedPasses >= 1
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses >= 1 ? root.shader("hyprblur1") : ""
    }

    ShaderEffect {
        id: down2

        property var source: down1
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(1 / source.width, 1 / source.height)
        property real passes: root.usedPasses
        property real vibrancy: root.vibrancy
        property real vibrancy_darkness: root.vibrancyDarkness

        visible: false
        width: root.width / 4
        height: root.height / 4
        layer.enabled: root.active && root.usedPasses >= 2
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses >= 2 ? root.shader("hyprblur1") : ""
    }

    ShaderEffect {
        id: down3

        property var source: down2
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(1 / source.width, 1 / source.height)
        property real passes: root.usedPasses
        property real vibrancy: root.vibrancy
        property real vibrancy_darkness: root.vibrancyDarkness

        visible: false
        width: root.width / 8
        height: root.height / 8
        layer.enabled: root.active && root.usedPasses >= 3
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses >= 3 ? root.shader("hyprblur1") : ""
    }

    ShaderEffect {
        id: down4

        property var source: down3
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(1 / source.width, 1 / source.height)
        property real passes: root.usedPasses
        property real vibrancy: root.vibrancy
        property real vibrancy_darkness: root.vibrancyDarkness

        visible: false
        width: root.width / 16
        height: root.height / 16
        layer.enabled: root.active && root.usedPasses >= 4
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses >= 4 ? root.shader("hyprblur1") : ""
    }

    ShaderEffect {
        id: down5

        property var source: down4
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(1 / source.width, 1 / source.height)
        property real passes: root.usedPasses
        property real vibrancy: root.vibrancy
        property real vibrancy_darkness: root.vibrancyDarkness

        visible: false
        width: root.width / 32
        height: root.height / 32
        layer.enabled: root.active && root.usedPasses >= 5
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses >= 5 ? root.shader("hyprblur1") : ""
    }

    ShaderEffect {
        id: down6

        property var source: down5
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(1 / source.width, 1 / source.height)
        property real passes: root.usedPasses
        property real vibrancy: root.vibrancy
        property real vibrancy_darkness: root.vibrancyDarkness

        visible: false
        width: root.width / 64
        height: root.height / 64
        layer.enabled: root.active && root.usedPasses >= 6
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses >= 6 ? root.shader("hyprblur1") : ""
    }

    ShaderEffect {
        id: down7

        property var source: down6
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(1 / source.width, 1 / source.height)
        property real passes: root.usedPasses
        property real vibrancy: root.vibrancy
        property real vibrancy_darkness: root.vibrancyDarkness

        visible: false
        width: root.width / 128
        height: root.height / 128
        layer.enabled: root.active && root.usedPasses >= 7
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses >= 7 ? root.shader("hyprblur1") : ""
    }

    ShaderEffect {
        id: down8

        property var source: down7
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(1 / source.width, 1 / source.height)
        property real passes: root.usedPasses
        property real vibrancy: root.vibrancy
        property real vibrancy_darkness: root.vibrancyDarkness

        visible: false
        width: root.width / 256
        height: root.height / 256
        layer.enabled: root.active && root.usedPasses >= 8
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses >= 8 ? root.shader("hyprblur1") : ""
    }

    // Double (Hyprland blur2). halfpixel = 1/4 texel of the source like in Hyprland.

    ShaderEffect {
        id: up7

        property var source: down8
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(0.25 / source.width, 0.25 / source.height)

        visible: false
        width: root.width / 128
        height: root.height / 128
        layer.enabled: root.active && root.usedPasses > 7
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses > 7 ? root.shader("hyprblur2") : ""
    }

    ShaderEffect {
        id: up6

        property var source: root.usedPasses === 7 ? down7 : up7
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(0.25 / source.width, 0.25 / source.height)

        visible: false
        width: root.width / 64
        height: root.height / 64
        layer.enabled: root.active && root.usedPasses > 6
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses > 6 ? root.shader("hyprblur2") : ""
    }

    ShaderEffect {
        id: up5

        property var source: root.usedPasses === 6 ? down6 : up6
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(0.25 / source.width, 0.25 / source.height)

        visible: false
        width: root.width / 32
        height: root.height / 32
        layer.enabled: root.active && root.usedPasses > 5
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses > 5 ? root.shader("hyprblur2") : ""
    }

    ShaderEffect {
        id: up4

        property var source: root.usedPasses === 5 ? down5 : up5
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(0.25 / source.width, 0.25 / source.height)

        visible: false
        width: root.width / 16
        height: root.height / 16
        layer.enabled: root.active && root.usedPasses > 4
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses > 4 ? root.shader("hyprblur2") : ""
    }

    ShaderEffect {
        id: up3

        property var source: root.usedPasses === 4 ? down4 : up4
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(0.25 / source.width, 0.25 / source.height)

        visible: false
        width: root.width / 8
        height: root.height / 8
        layer.enabled: root.active && root.usedPasses > 3
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses > 3 ? root.shader("hyprblur2") : ""
    }

    ShaderEffect {
        id: up2

        property var source: root.usedPasses === 3 ? down3 : up3
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(0.25 / source.width, 0.25 / source.height)

        visible: false
        width: root.width / 4
        height: root.height / 4
        layer.enabled: root.active && root.usedPasses > 2
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses > 2 ? root.shader("hyprblur2") : ""
    }

    ShaderEffect {
        id: up1

        property var source: root.usedPasses === 2 ? down2 : up2
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(0.25 / source.width, 0.25 / source.height)

        visible: false
        width: root.width / 2
        height: root.height / 2
        layer.enabled: root.active && root.usedPasses > 1
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses > 1 ? root.shader("hyprblur2") : ""
    }

    ShaderEffect {
        id: up0

        property var source: root.usedPasses === 1 ? down1 : up1
        property real radius: root.size
        property vector2d halfpixel: Qt.vector2d(0.25 / source.width, 0.25 / source.height)

        visible: false
        width: root.width / 1
        height: root.height / 1
        layer.enabled: root.active && root.usedPasses > 0
        layer.smooth: true
        fragmentShader: root.active && root.usedPasses > 0 ? root.shader("hyprblur2") : ""
    }

    // Noise and brightness below 1 (Hyprland blurFinish), also its own 8-bit buffer like in Hyprland
    ShaderEffect {
        id: fin

        property var source: up0
        property real noise: root.noise
        property real brightness: root.brightness
        property vector2d itemSize: Qt.vector2d(width, height)
        property vector2d screenSize: root.screenSize

        visible: false
        width: root.width
        height: root.height
        layer.enabled: root.active
        layer.smooth: true
        fragmentShader: root.active ? root.shader("hyprfinish") : ""
    }
}
