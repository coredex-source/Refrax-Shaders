/* Refrax — lib/clouds.glsl */
#ifndef REFRAX_CLOUDS
#define REFRAX_CLOUDS

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/noise.glsl"
#include "/lib/atmosphere.glsl"

uniform int worldTime;
uniform int worldDay;

#define CU_BOTTOM CLOUD_ALTITUDE
#define CU_TOP (CLOUD_ALTITUDE + CLOUD_THICKNESS)
#define AC_BOTTOM (CU_TOP + CLOUD_LAYER_GAP)
#define AC_TOP (AC_BOTTOM + CLOUD_AC_THICKNESS)

float vnoise2(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash12(i), b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0)), d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm2(vec2 p, int octaves) {
    float v = 0.0, a = 0.5, w = 0.0;
    for (int i = 0; i < octaves; i++) {
        v += a * vnoise2(p);
        w += a;
        p = p * 2.17 + vec2(19.3, 7.7);
        a *= 0.5;
    }
    return v / max(w, 1e-4);
}

float cloudHash1(float x) {
    float i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(hash12(vec2(i, 3.7)), hash12(vec2(i + 1.0, 3.7)), f);
}

float cloudDayPhase() {
    return (float(worldDay % 8192) + float(worldTime) / 24000.0) * CLOUD_WEATHER_SPEED
         + CLOUD_SEED * 37.13;
}

float cloudDailyBias() {
    return (cloudHash1(cloudDayPhase() + 19.1) - 0.5) * CLOUD_DAILY_VARIANCE;
}

vec2 cloudWind(float time) {
    float speed = length(CLOUD_WIND);
    vec2 fwd = speed > 1e-4 ? CLOUD_WIND / speed : vec2(1.0, 0.0);
    vec2 side = vec2(-fwd.y, fwd.x);

    const float gustRate = 0.011;
    const float meanderRate = 0.0061;
    float along = speed * time + (CLOUD_WIND_GUST * speed / gustRate) * sin(gustRate * time);
    float across = (CLOUD_WIND_MEANDER * speed / meanderRate) * sin(meanderRate * time + 2.1);

    float dp = cloudDayPhase();
    vec2 drift = (vec2(cloudHash1(dp), cloudHash1(dp + 57.3)) * 2.0 - 1.0) * CLOUD_DRIFT_RANGE;

    return fwd * along + side * across + drift;
}

float cloudCoverage(vec2 xz, vec2 wind, float rain, float bias) {
    vec2 p = (xz + wind) * (CLOUD_SCALE * CLOUD_COVERAGE_SCALE);
    float large = fbm2(p, 3);
    return saturate(CLOUD_COVERAGE * 1.15 - 0.10 + (large - 0.5) * CLOUD_COVERAGE_CONTRAST
                  + rain * 0.30 + bias + cloudDailyBias());
}

float cumulusDensity(vec3 wp, vec2 wind, float rain, int lod) {
    float h = (wp.y - CU_BOTTOM) / CLOUD_THICKNESS;
    if (h < 0.0 || h > 1.0) return 0.0;

    float cov = cloudCoverage(wp.xz, wind, rain, 0.0);
    if (cov <= 0.002) return 0.0;

    float shear = pow(h, 1.5) * CLOUD_SHEAR * CLOUD_THICKNESS;
    vec3 sp = vec3(wp.x + wind.x + shear,
                   wp.y * CLOUD_VERTICAL_SCALE,
                   wp.z + wind.y + shear * 0.5) * CLOUD_SCALE;

    float base = fbm3(sp, lod == 0 ? 4 : 3);
    float prof = smoothstep(0.0, 0.18, h) * smoothstep(0.0, 0.55, 1.0 - h);
    float d = saturate((base - (1.0 - cov)) * 2.6) * prof;
    if (d <= 0.0) return 0.0;

    if (lod == 0) {
        float det = fbm3(sp * CLOUD_DETAIL_FREQ + vec3(31.7, 13.1, 7.9), 3);
        d = max(d - det * det * CLOUD_DETAIL_STRENGTH * (1.0 - 0.5 * h), 0.0);
    }
    return d;
}

