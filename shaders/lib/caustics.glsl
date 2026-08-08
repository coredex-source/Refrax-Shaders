#ifndef REFRAX_CAUSTICS
#define REFRAX_CAUSTICS

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/water.glsl"

vec2 causticOffset(sampler2D waterTex, vec3 worldPos, vec3 lightDir, float t, float rain) {
    float roughness;
    float crest;
    vec3 N = waterSurfaceNormalFlow(waterTex, worldPos, vec2(0.0), t, 1.0, 1.0, rain, 0.0, CAUSTIC_STEP * 0.5, roughness, crest);
    return refractSafe(-lightDir, N, 1.0 / WATER_IOR).xz * CAUSTIC_DEPTH;
}

float waterCaustic(sampler2D waterTex, vec3 scenePos, vec3 camPos, vec3 lightDir, float t, float rain) {
#ifndef CAUSTICS_ACTIVE
    return 1.0;
#else
    vec3 p = scenePos + camPos;
    vec2 o0 = causticOffset(waterTex, p, lightDir, t, rain);
    vec2 ox = causticOffset(waterTex, p + vec3(CAUSTIC_STEP, 0.0, 0.0), lightDir, t, rain);
    vec2 oz = causticOffset(waterTex, p + vec3(0.0, 0.0, CAUSTIC_STEP), lightDir, t, rain);

    vec2 dx = vec2(CAUSTIC_STEP, 0.0) + ox - o0;
    vec2 dz = vec2(0.0, CAUSTIC_STEP) + oz - o0;
    float det = abs(dx.x * dz.y - dx.y * dz.x) / (CAUSTIC_STEP * CAUSTIC_STEP);

    float c = det < 1e-4 ? CAUSTIC_CLAMP : 1.0 / det;
    return clamp(mix(1.0, c, CAUSTIC_STRENGTH), 0.0, CAUSTIC_CLAMP);
#endif
}

#endif
