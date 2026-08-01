/* Refrax — lib/thunder.glsl */

#ifndef REFRAX_THUNDER
#define REFRAX_THUNDER

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#if defined THUNDER_FLASH && defined IS_IRIS && !defined WORLD_NETHER && !defined WORLD_END
  #define THUNDER_ACTIVE
#endif

const vec3 THUNDER_TINT = vec3(0.80, 0.87, 1.00);
const float THUNDER_LIFT = 24.0;
const float THUNDER_RANGE = 88.0;
const float THUNDER_RANGE2 = THUNDER_RANGE * THUNDER_RANGE;

vec3 thunderLight(vec3 scenePos, vec3 N, float skyLight, vec4 bolt) {
    if (bolt.w < 0.5) return vec3(0.0);
    vec3 toBolt = bolt.xyz + vec3(0.0, THUNDER_LIFT, 0.0) - scenePos;
    float d2 = dot(toBolt, toBolt);
    vec3 L = toBolt * inversesqrt(max(d2, 1e-4));
    float atten = THUNDER_RANGE2 / (THUNDER_RANGE2 + d2);
    float wrap = saturate(dot(N, L) * 0.55 + 0.45);
    float reach = smoothstep(0.02, 0.40, skyLight);
    return THUNDER_TINT * (atten * wrap * reach * THUNDER_STRENGTH * 2.5);
}

float thunderSkyGlow(vec4 bolt) {
    if (bolt.w < 0.5) return 0.0;
    float d2 = dot(bolt.xz, bolt.xz);
    return THUNDER_STRENGTH * (THUNDER_RANGE2 * 4.0) / (THUNDER_RANGE2 * 4.0 + d2);
}

#endif
