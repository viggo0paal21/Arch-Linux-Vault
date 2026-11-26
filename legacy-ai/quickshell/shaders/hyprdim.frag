#version 440
// kitty's window background over Hyprland's blur, computed like Hyprland composites it: black with an 8-bit
// alpha (background_opacity 0.55 -> 140/255), blur * (1 - alpha), rounded to the nearest 8-bit step.
// Blending it with Qt instead came out darker: the driver writes 8-bit textures rounding up only from
// about x.56 on, while Hyprland's output buffer rounds correctly. An exact 8-bit step is stored unchanged.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float dim;  // opacity of the black on top (0 = only the blur, 1 = black)
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 blurred = texture(source, qt_TexCoord0);
    float alpha = floor(clamp(ubuf.dim, 0.0, 1.0) * 255.0 + 0.5) / 255.0;
    vec4 color = vec4(blurred.rgb * (1.0 - alpha), blurred.a) * ubuf.qt_Opacity;
    fragColor = floor(clamp(color, 0.0, 1.0) * 255.0 + 0.5) / 255.0;
}
