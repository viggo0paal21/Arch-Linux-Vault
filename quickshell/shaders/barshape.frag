#version 440
// Background of the bar with Hyprland's blur ("Glass blur: Hyprland"), drawn instead of a Rectangle so its
// edges can sit between two pixels while the bar docks and undocks, like the content and like the own glass.
//
// Hyprland blurs a pixel of the bar only if its alpha is above ignore_alpha (0.5). An edge pixel that is
// only partly covered gets no blur; over a window (kitty) the window then shows through it darkened by the
// bar's black: the dark line. Above the windows (rows above zoneY, only the wallpaper there) plain
// antialiasing is right. In the rows where a window can be under the bar, while dither is set, an edge pixel
// is either full glass (blurred, alpha = bar opacity) or at most a low level that stays below the threshold.
// Which pixels are full follows a fixed ordered pattern along the edge (bit-reversed index), so the share of
// full pixels equals the coverage and the edge moves smoothly on average, the same over any background.
// The low level is kept small enough that its missing blur is at most 4 % of the difference (lo below).
// Pixels that are fully covered or empty are unchanged, so at rest (edges on whole pixels) it is the same
// as a plain antialiased rectangle.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

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

float bitrev(uint v, uint bits) {
    uint r = 0u;
    for (uint i = 0u; i < bits; i++) {
        r = (r << 1u) | (v & 1u);
        v >>= 1u;
    }
    return float(r);
}

void main() {
    vec2 p = qt_TexCoord0 * ubuf.itemSize;  // pixel center
    vec2 c = 0.5 * (ubuf.rect.xy + ubuf.rect.zw);
    vec2 h = max(0.5 * (ubuf.rect.zw - ubuf.rect.xy), vec2(0.0));
    float r = clamp(ubuf.radius, 0.0, min(h.x, h.y));
    vec2 q = abs(p - c) - (h - r);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    // On the straight edges this is exactly the covered part of the pixel
    float cov = clamp(0.5 - d, 0.0, 1.0);
    float a = cov;
    vec2 s = ubuf.origin + floor(p);  // screen pixel
    bool corner = q.x > 0.0 && q.y > 0.0;
    if (ubuf.dither > 0.5 && cov > 0.0 && cov < 1.0 && s.y >= ubuf.zoneY && !corner) {
        float o = max(ubuf.qt_Opacity, 0.001);
        float lo = min(min(0.49 / o, 0.04 / max(1.0 - o, 0.0001)), 1.0);
        if (cov > lo) {
            // Bottom edge: pattern along x (64 px), side edges: along y (16 px)
            float t = q.y >= q.x
                ? (bitrev(uint(mod(s.x, 64.0)), 6u) + 0.5) / 64.0
                : (bitrev(uint(mod(s.y, 16.0)), 4u) + 0.5) / 16.0;
            a = (cov - lo) / (1.0 - lo) > t ? 1.0 : lo;
        }
    }
    fragColor = ubuf.fill * (a * ubuf.qt_Opacity);
}
