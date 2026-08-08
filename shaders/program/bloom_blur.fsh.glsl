/* Refrax — program/bloom_blur.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/bloom.glsl"

uniform sampler2D colortex4;
uniform float viewWidth, viewHeight;

/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 outTile;

const float tapWeight[3] = float[](0.2042, 0.3040, 0.0939);
const float tapOffset[3] = float[](0.0, 1.4072368, 3.2939297);

void main() {
    ivec2 texel = ivec2(gl_FragCoord.xy);
    vec2 viewSize = vec2(viewWidth, viewHeight);
    ivec2 lo = ivec2(0), hi = ivec2(-1);
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

    vec3 acc = texelFetch(colortex4, texel, 0).rgb * tapWeight[0];
    vec2 center = vec2(texel) + 0.5;
    for (int i = 1; i < 3; i++) {
#ifdef BLOOM_BLUR_VERTICAL
        float far = clamp(center.y + tapOffset[i], float(lo.y) + 0.5, float(hi.y) + 0.5);
        float near = clamp(center.y - tapOffset[i], float(lo.y) + 0.5, float(hi.y) + 0.5);
        acc += (texture(colortex4, vec2(center.x, far) / viewSize).rgb
              + texture(colortex4, vec2(center.x, near) / viewSize).rgb) * tapWeight[i];
#else
        float far = clamp(center.x + tapOffset[i], float(lo.x) + 0.5, float(hi.x) + 0.5);
        float near = clamp(center.x - tapOffset[i], float(lo.x) + 0.5, float(hi.x) + 0.5);
        acc += (texture(colortex4, vec2(far, center.y) / viewSize).rgb
              + texture(colortex4, vec2(near, center.y) / viewSize).rgb) * tapWeight[i];
#endif
    }
    outTile = vec4(acc, 1.0);
}
