#version 440
// Hyprland blur, step 1: prepare (contrast as a gain curve, brightness above 1).
// Ported from Hyprland src/render/shaders/glsl/blurprepare.glsl + gain.glsl (without color management).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float contrast;
    float brightness;
} ubuf;

layout(binding = 1) uniform sampler2D source;

vec3 gain(vec3 src, float k) {
    vec3 x = clamp(src, 0.0, 1.0);
    vec3 t = step(0.5, x);
    vec3 y = mix(x, 1.0 - x, t);
    vec3 a = 0.5 * pow(2.0 * y, vec3(k));
    return mix(a, 1.0 - a, t);
}

void main() {
    vec4 pixColor = texture(source, qt_TexCoord0);
    if (pixColor.a <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    if (ubuf.contrast != 1.0)
        pixColor.rgb = gain(pixColor.rgb / pixColor.a, ubuf.contrast) * pixColor.a;
    pixColor.rgb *= max(1.0, ubuf.brightness);
    fragColor = pixColor * ubuf.qt_Opacity;
}