#ifdef CLOUD_ALTOCUMULUS
float altocumulusDensity(vec3 wp, vec2 wind, float rain, int lod) {
    float h = (wp.y - AC_BOTTOM) / CLOUD_AC_THICKNESS;
    if (h < 0.0 || h > 1.0) return 0.0;

    float cov = cloudCoverage(wp.zx * 1.7 + 431.0, wind * 1.6, rain, CLOUD_ALTOCUMULUS_AMOUNT - 0.85);
    if (cov <= 0.002) return 0.0;

    vec3 sp = vec3(wp.x + wind.x * 1.6, wp.y * CLOUD_VERTICAL_SCALE * 1.6, wp.z + wind.y * 1.6)
            * (CLOUD_SCALE * 2.6);

    float base = fbm3(sp + 57.0, lod == 0 ? 4 : 3);
    float prof = smoothstep(0.0, 0.22, h) * smoothstep(0.0, 0.45, 1.0 - h);
    float d = saturate((base - (1.0 - cov)) * 2.8) * prof;
    if (d <= 0.0) return 0.0;

    if (lod == 0) {
        float det = fbm3(sp * (CLOUD_DETAIL_FREQ * 1.6) + 11.3, 2);
        d = max(d - det * det * CLOUD_DETAIL_STRENGTH * 0.8, 0.0);
    }
    return d * 0.8;
}
#endif

float hgPhase(float cosT, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * PI * pow(max(1.0 + g2 - 2.0 * g * cosT, 1e-4), 1.5));
}

float cloudPhase(float cosT) {
    return 0.78 * max(hgPhase(cosT, 0.80), hgPhase(cosT, 0.35) * 0.6)
         + 0.22 * hgPhase(cosT, -0.22);
}

float cumulusLightDepth(vec3 p, vec3 lightDir, vec2 wind, float rain, int steps) {
    float od = 0.0;
    float travelled = 0.0;
    float len = CLOUD_THICKNESS * 0.09;
    for (int i = 0; i < steps; i++) {
        travelled += len;
        od += cumulusDensity(p + lightDir * travelled, wind, rain, 1) * len;
        len *= 2.1;
    }
    return od;
}

vec3 cloudScatter(float density, float lightOD, float cosT, float heightFrac,
                  vec3 sunC, vec3 ambC, float extinction) {
    float powder = 1.0 - exp(-density * extinction * 8.0);
    float phase = cloudPhase(cosT);

    float sun = 0.0;
    float amp = 1.0;
    float ext = 1.0;
    for (int i = 0; i < CLOUD_SCATTER_OCTAVES; i++) {
        sun += amp * exp(-lightOD * extinction * ext) * (i == 0 ? phase : 0.30);
        amp *= 0.55 * (i == 0 ? powder : 1.0);
        ext *= 0.45;
    }
    return sunC * (sun * CLOUD_SUN_GAIN) + ambC * (CLOUD_AMBIENT + 0.50 * heightFrac);
}

float cloudShadow(vec3 worldPos, vec3 lightDir, float time, float rain) {
#if CLOUD_MODE == 0
    return 1.0;
#else
    float ly = lightDir.y;
    if (ly < 0.06) return 1.0;

    vec2 wind = cloudWind(time);
    float od = 0.0;
    for (int i = 0; i < 3; i++) {
        float y = CU_BOTTOM + CLOUD_THICKNESS * (float(i) + 0.5) / 3.0;
        float travel = (y - worldPos.y) / ly;
        if (travel <= 0.0) continue;
        vec3 p = worldPos + lightDir * min(travel, 8000.0);
        p.y = y;
        od += cumulusDensity(p, wind, rain, 1);
    }
    od *= (CLOUD_THICKNESS / 3.0) * CLOUD_DENSITY;

    float fade = smoothstep(0.06, 0.18, ly);
    return mix(1.0, exp(-od), CLOUD_SHADOW_STRENGTH * fade);
#endif
}

