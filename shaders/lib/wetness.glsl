/* Refrax — lib/wetness.glsl */
#ifndef REFRAX_WETNESS
#define REFRAX_WETNESS

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/noise.glsl"

struct WetResult {
    float wet;
    float puddle;
};

float puddleField(vec2 worldXZ) {
    float base = vnoise3(vec3(worldXZ * 0.22, 0.0));
    base += (vnoise3(vec3(worldXZ * 0.52, 7.3)) - 0.5) * 0.55;
    return saturate(base);
}

WetResult computeWetness(vec3 worldPos, float upFace, float skyLight, float wetAmt, float biomeRain) {
    WetResult w;
    w.wet = 0.0;
    w.puddle = 0.0;
#ifdef RAIN_PUDDLES
    float localWet = saturate(wetAmt) * saturate(biomeRain);
    if (localWet <= 0.0) return w;

    float exposed = smoothstep(0.55, 0.95, skyLight);
    w.wet = localWet * exposed;

    float presence = smoothstep(0.05, 0.35, localWet);
    float floorFace = smoothstep(0.86, 0.98, upFace);
    float field = puddleField(worldPos.xz);
    float thresh = clamp(0.66 - 0.24 * PUDDLE_AMOUNT, 0.06, 0.92);
    float p = smoothstep(thresh, thresh + 0.08, field);
    w.puddle = p * presence * floorFace * exposed;
#endif
    return w;
}

float puddleRippleHeight(vec2 p, float t) {
    p *= 0.72;
    vec2 cell = floor(p);
    vec2 f = fract(p);
    float seed = hash12(cell);
    float cyc = t * 1.32 + seed * 7.0;
    float ci = floor(cyc);
    float ph = fract(cyc);
    float impactMask = step(0.28, hash12(cell + ci + 4.17));
    vec2 drop = vec2(hash12(cell + ci + 0.31), hash12(cell + ci + 0.67)) * 0.60 + 0.20;
    float d = length(f - drop);
    float front = ph * 0.24;
    float leading = 1.0 - smoothstep(0.012, 0.040, abs(d - front));
    float trailingCenter = max(front - 0.060, 0.0);
    float trailing = (1.0 - smoothstep(0.014, 0.045, abs(d - trailingCenter))) * smoothstep(0.045, 0.095, front);
    float fade = smoothstep(0.015, 0.090, ph) * (1.0 - smoothstep(0.52, 1.0, ph));
    float ring = (leading - trailing * 0.38) * impactMask * fade;
    ring *= 1.0 - smoothstep(0.22, 0.30, d);
    return ring * 0.35;
}

vec3 puddleNormal(vec2 worldXZ, vec3 geomNormal, float t, float rain) {
    vec3 flatN = normalize(mix(geomNormal, vec3(0.0, 1.0, 0.0), 0.9));
    if (rain <= 0.0) return flatN;
    float e = 0.07;
    float rainResponse = smoothstep(0.08, 0.75, saturate(rain));
    float amp = 0.035 * rainResponse;
    float h0 = puddleRippleHeight(worldXZ, t);
    float hx = puddleRippleHeight(worldXZ + vec2(e, 0.0), t);
    float hz = puddleRippleHeight(worldXZ + vec2(0.0, e), t);
    vec2 slope = vec2(h0 - hx, h0 - hz) / e * amp;
    return normalize(flatN + vec3(slope.x, 0.0, slope.y));
}

#endif
