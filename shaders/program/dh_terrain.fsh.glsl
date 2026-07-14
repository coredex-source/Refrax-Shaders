/* Refrax — program/dh_terrain.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/noise.glsl"
#include "/lib/labpbr.glsl"
#include "/lib/dh.glsl"

uniform vec3 cameraPosition;
uniform float far;
uniform int frameCounter;

in vec2 lmcoord;
in vec4 vcolor;
in vec3 normalW;
in vec3 scenePos;
in float viewZ;
flat in int matId;

/* RENDERTARGETS: 1,2,3 */
layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outMaterial;

void main() {
#ifdef DISTANT_HORIZONS
    float dist = length(scenePos);
    if (ignAnim(gl_FragCoord.xy, frameCounter) > dhOverdrawFade(dist, far)) discard;

    vec3 albedo = vcolor.rgb;
    vec3 N = normalize(normalW);

#ifdef DH_NOISE
    vec3 wp = scenePos + cameraPosition;
    float grain = vnoise3(wp * 0.55) * 0.65 + vnoise3(wp * 2.2) * 0.35;
    float grainAmp = 0.12 * (1.0 - smoothstep(far, far * 4.0, dist));
    albedo *= 1.0 + (grain - 0.5) * grainAmp;
#endif

    float luma = luminance(albedo);
    float emission = 0.0;
    float roughness = 0.9;
    float f0 = 0.04;

    if (matId == DH_BLOCK_LAVA) {
        emission = 0.85;
    } else if (matId == DH_BLOCK_ILLUMINATED) {
        emission = 0.10 + 0.90 * luma * luma * luma;
    } else if (matId == DH_BLOCK_LEAVES) {
        roughness = 1.0;
        f0 = MATTE_FOLIAGE_F0;
    } else if (matId == DH_BLOCK_SNOW) {
        roughness = 0.55;
        f0 = 0.045;
    }

    outAlbedo = vec4(saturate(albedo), 1.0);
    outNormal = vec4(N, emission);
    outMaterial = vec4(lmcoord, roughness, f0);
#else
    discard;
#endif
}
