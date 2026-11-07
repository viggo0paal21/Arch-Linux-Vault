#version 440
// Wallpaper scaling exactly like awww (fast_image_resize, Lanczos3, fit_into_destination centered).
// One direction per pass (horizontal, then vertical). Qt's own image scaling came out about half a level
// darker than awww, which the glass then showed.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 dstSize;     // size of this pass in pixels
    float vertical;   // 0 = horizontal, 1 = vertical
    float zoom;       // destination pixels per source pixel
    float offset;     // source coordinate of the destination's left/top edge (centered crop)
    float rowStart;   // horizontal pass: image row of output row 0
} ubuf;

layout(binding = 1) uniform sampler2D source;


// Store exactly like Hyprland's 8-bit buffers. The graphics driver keeps only 12 bits of a color when it
// writes an 8-bit texture here and rounds up only from about x.56 instead of x.5 (measured, every stage
// came out up to 0.06 steps too dark). Rounding to the exact 8-bit step first makes the stored value exact.
vec4 store8(vec4 c) {
    return floor(clamp(c, 0.0, 1.0) * 255.0 + 0.5) / 255.0;
}

const float PI = 3.14159265358979323846;

float sinc(float x) {
    if (x == 0.0)
        return 1.0;
    x *= PI;
    return sin(x) / x;
}

float lanczos3(float x) {
    return abs(x) < 3.0 ? sinc(x) * sinc(x / 3.0) : 0.0;
}

void main() {
    ivec2 srcSize = textureSize(source, 0);
    ivec2 o = ivec2(floor(qt_TexCoord0 * ubuf.dstSize));
    bool vert = ubuf.vertical > 0.5;
    int n = vert ? srcSize.y : srcSize.x;
    float c = ubuf.offset + (float(vert ? o.y : o.x) + 0.5) / ubuf.zoom;
    float f = min(ubuf.zoom, 1.0);
    float support = 3.0 / f;
    int lo = max(0, int(floor(c - support)));
    int hi = min(n - 1, int(ceil(c + support)));
    vec4 sum = vec4(0.0);
    float wsum = 0.0;
    for (int j = lo; j <= hi; j++) {
        float w = lanczos3((float(j) + 0.5 - c) * f);
        ivec2 p = vert ? ivec2(o.x, j) : ivec2(j, o.y + int(ubuf.rowStart + 0.5));
        sum += texelFetch(source, p, 0) * w;
        wsum += w;
    }
    vec3 col = wsum != 0.0 ? sum.rgb / wsum : vec3(0.0);
    fragColor = store8(vec4(col, 1.0) * ubuf.qt_Opacity);
}
