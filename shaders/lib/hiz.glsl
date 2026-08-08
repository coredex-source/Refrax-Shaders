/* Refrax — lib/hiz.glsl */
#ifndef REFRAX_HIZ
#define REFRAX_HIZ

#include "/lib/settings.glsl"

ivec2 hizSize(ivec2 full, int level) {
    return max((full + ((1 << level) - 1)) >> level, ivec2(1));
}

vec2 hizCellCount(ivec2 full, int level) {
    return vec2(full) / float(1 << level);
}

int hizYOffset(ivec2 full, int level) {
    int y = 0;
    for (int i = 1; i < level; i++) y += hizSize(full, i).y;
    return y;
}

ivec2 hizTexel(ivec2 full, int level, ivec2 p) {
    return ivec2(p.x, hizYOffset(full, level) + p.y);
}

#ifdef HIZ_READ
uniform sampler2D refraxHiZTex;

vec2 hizFetch(ivec2 full, int level, ivec2 p) {
    ivec2 sz = hizSize(full, level);
    p = clamp(p, ivec2(0), sz - 1);
    return texelFetch(refraxHiZTex, hizTexel(full, level, p), 0).rg;
}

vec2 hizFetchUV(ivec2 full, int level, vec2 uv) {
    return hizFetch(full, level, ivec2(uv * hizCellCount(full, level)));
}

bool hizSegmentClear(ivec2 full, vec3 a, vec3 b) {
    vec2 lo = min(a.xy, b.xy);
    vec2 hi = max(a.xy, b.xy);
    vec2 ext = (hi - lo) * vec2(full);
    int level = int(ceil(log2(max(max(ext.x, ext.y), 1.0)))) + 1;
    if (level > HIZ_LEVELS) return false;

    vec2 cellCount = hizCellCount(full, level);
    ivec2 c0 = ivec2(floor(lo * cellCount));
    ivec2 c1 = ivec2(floor(hi * cellCount));
    float minZ = min(min(hizFetch(full, level, c0).x, hizFetch(full, level, ivec2(c1.x, c0.y)).x),
                     min(hizFetch(full, level, ivec2(c0.x, c1.y)).x, hizFetch(full, level, c1).x));
    return minZ >= max(a.z, b.z);
}
#endif

#endif
