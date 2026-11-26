#version 440
// Hyprland blur, step 3: dual kawase upsample.
// Ported from Hyprland src/render/shaders/glsl/blur2.glsl. The output item is twice the size of the source,
// so uv = qt_TexCoord0 here replaces Hyprland's "v_texcoord / 2.0" on its shared framebuffer.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float radius;
    vec2 halfpixel;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 halfpixel = ubuf.halfpixel;
    float radius = ubuf.radius;

    vec4 sum = texture(source, uv + vec2(-halfpixel.x * 2.0, 0.0) * radius);

    sum += texture(source, uv + vec2(-halfpixel.x,  halfpixel.y) * radius) * 2.0;
    sum += texture(source, uv + vec2(0.0,           halfpixel.y * 2.0) * radius);
    sum += texture(source, uv + vec2(halfpixel.x,   halfpixel.y) * radius) * 2.0;
    sum += texture(source, uv + vec2(halfpixel.x * 2.0, 0.0) * radius);
    sum += texture(source, uv + vec2(halfpixel.x,  -halfpixel.y) * radius) * 2.0;
    sum += texture(source, uv + vec2(0.0,          -halfpixel.y * 2.0) * radius);
    sum += texture(source, uv + vec2(-halfpixel.x, -halfpixel.y) * radius) * 2.0;

    fragColor = (sum / 12.0) * ubuf.qt_Opacity;
}
