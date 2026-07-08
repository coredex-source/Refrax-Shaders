/* Refrax — lib/clouds.glsl */
#ifndef REFRAX_CLOUDS
#define REFRAX_CLOUDS

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/noise.glsl"
#include "/lib/atmosphere.glsl"

float cloudDensity(vec3 wp, float time, float rain) {
    vec3 sp = wp * CLOUD_SCALE + vec3(CLOUD_WIND * time * CLOUD_SCALE, 0.0).xzy;
    float base = fbm3(sp * vec3(1.0, 2.4, 1.0), 4);
    float cov = CLOUD_COVERAGE + rain * 0.28;
    float h01 = saturate((wp.y - CLOUD_ALTITUDE) / CLOUD_THICKNESS);
    float profile = smoothstep(0.0, 0.18, h01) * smoothstep(1.0, 0.5, h01);
    return saturate((base - (1.02 - cov)) * 2.6) * profile;
}

float hgPhase(float cosT, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * PI * pow(1.0 + g2 - 2.0 * g * cosT, 1.5));
}

vec4 volumetricClouds(vec3 camWorld, vec3 dir, vec3 sunDir, float time, float rain, float dither) {
    float bottom = CLOUD_ALTITUDE, top = CLOUD_ALTITUDE + CLOUD_THICKNESS;
    if (abs(dir.y) < 0.015) return vec4(0.0, 0.0, 0.0, 1.0);
    float t0 = (bottom - camWorld.y) / dir.y;
    float t1 = (top - camWorld.y) / dir.y;
    if (t0 > t1) { float tmp = t0; t0 = t1; t1 = tmp; }
    t0 = max(t0, 0.0);
    if (t1 <= 0.0 || t0 > 9000.0) return vec4(0.0, 0.0, 0.0, 1.0);
    t1 = min(t1, t0 + 3500.0);

    int steps = PERF_SCALED_COUNT(CLOUD_STEPS, 4);
    float dt = (t1 - t0) / float(steps);
    float t = t0 + dt * dither;

    vec3 sunC = sunColor(sunDir.y) + moonColor(-sunDir.y) * 2.5;
    vec3 amb = skyAmbient(sunDir, rain);
    float phase = hgPhase(dot(dir, sunDir), 0.45) + 0.28;

    vec3 scatter = vec3(0.0);
    float trans = 1.0;
    for (int i = 0; i < steps; i++) {
        vec3 p = camWorld + dir * t;
        float d = cloudDensity(p, time, rain);
        if (d > 0.0) {
            
            float od = 0.0;
            float ldt = CLOUD_THICKNESS / float(CLOUD_LIGHT_STEPS + 1);
            for (int j = 1; j <= CLOUD_LIGHT_STEPS; j++)
                od += cloudDensity(p + sunDir * ldt * float(j), time, rain) * ldt;
            float sunT = exp(-od * CLOUD_DENSITY * 1.6);
            float powder = 1.0 - exp(-d * 14.0);
            vec3 li = sunC * sunT * phase * powder + amb * 0.35;
            float stepT = exp(-d * CLOUD_DENSITY * dt);
            scatter += li * trans * (1.0 - stepT);
            trans *= stepT;
            if (trans < 0.02) break;
        }
        t += dt;
    }
    
    float fade = 1.0 - saturate(t0 / 7000.0);
    return vec4(scatter * fade, mix(1.0, trans, fade));
}

vec4 clouds2D(vec3 camWorld, vec3 dir, vec3 sunDir, float time, float rain) {
    if (dir.y < 0.02) return vec4(0.0, 0.0, 0.0, 1.0);
    float t = (CLOUD_ALTITUDE + CLOUD_THICKNESS * 0.5 - camWorld.y) / dir.y;
    if (t < 0.0) return vec4(0.0, 0.0, 0.0, 1.0);
    vec3 p = camWorld + dir * t;
    float d = fbm3(vec3(p.xz * CLOUD_SCALE * 1.4, time * 0.02), 4);
    float a = saturate((d - (1.0 - (CLOUD_COVERAGE + rain * 0.28))) * 3.0) * saturate(dir.y * 6.0);
    a *= 1.0 - saturate(t / 8000.0);
    vec3 lit = mix(skyAmbient(sunDir, rain), sunColor(sunDir.y) * 0.35 + moonColor(-sunDir.y), 0.5);
    return vec4(lit * a, 1.0 - a * 0.85);
}

#endif
