/* Refrax — lib/water.glsl */
#ifndef REFRAX_WATER
#define REFRAX_WATER

#include "/lib/settings.glsl"
#ifdef WATER_NOISY_WAVES
#include "/lib/noise.glsl"
#endif

const int WATER_RIPPLE_OCTAVES = PERF_SCALED_CONST(4);
const int WATER_NOISY_RIPPLE_OCTAVES = PERF_SCALED_CONST(6);

float waterCrest(float phase) {
    float s = sin(phase) * 0.5 + 0.5;
    return s * s * (3.0 - 2.0 * s);
}

float waterCrestDeriv(float phase) {
    float s = sin(phase) * 0.5 + 0.5;
    return 3.0 * s * (1.0 - s) * cos(phase);
}

vec3 waterWaveLayer(vec2 p, vec2 dir, float freq, float speed, float amp, float phase, float wt) {
    float x = dot(p, dir) * freq - wt * speed + phase;
    float h = (waterCrest(x) - 0.5) * amp;
    vec2 grad = dir * (waterCrestDeriv(x) * freq * amp);
    return vec3(h, grad);
}

vec3 waterSwellSample(vec2 p, float t) {
    float wt = t * WAVE_SPEED;
    vec3 s = vec3(0.0);

    s += waterWaveLayer(p, vec2(0.819, 0.574), 0.82, 0.78, 0.72, 0.0, wt);
    s += waterWaveLayer(p, vec2(-0.454, 0.891), 0.48, 0.52, 0.42, 1.7, wt);

    float x = dot(p, vec2(0.073, -0.052)) + wt * 0.27 + 2.4;
    s.x += sin(x) * 0.14;
    s.yz += vec2(0.073, -0.052) * (cos(x) * 0.14);
    return s;
}

float waterSwellField(vec2 p, float t) {
    return waterSwellSample(p, t).x;
}

#ifdef WATER_NOISY_WAVES
float waterNoisySwellField(vec2 p, float t) {
    float wt = t * WAVE_SPEED;
    float slow = fbm3(vec3(p * 0.018, wt * 0.035), 3) - 0.5;
    vec2 drift = vec2(slow, -slow) * 0.45;

    float h = 0.0;
    h += (waterCrest(dot(p + drift, vec2(0.819, 0.574)) * 0.82 - wt * 0.78 + slow * 2.2) - 0.5) * 0.72;
    h += (waterCrest(dot(p - drift, vec2(-0.454, 0.891)) * 0.48 - wt * 0.52 + 1.7 - slow * 2.5) - 0.5) * 0.42;
    h += sin(dot(p, vec2(0.073, -0.052)) + wt * 0.27 + slow * 3.1) * 0.14;
    return h;
}

float waterNoisyRippleField(vec2 p, float t) {
    float wt = t * WAVE_SPEED;
    float warp = fbm3(vec3(p * 0.026, wt * 0.055), 3) - 0.5;
    vec2 q = p + vec2(warp, -warp) * 0.55;

    const mat2 rot = mat2(-0.275637, 0.961262, -0.961262, -0.275637);
    vec2 dir = vec2(0.899, 0.438);
    float h = waterNoisySwellField(p, t) * 0.35;
    float amp = 1.0;
    float sum = 0.35;
    float freq = 1.25;

    for (int i = 0; i < WATER_NOISY_RIPPLE_OCTAVES; i++) {
        float fi = float(i);
        float n = vnoise3(vec3(q * (0.045 + freq * 0.012) + fi * vec2(2.17, 5.83), wt * 0.06 + fi * 9.1));
        float phase = (n - 0.5) * 4.8;
        float c = waterCrest(dot(q, dir) * freq - wt * (0.92 + fi * 0.18) + phase);

        h += (c - 0.5) * amp;
        sum += amp;
        amp *= 0.52;
        freq *= 1.68;
        q += dir * (0.19 + fi * 0.03);
        dir = rot * dir;
    }

    return h / sum;
}
#endif

