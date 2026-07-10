/* Refrax — program/bloom_blur.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/bloom.glsl"

uniform sampler2D colortex4;
uniform float viewWidth, viewHeight;

/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 outTile;

const float gaussW[5] = float[](0.2042, 0.1802, 0.1238, 0.0663, 0.0276);

void main() {
    ivec2 texel = ivec2(gl_FragCoord.xy);
    vec2 viewSize = vec2(viewWidth, viewHeight);
    ivec2 lo, hi;
    int lvl = -1;
    for (int i = 0; i < BLOOM_LEVELS; i++) {
        lo = ivec2(0, int(viewSize.y * bloomLevelY(i) + 0.5));
        hi = ivec2(int(viewSize.x * bloomLevelScale(i) + 0.5),
                   int(viewSize.y * bloomLevelY(i + 1) + 0.5)) - 1;
        if (texel.y >= lo.y && texel.y <= hi.y) { lvl = i; break; }
    }
    if (lvl < 0 || texel.x > hi.x) {
        outTile = vec4(0.0);
        return;
    }

    vec3 acc = vec3(0.0);
    for (int i = -4; i <= 4; i++) {
#ifdef BLOOM_BLUR_VERTICAL
        ivec2 pos = ivec2(texel.x, clamp(texel.y + i, lo.y, hi.y));
#else
        ivec2 pos = ivec2(clamp(texel.x + i, lo.x, hi.x), texel.y);
#endif
        acc += texelFetch(colortex4, pos, 0).rgb * gaussW[abs(i)];
    }
    outTile = vec4(acc, 1.0);
}
