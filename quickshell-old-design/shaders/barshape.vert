#version 440
// Vertex shader for barshape.frag, only used with OpenGL (see components/HyprBlur.qml, vshader()).
// The same as Qt's built-in ShaderEffect vertex shader, but also built for GLSL ES 3.00: OpenGL ES
// (what Qt uses on Wayland) needs both stages in the same GLSL version, and barshape.frag needs ES 3.00 for
// its integer math, while the built-in vertex shader only exists as ES 1.00. Vulkan keeps the built-in one.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 rect;      // shape: left, top, right, bottom in item pixels
    vec2 itemSize;  // item size in pixels
    vec2 origin;    // position of the item on the screen (whole pixels)
    float radius;   // corner radius
    float zoneY;    // first screen row where a window can be under the bar
    float dither;   // 1 = dither edge pixels in the window rows
    vec4 fill;      // color of the bar (premultiplied)
} ubuf;

out gl_PerVertex { vec4 gl_Position; };

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = ubuf.qt_Matrix * qt_Vertex;
}
