/* Refrax — program/bloom_downsample.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/bloom.glsl"

uniform float viewWidth, viewHeight;

#if BLOOM_LEVEL == 0
uniform sampler2D colortex0;
const float srcScale = 1.0;
const float srcY = 0.0;
vec3 srcFetch(vec2 c) { return max(textureLod(colortex0, c, 0.0).rgb, vec3(0.0)); }
#else
uniform sampler2D colortex4;
const float srcScale = bloomLevelScale(BLOOM_LEVEL - 1);
const float srcY = bloomLevelY(BLOOM_LEVEL - 1);
vec3 srcFetch(vec2 c) { return textureLod(colortex4, c, 0.0).rgb; }
#endif

const float lvlScale = bloomLevelScale(BLOOM_LEVEL);
const float lvlY = bloomLevelY(BLOOM_LEVEL);

const ivec2 kTap[13] = ivec2[](
    ivec2( 0,  0),
    ivec2(-1, -1), ivec2( 1, -1), ivec2(-1,  1), ivec2( 1,  1),
    ivec2(-2,  0), ivec2( 2,  0), ivec2( 0, -2), ivec2( 0,  2),
    ivec2(-2, -2), ivec2( 2, -2), ivec2(-2,  2), ivec2( 2,  2));
const float kWeight[13] = float[](
    0.125,
    0.125, 0.125, 0.125, 0.125,
    0.0625, 0.0625, 0.0625, 0.0625,
    0.03125, 0.03125, 0.03125, 0.03125);

/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 outTile;

void main() {
    ivec2 texel = ivec2(gl_FragCoord.xy);
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);

#if BLOOM_LEVEL > 0
    if (texel.y < int(viewHeight * lvlY + 0.5)) {
        outTile = texelFetch(colortex4, texel, 0);
        return;
    }
#endif
    if (texel.x >= int(viewWidth * lvlScale + 0.5)) {
        outTile = vec4(0.0);
        return;
    }

    vec2 c = ((vec2(texel) + 0.5) * px - vec2(0.0, lvlY)) / lvlScale;
    vec2 srcPx = px / srcScale;
    vec2 pad = 0.5 * srcPx;

    vec3 acc = vec3(0.0);
    for (int i = 0; i < 13; i++) {
        vec2 q = clamp(c + vec2(kTap[i]) * srcPx, pad, 1.0 - pad);
        acc += srcFetch(vec2(0.0, srcY) + q * srcScale) * kWeight[i];
    }
    outTile = vec4(acc, 1.0);
}
