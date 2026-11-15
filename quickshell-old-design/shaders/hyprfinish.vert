#version 440
// Vertex shader for hyprfinish.frag, only used with OpenGL (see components/HyprBlur.qml, vshader()).
// The same as Qt's built-in ShaderEffect vertex shader, but also built for GLSL ES 3.00: OpenGL ES
// (what Qt uses on Wayland) needs both stages in the same GLSL version, and hyprfinish.frag needs ES 3.00 for
// its integer math, while the built-in vertex shader only exists as ES 1.00. Vulkan keeps the built-in one.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float noise;
    float brightness;
    vec2 itemSize;    // size of this item in pixels (top strip of the screen, starting at 0,0)
    vec2 screenSize;  // monitor size in pixels
} ubuf;

out gl_PerVertex { vec4 gl_Position; };

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = ubuf.qt_Matrix * qt_Vertex;
}
