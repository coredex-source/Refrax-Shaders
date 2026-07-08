/* Refrax — lib/atomsphere.glsl */
#ifndef REFRAX_ATMOSPHERE
#define REFRAX_ATMOSPHERE

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/noise.glsl"


float dayFactor(float selev) { return smoothstep(-0.05, 0.10, selev); }

float duskFactor(float selev) { return exp(-selev * selev * 180.0); }


vec3 sunColor(float selev) {
    float t = saturate(selev * 5.0);
    vec3 ember = vec3(1.00, 0.22, 0.04);
    vec3 amber = vec3(1.00, 0.55, 0.22);
    vec3 day   = vec3(1.00, 0.97, 0.92);
    vec3 c = mix(mix(ember, amber, saturate(t * 2.2)), day, t * t);
    float up = smoothstep(-0.03, 0.02, selev);
    return c * SUN_BRIGHTNESS * up * mix(0.18, 1.0, t); 
}

vec3 moonColor(float melev) {
    return vec3(0.28, 0.40, 0.68) * MOON_BRIGHTNESS * smoothstep(-0.03, 0.06, melev);
}

vec3 zenithColor(float selev, float rain) {
    vec3 day   = vec3(0.13, 0.32, 0.80);
    vec3 dusk  = vec3(0.09, 0.12, 0.30);
    vec3 night = vec3(0.0028, 0.0044, 0.011);
    vec3 c = mix(night, day, dayFactor(selev));
    c = mix(c, dusk, duskFactor(selev) * 0.80);
    c = mix(c, vec3(luminance(c)) * 0.7, rain * 0.8);
    return c * SKY_SATURATION;
}
vec3 horizonColor(float selev, float rain) {
    vec3 day   = vec3(0.58, 0.75, 0.93);
    vec3 dusk  = vec3(0.48, 0.26, 0.22); 
    vec3 night = vec3(0.010, 0.014, 0.030);
    vec3 c = mix(night, day, dayFactor(selev));
    c = mix(c, dusk, duskFactor(selev) * 0.85);
    c = mix(c, vec3(luminance(c)) * 0.75, rain * 0.85);
    return c;
}

vec3 skyGradient(vec3 dir, vec3 sunDir, float rain) {
    float selev = sunDir.y;
    vec3 zen = zenithColor(selev, rain);
    vec3 hor = horizonColor(selev, rain);
    float h = pow(1.0 - saturate(dir.y), 3.0);
    vec3 sky = mix(zen, hor, h);
    float clearW = 1.0 - rain * 0.85;

    
    
    float dusk = duskFactor(selev);
    if (dusk > 0.001) {
        vec2 dirH = dir.xz / max(length(dir.xz), 1e-4);
        vec2 sunH = sunDir.xz / max(length(sunDir.xz), 1e-4);
        float az  = dot(dirH, sunH) * 0.5 + 0.5; 
        float az2 = az * az;
        vec3 glowCol = mix(vec3(0.30, 0.16, 0.34), vec3(1.05, 0.36, 0.08), az2);
        float band = pow(1.0 - saturate(dir.y), 2.5);
        sky += glowCol * (dusk * band * (0.25 + 1.05 * az2 * az) * clearW);
    }

    
    float sd = saturate(dot(dir, sunDir));
    sky += (pow(sd, 9.0) * 0.5 + pow(sd, 120.0)) * sunColor(selev) * 0.16 * (0.4 + h) * clearW;
    float md = saturate(dot(dir, -sunDir));
    sky += pow(md, 20.0) * moonColor(-selev) * 0.6 * clearW;

    if (dir.y < 0.0) sky = mix(sky, hor * 0.5, saturate(-dir.y * 4.0)); 
    return sky;
}


vec3 skyAmbient(vec3 sunDir, float rain) {
    float selev = sunDir.y;
    vec3 amb = zenithColor(selev, rain) * 0.60 + horizonColor(selev, rain) * 0.40;
    
    amb += vec3(0.45, 0.18, 0.05) * duskFactor(selev) * 0.18 * (1.0 - rain * 0.85);
    
    return max(amb * 0.85, vec3(0.0030, 0.0042, 0.0080));
}




vec3 skyAmbientDirectional(vec3 N, vec3 sunDir, float rain) {
    float up = saturate(N.y * 0.5 + 0.5);
    vec3 tint = mix(vec3(1.06, 0.97, 0.90), vec3(0.90, 0.97, 1.14), up);
    return skyAmbient(sunDir, rain) * tint * (0.75 + 0.30 * up);
}

