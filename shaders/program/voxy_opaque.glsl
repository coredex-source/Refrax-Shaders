/* Refrax — program/voxy_opaque.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/noise.glsl"
#include "/lib/blockid.glsl"
#include "/lib/labpbr.glsl"
#include "/lib/dh.glsl"

layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outMaterial;

void voxy_emitFragment(VoxyFragmentParameters p) {
    vec4 base = p.sampledColour * p.tinting;
    if (base.a < 0.1) discard;

    int axis = int(p.face) >> 1;
    vec3 N = vec3(float(axis == 2), float(axis == 0), float(axis == 1))
           * (float(int(p.face) & 1) * 2.0 - 1.0);

    int id = int(p.customId);
    vec3 albedo = base.rgb;
    vec2 lm = saturate(p.lightMap);

#ifdef DH_NOISE
    vec4 v = vxProjInv * vec4(gl_FragCoord.xy / refraxViewSize * 2.0 - 1.0,
                              gl_FragCoord.z * 2.0 - 1.0, 1.0);
    if (abs(v.w) > 1e-8) {
        vec3 scenePos = (gbufferModelViewInverse * vec4(v.xyz / v.w, 1.0)).xyz;
        float dist = length(scenePos);
        vec3 wp = scenePos + cameraPosition;
        float grain = vnoise3(wp * 0.55) * 0.65 + vnoise3(wp * 2.2) * 0.35;
        float grainAmp = 0.12 * (1.0 - smoothstep(far, far * 4.0, dist));
        albedo *= 1.0 + (grain - 0.5) * grainAmp;
    }
#endif

    float emission = 0.0;
    float roughness = 0.9;
    float f0 = 0.04;
    if (id == 10008) {
        emission = 0.85;
    } else if (isEmitter(id)) {
        emission = emitterEmission(id, luminance(albedo));
    } else if (isFoliage(id)) {
        roughness = 1.0;
        f0 = MATTE_FOLIAGE_F0;
    }

    outAlbedo = vec4(saturate(albedo), 1.0);
    outNormal = vec4(N, emission);
    outMaterial = vec4(lm, roughness, f0);
}
