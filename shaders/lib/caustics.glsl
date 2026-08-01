/* Refrax — lib/caustics.glsl */

#ifndef REFRAX_CAUSTICS
#define REFRAX_CAUSTICS

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/water.glsl"


vec3 refractSafe(vec3 incident, vec3 N, float eta) {
    float NoI = dot(N, incident);
    float k = 1.0 - eta * eta * (1.0 - NoI * NoI);
    if (k < 0.0) return vec3(0.0);
    return eta * incident - (eta * NoI + sqrt(k)) * N;
}


vec2 causticOffset(sampler2D noiseTex, vec2 worldXZ, vec3 lightDir, float t, float rain, float dist) {
    vec3 N = waterNormal(noiseTex, worldXZ, t, 1.0, 1.0, rain, dist);
    return refractSafe(-lightDir, N, 1.0 / WATER_IOR).xz * CAUSTIC_DEPTH;
}


float waterCaustic(sampler2D noiseTex, vec3 scenePos, vec3 camPos, vec3 lightDir, float t, float rain) {
#ifndef CAUSTICS_ACTIVE
    return 1.0;
#else
    vec2 p = (scenePos + camPos).xz;
    float dist = length(scenePos);

    vec2 o0 = causticOffset(noiseTex, p, lightDir, t, rain, dist);
    vec2 ox = causticOffset(noiseTex, p + vec2(CAUSTIC_STEP, 0.0), lightDir, t, rain, dist);
    vec2 oz = causticOffset(noiseTex, p + vec2(0.0, CAUSTIC_STEP), lightDir, t, rain, dist);

    vec2 dx = vec2(CAUSTIC_STEP, 0.0) + ox - o0;
    vec2 dz = vec2(0.0, CAUSTIC_STEP) + oz - o0;
    float det = abs(dx.x * dz.y - dx.y * dz.x) / (CAUSTIC_STEP * CAUSTIC_STEP);

    float c = det < 1e-4 ? CAUSTIC_CLAMP : 1.0 / det;
    return clamp(mix(1.0, c, CAUSTIC_STRENGTH), 0.0, CAUSTIC_CLAMP);
#endif
}

#endif