float starField(vec3 dir, float time) {
    vec3 p = dir * 220.0;
    vec3 cell = floor(p);
    float h = hash13(cell);
    float star = step(0.9965, h);
    float tw = 0.75 + 0.25 * sin(time * 2.5 + h * 40.0);
    return star * tw;
}

vec3 celestial(vec3 dir, vec3 sunDir, float time, float rain) {
    float selev = sunDir.y;
    vec3 c = vec3(0.0);
    
    float sd = dot(dir, sunDir);
    c += smoothstep(0.99955, 0.99985, sd) * sunColor(selev) * 24.0;
    
    float md = dot(dir, -sunDir);
    c += smoothstep(0.99965, 0.99990, md) * vec3(0.75, 0.80, 0.95) * 1.6 * smoothstep(-0.06, 0.06, -selev);
    
    float night = smoothstep(0.02, -0.08, selev);
    c += starField(dir, time) * night * vec3(0.55, 0.62, 0.80) * saturate(dir.y * 2.0);
    return c * (1.0 - rain * 0.95);
}





vec3 netherSky(vec3 dir, vec3 fogCol, float time) {
    vec3 f = srgbToLinear(fogCol) * 1.2;
    float h = saturate(dir.y * 0.5 + 0.5);
    vec3 sky = mix(f * 1.15, f * 0.25, h); 
    float smoke = fbm3(vec3(dir.xz / max(abs(dir.y), 0.15) * 1.6, time * 0.02), 3);
    sky *= 0.8 + 0.4 * smoke;
    sky += vec3(0.30, 0.06, 0.008) * pow(1.0 - h, 3.0) * (0.5 + 0.5 * smoke);
    return sky;
}



vec3 endFogColor() { return vec3(0.034, 0.014, 0.058) * END_AMBIENT; }


vec3 endSky(vec3 dir, float time) {
    vec3 sky = vec3(0.012, 0.007, 0.022); 
    vec3 axis = normalize(vec3(0.42, 1.0, 0.18));
    float band = exp(-pow(dot(dir, axis), 2.0) * 4.5); 
    float neb  = fbm3(dir * 3.1 + vec3(0.0, time * 0.004, 0.0), 4);
    float hue  = fbm3(dir * 7.7 + 13.1, 3);
    vec3 nebCol = mix(vec3(0.14, 0.04, 0.26), vec3(0.04, 0.17, 0.21), hue);
    sky += band * (0.10 + 1.8 * smoothstep(0.45, 0.80, neb)) * nebCol;
    sky += band * vec3(0.08, 0.05, 0.13); 
    float stars = starField(dir, time);
    sky += stars * mix(vec3(0.40, 0.33, 0.55), vec3(0.65, 0.50, 0.90), band);
    sky *= mix(1.0, 0.35, smoothstep(-0.10, -0.60, dir.y)); 
    
    float haze = pow(1.0 - abs(dir.y), 3.0);
    return mix(sky, endFogColor() * 1.6, haze * 0.75);
}


vec3 dimensionSky(vec3 dir, vec3 sunDir, vec3 fogCol, float time, float rain) {
#if defined WORLD_NETHER
    return netherSky(dir, fogCol, time);
#elif defined WORLD_END
    return endSky(dir, time);
#else
    return skyGradient(dir, sunDir, rain) + celestial(dir, sunDir, time, rain);
#endif
}

float netherFacing(vec3 N) {
    return (0.85 + 0.15 * N.x) * (0.72 + 0.28 * abs(N.y));
}

vec3 netherAmbient(vec3 N, vec3 fogCol) {
    vec3 f = srgbToLinear(fogCol);
    vec3 hue = f / max(luminance(f), 1e-4);
    hue = mix(vec3(1.0), hue, 0.60);
    float up = saturate(N.y * 0.5 + 0.5);
    vec3 amb = hue * mix(0.115, 0.065, up);
    amb += vec3(0.055, 0.016, 0.004) * (1.0 - up);
    return amb * NETHER_AMBIENT;
}


vec3 endAmbient(vec3 N) {
    vec3 above = vec3(0.034, 0.014, 0.058);
    vec3 below = vec3(0.012, 0.006, 0.022);
    return mix(below, above, saturate(N.y * 0.5 + 0.5)) * END_AMBIENT;
}

vec3 endLightColor() { return vec3(1.00, 0.55, 0.30) * 0.55 * END_LIGHT; }

#endif
