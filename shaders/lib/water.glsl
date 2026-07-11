/* Refrax — lib/water.glsl */
#ifndef REFRAX_WATER
#define REFRAX_WATER

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

float waterWaveField(sampler2D noiseTex, vec2 p, float t, float detailFade) {
    const mat2 turn = mat2(0.8192, 0.5736, -0.5736, 0.8192);
    vec2 wind = vec2(0.91, 0.42);

    vec2 broadUV = p * vec2(0.0054, 0.0062) - wind * (t * 0.0032);
    float broad = texture(noiseTex, broadUV).g;

    vec2 detailUV = (turn * p) * vec2(0.021, 0.018) + vec2(-wind.y, wind.x) * (t * 0.0085);
    float detail = texture(noiseTex, detailUV).r;
    detail = detail * detail * (3.0 - 2.0 * detail);

    float field = mix(broad, detail, 0.30 * detailFade);
#ifdef WATER_NOISY_WAVES
    vec2 microUV = (transpose(turn) * p) * vec2(0.043, 0.051) - wind.yx * (t * 0.013);
    float micro = texture(noiseTex, microUV).b;
    field = mix(field, micro, 0.10 * detailFade);
#endif
    return field;
}

vec3 waterNormal(sampler2D noiseTex, vec2 p, float t, float viewDot, float sky, float rain, float viewDistance) {
#ifndef WATER_WAVES
    return vec3(0.0, 1.0, 0.0);
#else
    float wt = t * WAVE_SPEED;
    float detailFade = 1.0 - smoothstep(64.0, 192.0, viewDistance);
    const float offset = 0.18;
    float left = waterWaveField(noiseTex, p - vec2(offset, 0.0), wt, detailFade);
    float right = waterWaveField(noiseTex, p + vec2(offset, 0.0), wt, detailFade);
    float down = waterWaveField(noiseTex, p - vec2(0.0, offset), wt, detailFade);
    float up = waterWaveField(noiseTex, p + vec2(0.0, offset), wt, detailFade);

    vec2 slope = vec2(left - right, down - up) / (2.0 * offset);
    float exposure = mix(0.78, 1.0, sky);
    float weather = 1.0 + rain * 0.18;
    float grazingStability = smoothstep(0.025, 0.15, viewDot);
    slope *= 0.29 * WATER_WAVE_INTENSITY * exposure * weather * grazingStability;
    slope = clamp(slope, vec2(-0.55), vec2(0.55));
    return normalize(vec3(-slope.x, 1.0, -slope.y));
#endif
}

float waterFresnel(float NoV) {
    float grazing = 1.0 - saturate(NoV);
    float grazing2 = grazing * grazing;
    return 0.02 + 0.98 * grazing2 * grazing2 * grazing;
}

float waterSurfaceAlpha(vec3 transmittance, float fresnel) {
    float depthOpacity = 1.0 - dot(transmittance, vec3(0.20, 0.65, 0.15));
    float bodyAlpha = mix(WATER_OPACITY, 0.82, saturate(depthOpacity));
    return mix(bodyAlpha, 1.0, fresnel);
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
