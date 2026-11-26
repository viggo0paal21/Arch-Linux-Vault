#version 440
// Hyprland blur, step 4: finish (noise, brightness below 1).
// Ported from Hyprland src/render/shaders/glsl/blurFinish.glsl (without color management).
// The noise hash gets v_texcoord exactly as the GPU interpolates it for Hyprland's full screen quad:
// (pixel + 0.5) * (1 / size), with 1 / size rounded to a float and the product rounded toward zero.
// Measured against a real kitty window: 92.7 % of the pixels come out exactly like kitty. Being off by the
// smallest float step already gives a completely different noise pattern, so it is built with integer math.
// The output is stored like Hyprland's buffer (an 8-bit texture, rounded by the driver in the same way).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float noise;
    float brightness;
    vec2 itemSize;    // size of this item in pixels (top strip of the screen, starting at 0,0)
    vec2 screenSize;  // monitor size in pixels
} ubuf;

layout(binding = 1) uniform sampler2D source;

// p / q as a float for 0 < p < q: correctly rounded, or rounded down (roundDown = true)
float exactRatio(uint p, uint q, bool roundDown) {
    uint r = p;
    int k = 0;
    while (r < q) {
        r <<= 1u;
        k++;
    }
    uint m = 0u;
    for (int i = 0; i < 24; i++) {
        m <<= 1u;
        if (r >= q) {
            m |= 1u;
            r -= q;
        }
        r <<= 1u;
    }
    bool roundBit = r >= q;
    bool sticky = (roundBit ? r - q : r) != 0u;
    if (!roundDown && roundBit && (sticky || (m & 1u) == 1u))
        m += 1u;
    if (m == (1u << 24u)) {
        m >>= 1u;
        k -= 1;
    }
    return uintBitsToFloat((uint(127 - k) << 23u) | (m & 0x7FFFFFu));
}

int bitLength(uint v) {
    int n = 0;
    while (v != 0u) {
        v >>= 1u;
        n++;
    }
    return n;
}

// (p + 0.5) * float(1 / size), rounded toward zero like the GPU's interpolation. The exact product has up to
// 38 bits, so it is built from two 26-bit halves (hi:lo) and cut down to the 24 bits of a float.
float pixelCoord(uint p, uint size) {
    uint rb = floatBitsToUint(exactRatio(1u, size, false));
    uint mr = (rb & 0x7FFFFFu) | 0x800000u;
    int er = int((rb >> 23u) & 0xFFu) - 150;
    uint n = 2u * p + 1u;
    uint a = n * (mr & 0xFFFu);
    uint b = n * (mr >> 12u);
    uint lo = (b << 12u) + a;
    uint hi = (b >> 20u) + (lo < (b << 12u) ? 1u : 0u);
    int len = hi != 0u ? 32 + bitLength(hi) : bitLength(lo);
    int shift = len - 24;
    uint m = shift == 0 ? lo : ((lo >> uint(shift)) | (hi << uint(32 - shift)));
    return uintBitsToFloat((uint(shift + er + 149) << 23u) | (m & 0x7FFFFFu));
}

// Hyprland's hash, written out step by step and marked precise: every operation rounds on its own like
// in Hyprland (no fused multiply-add). The noise reacts to the last bit of x * 1689.1984.
float hash(vec2 p) {
    precise vec3 t = vec3(p.xyx) * 1689.1984;
    precise vec3 p3 = t - floor(t);
    precise vec3 q = p3.yzx + vec3(33.33);
    precise float d0 = p3.x * q.x;
    precise float d1 = p3.y * q.y;
    precise float d2 = p3.z * q.z;
    precise float d = (d0 + d1) + d2;
    precise vec3 p4 = p3 + vec3(d);
    precise float s = p4.x + p4.y;
    precise float h = s * p4.z;
    return h - floor(h);
}

void main() {
    vec4 pixColor = texture(source, qt_TexCoord0);
    float brightnessMultiplier = min(1.0, ubuf.brightness);

    uvec2 px = uvec2(floor(qt_TexCoord0 * ubuf.itemSize));
    uvec2 sz = uvec2(ubuf.screenSize + 0.5);
    vec2 v_texcoord = vec2(pixelCoord(px.x, sz.x), pixelCoord(px.y, sz.y));

    float noiseHash   = hash(v_texcoord);
    float noiseAmount = noiseHash - 0.5;
    pixColor.rgb += noiseAmount * ubuf.noise * pixColor.a;

    pixColor.rgb *= brightnessMultiplier;

    fragColor = pixColor * ubuf.qt_Opacity;
}
