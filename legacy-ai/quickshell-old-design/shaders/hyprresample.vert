#version 440
// Vertex shader for hyprresample.frag, only used with OpenGL (see components/HyprBlur.qml, vshader()).
// The same as Qt's built-in ShaderEffect vertex shader, but also built for GLSL ES 3.00: OpenGL ES
// (what Qt uses on Wayland) needs both stages in the same GLSL version, and hyprresample.frag needs ES 3.00 for
// its integer math, while the built-in vertex shader only exists as ES 1.00. Vulkan keeps the built-in one.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 dstSize;     // size of this pass in pixels
    float vertical;   // 0 = horizontal, 1 = vertical
    float zoom;       // destination pixels per source pixel
    float offset;     // source coordinate of the destination's left/top edge (centered crop)
    float rowStart;   // horizontal pass: image row of output row 0
} ubuf;

out gl_PerVertex { vec4 gl_Position; };

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = ubuf.qt_Matrix * qt_Vertex;
}
