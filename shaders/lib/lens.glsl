/* Refrax — lib/lens.glsl */
#ifndef REFRAX_LENS
#define REFRAX_LENS

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#define SPYGLASS_ITEM_ID 10030

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
#define FLARE_FOV_REFERENCE 1.37373871
#define FLARE_GAIN 0.15

vec2 flareOriginUV(vec3 sunPos, mat4 proj) {
    vec3 lightView = sunPos.z < 0.0 ? sunPos : -sunPos;
    vec4 clip = proj * vec4(lightView, 1.0);
    return clamp(clip.xy / max(clip.w, 1e-4), vec2(-4.0), vec2(4.0)) * 0.5 + 0.5;
}

float flareFovScale(mat4 proj) {
    return max(proj[1][1] / FLARE_FOV_REFERENCE, 0.05);
}

float flareDisc(vec2 d, float size, float hardness) {
    float v = min(saturate(1.0 - length(d) / size), 1.0 / hardness) * hardness;
    v *= v;
    return v * v;
}

float flareIris(vec2 d, vec2 axis, float size, float split) {
    return flareDisc(d - axis * split, size, 2.0) * flareDisc(d + axis * split, size, 2.0);
}

float flareGlint(vec2 d, float size) {
    return flareDisc(d, size, 1.5) + flareDisc(d, size * 4.0, 1.0) * 0.5;
}

float flareRing(vec2 d, float size, float width) {
    float band = saturate(1.0 - abs(length(d) / size - 1.0) / width);
    band *= band * (3.0 - 2.0 * band);
    return band * band;
}

vec3 flareSpectrum(vec2 d, float size, float width) {
    vec3 offs = abs(vec3(length(d) / size) - vec3(1.0, 0.90, 0.80));
    vec3 band = saturate(1.0 - offs / width);
    return band * band * (3.0 - 2.0 * band);
}

vec3 flareChroma(float t) {
    return t < 0.5 ? mix(vec3(2.20, 1.05, 0.15), vec3(2.00, 0.35, 1.30), t * 2.0)
                   : mix(vec3(2.00, 0.35, 1.30), vec3(0.20, 0.55, 2.40), t * 2.0 - 1.0);
}

vec3 flareShade(vec3 base, float t) {
    return mix(base, luminance(base) * flareChroma(t), LENS_DISPERSION);
}

vec3 lensFlare(vec2 coord, vec2 origin, vec3 tint, float aspect, float fov) {
    vec2 stretch = vec2(aspect, 1.0);
    vec2 axis = (vec2(0.5) - origin) * stretch;
    vec2 d = (coord - origin) * stretch;
    float spread = length(axis);

    float fadeIn = saturate(spread * 8.0);
    fadeIn *= fadeIn;
    float fadeOut = saturate((spread - 0.78) * 1.7);
    float chain = max(fadeIn - fadeOut, 0.0);
    float wide = 1.0 - fadeOut;

    float r = length(d);
    vec3 f = tint * ((exp(-r * 11.0 / fov) * 0.42 + exp(-r * 2.6 / fov) * 0.07) * wide);
    f += flareShade(tint, 0.05) * (flareGlint(d, 0.035 * fov) * 0.10 * wide);
    f += tint * (flareSpectrum(d, 0.30 * fov, 0.28) * (0.030 * wide));

    for (int i = 1; i <= LENS_GHOSTS; i++) {
        float t = mix(0.26, 1.04, (float(i) - 0.5) / float(LENS_GHOSTS));
        float jitter = fract(float(i) * 0.6180339887);
        float size = (0.09 + 0.075 * jitter) * fov;
        vec2 gd = d - axis * (t * 2.0);

        float body = flareIris(gd, axis, size, 0.055 + 0.05 * jitter) * 1.4
                   + flareDisc(gd, size * 1.9, 1.0) * 0.30
                   + flareGlint(gd - axis * 0.10, size * 0.22) * 0.22;

        f += flareShade(tint, saturate(t)) * (body * chain * 0.085 / (0.7 + 0.35 * float(i)));
    }

    vec2 hd = d - axis * 2.0;
    f += flareShade(tint, 1.0) * (flareRing(hd, 0.30 * fov, 0.12) * 0.045 * chain);
    f += tint * (flareSpectrum(hd, 0.46 * fov, 0.20) * (0.035 * chain));

    if (LENS_ANAMORPHIC > 0.0) {
        vec3 streak = mix(tint, luminance(tint) * vec3(0.30, 0.60, 1.80), 0.6);
        float core = exp(-abs(d.y) * 210.0 / fov) * exp(-abs(d.x) * 2.4);
        float bleed = exp(-abs(d.y) * 44.0 / fov) * exp(-abs(d.x) * 6.5);
        f += streak * ((core + bleed * 0.35) * (LENS_ANAMORPHIC * 0.55) * wide);
    }

    return f;
}

vec3 flareLightSample(sampler2D sceneTex, sampler2D depthTex, vec2 origin, vec3 sunPos,
                      mat4 modelViewInv, float aspect, float clarity) {
    vec3 lightView = sunPos.z < 0.0 ? sunPos : -sunPos;
    vec3 lightDir = normalize(mat3(modelViewInv) * lightView);
    float altitude = smoothstep(-0.06, 0.08, lightDir.y);
    if (altitude <= 0.0 || clarity <= 0.0) return vec3(0.0);

    vec3 tint = vec3(0.0);
    float sky = 0.0;
    for (int i = 0; i < 9; i++) {
        float a = float(i) * 0.6981317;
        vec2 o = i == 0 ? vec2(0.0) : vec2(cos(a), sin(a)) * 0.011;
        vec2 s = clamp(origin + o * vec2(1.0 / aspect, 1.0), vec2(0.0), vec2(1.0));
        if (textureLod(depthTex, s, 0.0).r < 1.0) continue;
        tint += textureLod(sceneTex, s, 0.0).rgb;
        sky += 1.0;
    }
    if (sky <= 0.0) return vec3(0.0);

    vec2 edge = min(origin, 1.0 - origin);
    float visibility = sky / 9.0 * altitude * clarity * saturate(min(edge.x, edge.y) * 3.0 + 1.0);
    return clamp(tint / sky, vec3(0.0), vec3(12.0)) * visibility;
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
