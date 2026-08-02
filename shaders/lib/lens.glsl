/* Refrax — lib/lens.glsl */
#ifndef REFRAX_LENS
#define REFRAX_LENS

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#define SPYGLASS_ITEM_ID 10030
#define HAND_DEPTH_LIMIT 0.56

#ifdef DEPTH_OF_FIELD
float dofCoc(float dist, float focus) {
    return saturate(abs(dist - focus) / max(dist, 0.35) * DOF_STRENGTH);
}

vec2 dofHexOffset(int i, int count, float rotation) {
    float t = (float(i) + 0.5) / float(count);
    float a = float(i) * 2.39996323 + rotation;
    float hex = 0.86602540 / cos(mod(a, 1.04719755) - 0.52359878);
    return vec2(cos(a), sin(a)) * (sqrt(t) * hex);
}
#endif

#ifdef LENS_FLARE_ACTIVE
vec3 lensFlare(vec2 uv, vec2 sunUV, vec3 tint, float aspect) {
    vec2 stretch = vec2(aspect, 1.0);
    vec2 d = (uv - sunUV) * stretch;
    float r = length(d);
    vec3 f = tint * (exp(-r * 11.0) * 0.42 + exp(-r * 2.6) * 0.07);

    if (LENS_ANAMORPHIC > 0.0)
        f += tint * exp(-abs(d.y) * 210.0) * exp(-abs(d.x) * 2.4) * (LENS_ANAMORPHIC * 0.55);

    vec2 ghostVec = (vec2(0.5) - sunUV) * 0.45;
    for (int i = 1; i <= LENS_GHOSTS; i++) {
        vec2 gd = (uv - (sunUV + ghostVec * float(i))) * stretch;
        float rad = 0.028 + 0.015 * float(i);
        float disc = saturate(1.0 - length(gd) / rad);
        disc *= disc * (3.0 - 2.0 * disc);
        vec3 gt = mix(tint, tint.bgr, float(i) / float(LENS_GHOSTS + 1));
        f += gt * (disc * 0.085 / float(i));
    }

    vec2 hd = (uv - (vec2(1.0) - sunUV)) * stretch;
    f += tint.gbr * (exp(-abs(length(hd) - 0.24) * 28.0) * 0.05);
    return f;
}
#endif

#ifdef PURKINJE
vec3 purkinjeShift(vec3 c, float strength) {
    float rod = dot(max(c, vec3(0.0)), vec3(0.12, 0.58, 0.78));
    vec3 scotopic = vec3(rod) * vec3(0.66, 0.84, 1.24);
    float w = strength * (1.0 - smoothstep(PURKINJE_ONSET * 0.05, PURKINJE_ONSET, luminance(c)));
    return mix(c, scotopic, saturate(w));
}
#endif

#ifdef FILM_GRAIN
float filmGrain(vec2 px, int frame) {
    vec3 p = fract(vec3(px, float(frame % 1024)) * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z) - 0.5;
}
#endif

#endif