vec4 volumetricClouds(vec3 camWorld, vec3 dir, vec3 sunDir, float time, float rain, float dither, float maxDist) {
#if CLOUD_MODE != 2
    return vec4(0.0, 0.0, 0.0, 1.0);
#else
    if (dir.y < 0.006) return vec4(0.0, 0.0, 0.0, 1.0);

    vec2 wind = cloudWind(time);
    vec3 lightDir = sunDir.y > -0.04 ? sunDir : -sunDir;
    float cosT = dot(dir, lightDir);
    vec3 sunC = (sunColor(sunDir.y) + moonColor(-sunDir.y) * 2.2) * (1.0 - rain * 0.42);
    vec3 ambC = skyAmbient(sunDir, rain);

    vec3 scatter = vec3(0.0);
    float transmittance = 1.0;

    int primary = PERF_SCALED_COUNT(CLOUD_STEPS, 8);
    int lightSteps = PERF_SCALED_COUNT(CLOUD_LIGHT_STEPS, 2);

    {
        float t0 = (CU_BOTTOM - camWorld.y) / dir.y;
        float t1 = (CU_TOP - camWorld.y) / dir.y;
        if (t0 > t1) { float tmp = t0; t0 = t1; t1 = tmp; }
        t0 = max(t0, 0.0);
        t1 = min(min(t1, CLOUD_FADE_DIST), maxDist);

        if (t1 > t0) {
            int steps = clamp(int((t1 - t0) / (CLOUD_THICKNESS * 0.5)), primary, primary * 3);
            float dt = (t1 - t0) / float(steps);
            float t = t0 + dt * dither;

            for (int i = 0; i < steps; i++) {
                if (transmittance < 0.02) break;
                vec3 p = camWorld + dir * t;
                float d = cumulusDensity(p, wind, rain, 0);
                if (d > 0.0) {
                    float lightOD = cumulusLightDepth(p, lightDir, wind, rain, lightSteps);
                    float h = saturate((p.y - CU_BOTTOM) / CLOUD_THICKNESS);
                    float stepTrans = exp(-d * CLOUD_DENSITY * dt);
                    float fade = saturate(1.0 - t / CLOUD_FADE_DIST);
                    scatter += cloudScatter(d, lightOD, cosT, h, sunC, ambC, CLOUD_DENSITY)
                             * transmittance * (1.0 - stepTrans) * fade;
                    transmittance *= mix(1.0, stepTrans, fade);
                }
                t += dt;
            }
        }
    }

#ifdef CLOUD_ALTOCUMULUS
    if (transmittance > 0.02) {
        float t0 = (AC_BOTTOM - camWorld.y) / dir.y;
        float t1 = (AC_TOP - camWorld.y) / dir.y;
        if (t0 > t1) { float tmp = t0; t0 = t1; t1 = tmp; }
        t0 = max(t0, 0.0);
        t1 = min(min(t1, CLOUD_FADE_DIST * 1.4), maxDist);

        if (t1 > t0) {
            int steps = max(primary / 2, 4);
            float dt = (t1 - t0) / float(steps);
            float t = t0 + dt * dither;

            for (int i = 0; i < steps; i++) {
                if (transmittance < 0.02) break;
                vec3 p = camWorld + dir * t;
                float d = altocumulusDensity(p, wind, rain, 0);
                if (d > 0.0) {
                    float lightOD = d * CLOUD_AC_THICKNESS * 0.5;
                    float h = saturate((p.y - AC_BOTTOM) / CLOUD_AC_THICKNESS);
                    float stepTrans = exp(-d * CLOUD_DENSITY * dt);
                    float fade = saturate(1.0 - t / (CLOUD_FADE_DIST * 1.4));
                    scatter += cloudScatter(d, lightOD, cosT, h, sunC, ambC, CLOUD_DENSITY)
                             * transmittance * (1.0 - stepTrans) * fade;
                    transmittance *= mix(1.0, stepTrans, fade);
                }
                t += dt;
            }
        }
    }
#endif

    if (transmittance > 0.999) return vec4(0.0, 0.0, 0.0, 1.0);
    return vec4(scatter, transmittance);
#endif
}

vec4 clouds2D(vec3 camWorld, vec3 dir, vec3 sunDir, float time, float rain, float maxDist) {
    if (dir.y < 0.02) return vec4(0.0, 0.0, 0.0, 1.0);
    float t = (CU_BOTTOM + CLOUD_THICKNESS * 0.5 - camWorld.y) / dir.y;
    if (t < 0.0 || t >= maxDist) return vec4(0.0, 0.0, 0.0, 1.0);

    vec2 wind = cloudWind(time);
    vec3 p = camWorld + dir * t;
    float cov = cloudCoverage(p.xz, wind, rain, 0.0);

    float shape = fbm2((p.xz + wind) * (CLOUD_SCALE * 1.1), 4);
    float a = saturate((shape - (1.0 - cov)) * 2.6);
    float det = fbm2((p.xz + wind) * (CLOUD_SCALE * 5.0), 3);
    a = max(a - det * det * 0.45, 0.0);
    a *= saturate(dir.y * 6.0) * saturate(1.0 - t / CLOUD_FADE_DIST);

    float cosT = dot(dir, sunDir.y > -0.04 ? sunDir : -sunDir);
    vec3 sunC = (sunColor(sunDir.y) * 0.85 + moonColor(-sunDir.y)) * (1.0 - rain * 0.42);
    vec3 lit = mix(skyAmbient(sunDir, rain) * 0.9, sunC * (0.35 + cloudPhase(cosT)), 0.55);
    return vec4(lit * a, 1.0 - a * 0.88);
}

#endif
