/* Refrax — lib/wetness.glsl */
#ifndef REFRAX_WETNESS
#define REFRAX_WETNESS

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/noise.glsl"

const vec3 SNOW_ALBEDO = vec3(0.84, 0.88, 0.96);

struct WetResult {
    float wet;
    float puddle;
};

vec3 rainDirection() {
    vec2 w = CLOUD_WIND;
    float wl = length(w);
    vec2 h = wl > 1e-4 ? w / wl : vec2(1.0, 0.0);
    vec2 lateral = h * (RAIN_SLANT * 0.35);
    return normalize(vec3(lateral.x, -1.0, lateral.y));
}

float rainFlux(vec3 N, vec3 rainDir) {
    return saturate(dot(N, -rainDir) * 0.70 + 0.30);
}

float puddleField(vec2 worldXZ, float footprint) {
    float base = vnoise3(vec3(worldXZ * 0.22, 0.0));
    float detail = saturate(1.0 - footprint * 1.04);
    base += (vnoise3(vec3(worldXZ * 0.52, 7.3)) - 0.5) * (0.55 * detail);
    return saturate(base);
}

WetResult computeWetness(vec3 worldPos, vec3 N, float skyLight, float wetAmt, float biomeRain, float footprint) {
    WetResult w;
    w.wet = 0.0;
    w.puddle = 0.0;
#ifdef RAIN_PUDDLES
    float localWet = saturate(wetAmt) * saturate(biomeRain);
    if (localWet <= 0.0) return w;

    float open = smoothstep(0.55, 0.95, skyLight);
    float shelter = mix(1.0, smoothstep(0.72, 0.99, skyLight), RAIN_SHELTER);
    float exposed = open * shelter * rainFlux(N, rainDirection());
    w.wet = localWet * exposed;

    float presence = smoothstep(0.05, 0.35, localWet);
    float floorFace = smoothstep(0.86, 0.98, N.y);
    float field = puddleField(worldPos.xz, footprint);
    float thresh = clamp(0.66 - 0.24 * PUDDLE_AMOUNT, 0.06, 0.92);
    float band = max(0.04, footprint * 0.22);
    float p = smoothstep(thresh + 0.04 - band, thresh + 0.04 + band, field);
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

float snowField(vec3 worldPos, float footprint) {
#if PERF_SAMPLE_DEN >= 4
    return vnoise3(worldPos * vec3(0.16, 0.26, 0.16));
#else
    float detail = saturate(1.0 - footprint * 1.84);
    return vnoise3(worldPos * vec3(0.16, 0.26, 0.16)) * (1.0 - 0.34 * detail)
         + vnoise3(worldPos * vec3(0.92, 1.30, 0.92) + 27.0) * (0.34 * detail);
#endif
}

float snowAccumulation(vec3 worldPos, vec3 N, float skyLight, float amount, float footprint) {
    float up = smoothstep(0.28, 0.72, N.y);
    if (up <= 0.0) return 0.0;
    float open = smoothstep(0.42, 0.88, skyLight);
    if (open <= 0.0) return 0.0;
    float cover = saturate(amount * SNOW_AMOUNT);
    float edge = mix(0.86, -0.18, cover);
    float slope = 3.4 / (1.0 + footprint * 2.6);
    return saturate((snowField(worldPos, footprint) - edge) * slope) * up * open;
}

vec3 snowSparkle(vec3 worldPos, vec3 N, vec3 V, vec3 lightDir, float dist) {
    float fade = 1.0 - smoothstep(14.0, 34.0, dist);
    if (fade <= 0.0) return vec3(0.0);
    vec3 cell = floor(worldPos * 9.0);
    if (hash13(cell) < 0.86) return vec3(0.0);
    vec3 jitter = vec3(hash13(cell + vec3(41.0, 0.0, 0.0)),
                       hash13(cell + vec3(0.0, 57.0, 0.0)),
                       hash13(cell + vec3(0.0, 0.0, 73.0))) - 0.5;
    vec3 micro = normalize(N + jitter * 0.9);
    float spec = pow(saturate(dot(reflect(-V, micro), lightDir)), 90.0);
    return vec3(0.90, 0.95, 1.00) * (spec * fade * SNOW_SPARKLE * 3.0);
}

#endif