vec3 waterRippleSample(vec2 p, float t) {
    float wt = t * WAVE_SPEED;
    const mat2 rot = mat2(-0.275637, 0.961262, -0.961262, -0.275637);
    vec2 dir = vec2(0.899, 0.438);
    vec3 wave = waterSwellSample(p, t) * 0.35;
    float amp = 1.0;
    float sum = 0.35;
    float freq = 1.25;

    for (int i = 0; i < WATER_RIPPLE_OCTAVES; i++) {
        float fi = float(i);
        wave += waterWaveLayer(p + dir * (0.17 + fi * 0.09), dir, freq, 0.92 + fi * 0.18, amp, fi * 2.37, wt);
        sum += amp;
        amp *= 0.50;
        freq *= 1.62;
        dir = rot * dir;
    }

    return wave / sum;
}

float waveHeight(vec2 p, float t) {
#ifndef WATER_WAVES
    return 0.0;
#elif defined WATER_NOISY_WAVES
    return waterNoisySwellField(p, t) * WATER_WAVE_HEIGHT * WATER_WAVE_INTENSITY;
#else
    return waterSwellField(p, t) * WATER_WAVE_HEIGHT * WATER_WAVE_INTENSITY;
#endif
}



vec3 waterNormal(vec2 p, float t, float viewDot, float sky, float rain) {
#ifndef WATER_WAVES
    return vec3(0.0, 1.0, 0.0);
#elif defined WATER_NOISY_WAVES
    const float e = 0.12;
    float h0 = waterNoisyRippleField(p, t);
    float hx = waterNoisyRippleField(p + vec2(e, 0.0), t);
    float hz = waterNoisyRippleField(p + vec2(0.0, e), t);

    float strength = mix(0.06, 0.26 + 0.75 * rain, sky * sky) * WATER_WAVE_INTENSITY;
    strength *= smoothstep(0.02, 0.18, viewDot);
    vec2 slope = clamp(vec2(h0 - hx, h0 - hz) / e * strength, vec2(-1.25), vec2(1.25));
    return normalize(vec3(slope.x, 1.0, slope.y));
#else
    vec3 wave = waterRippleSample(p, t);
    float strength = mix(0.035, 0.18 + 0.46 * rain, sky * sky) * WATER_WAVE_INTENSITY;
    strength *= smoothstep(0.02, 0.18, viewDot);
    vec2 slope = clamp(-wave.yz * strength, vec2(-1.0), vec2(1.0));
    return normalize(vec3(slope.x, 1.0, slope.y));
#endif
}


vec3 waterTransmittance(float dist) {
    return exp(-WATER_ABSORB * WATER_ABSORPTION * max(dist, 0.0));
}


vec3 waterTransmittanceTinted(vec3 biomeTint, float dist) {
    vec3 absorb = (vec3(1.05) - saturate(biomeTint)) * 1.5 * WATER_ABSORPTION;
    return exp(-absorb * max(dist, 0.0));
}

vec3 underwaterFogTint(vec3 fogCol, vec3 sunDir, float eyeSky, float rain) {
    vec3 fogLin = srgbToLinear(max(fogCol, vec3(0.0)));
    vec3 fogHue = fogLin / max(luminance(fogLin), 0.015);
    fogHue = clamp(fogHue * vec3(0.050, 0.095, 0.220), vec3(0.0), vec3(0.28, 0.46, 0.86));

    vec3 deepWater = vec3(0.006, 0.020, 0.055);
    vec3 clearWater = vec3(0.018, 0.060, 0.135);
    vec3 litWater = vec3(0.050, 0.130, 0.285);
    float daylight = saturate(sunDir.y * 0.55 + 0.45);
    vec3 tint = mix(deepWater, clearWater, saturate(eyeSky * 1.35));
    tint = mix(tint, litWater, eyeSky * (0.22 + 0.38 * daylight));
    tint = mix(tint, tint + fogHue, saturate(0.18 + eyeSky * 0.30));

    return max(tint * mix(0.48, 0.98, eyeSky) * (1.0 - rain * 0.18), vec3(0.002));
}

#endif
