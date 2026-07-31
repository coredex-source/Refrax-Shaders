/* Refrax — lib/atmosphere_lut.glsl */
#ifndef REFRAX_ATMOSPHERE_LUT
#define REFRAX_ATMOSPHERE_LUT

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

const float ATMOS_GROUND_R = 6.360;
const float ATMOS_TOP_R = 6.460;
const float ATMOS_DEPTH = ATMOS_TOP_R - ATMOS_GROUND_R;

const vec3 ATMOS_RAYLEIGH_BASE = vec3(5.802, 13.558, 33.100);
const float ATMOS_RAYLEIGH_MEAN = 13.3200;
const vec3 ATMOS_RAYLEIGH_S = mix(vec3(ATMOS_RAYLEIGH_MEAN), ATMOS_RAYLEIGH_BASE, SKY_BLUENESS);
const float ATMOS_RAYLEIGH_H = 0.008;

const float ATMOS_MIE_S = 3.996;
const float ATMOS_MIE_A = 4.400;
const float ATMOS_MIE_H = 0.0012;
const float ATMOS_MIE_G = 0.80;

const float ATMOS_HAZE_E = ATMOS_HAZE * CALM_HAZE;

const vec3 ATMOS_OZONE_A = vec3(0.650, 1.881, 0.085);
const float ATMOS_OZONE_MID = 0.025;
const float ATMOS_OZONE_HALF = 0.015;

const float ATMOS_GROUND_ALBEDO = 0.30;

const vec3 ATMOS_RAYLEIGH_AERIAL = mix(vec3(ATMOS_RAYLEIGH_MEAN), ATMOS_RAYLEIGH_BASE, SKY_BLUENESS * AERIAL_BLUENESS);

const float ATMOS_SIGMA_E_REF = ATMOS_RAYLEIGH_AERIAL.g + (ATMOS_MIE_S + ATMOS_MIE_A) * ATMOS_HAZE_E;

const ivec2 ATMOS_TRANSMITTANCE_RES = ivec2(256, 64);
const ivec2 ATMOS_MULTISCATTER_RES = ivec2(32, 32);
const ivec2 ATMOS_SKYVIEW_RES = ivec2(192, 108);

const float ATMOS_SKY_GAIN = 18.1;
const float ATMOS_SUN_GAIN = 1.12;
const float ATMOS_MOON_GAIN = 0.70;
const vec3 ATMOS_MOON_TINT = vec3(0.45, 0.66, 1.05);

const float ATMOS_HORIZON_FADE = 0.55;
const float HORIZON_BRIGHTNESS_E = HORIZON_BRIGHTNESS * CALM_HORIZON;

float atmosHorizonRolloff(float elevation) {
    return mix(1.0, HORIZON_BRIGHTNESS_E, smoothstep(ATMOS_HORIZON_FADE, 0.0, abs(elevation)));
}

const float ATMOS_AERIAL_AMBIENT = 0.46;
const float ATMOS_MOON_SKY = 0.022;
const vec3 ATMOS_NIGHT_FLOOR = vec3(0.00120, 0.00170, 0.00320);

const float ATMOS_SEA_LEVEL = 62.0;

float atmosSafeAcos(float x) { return acos(clamp(x, -1.0, 1.0)); }

float atmosRaySphere(vec3 ro, vec3 rd, float rad) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - rad * rad;
    if (c > 0.0 && b > 0.0) return -1.0;
    float disc = b * b - c;
    if (disc < 0.0) return -1.0;
    float d = sqrt(disc);
    if (d - b < 0.0) return -1.0;
    return (-b - d < 0.0) ? (-b + d) : (-b - d);
}

vec3 atmosDensity(float h) {
    return vec3(exp(-max(h, 0.0) / ATMOS_RAYLEIGH_H), exp(-max(h, 0.0) / ATMOS_MIE_H), max(0.0, 1.0 - abs(h - ATMOS_OZONE_MID) / ATMOS_OZONE_HALF));
}

void atmosScatter(float h, out vec3 sigmaR, out float sigmaM, out vec3 sigmaE) {
    vec3 d = atmosDensity(h);
    sigmaR = ATMOS_RAYLEIGH_S * d.x;
    sigmaM = ATMOS_MIE_S * ATMOS_HAZE_E * d.y;
    sigmaE = sigmaR + vec3(sigmaM + ATMOS_MIE_A * ATMOS_HAZE_E * d.y) + ATMOS_OZONE_A * ATMOS_OZONE * d.z;
    sigmaE = max(sigmaE, vec3(1e-6));
}

float atmosRayleighPhase(float c) { return (3.0 / (16.0 * PI)) * (1.0 + c * c); }

float atmosMiePhase(float c) {
    const float g2 = ATMOS_MIE_G * ATMOS_MIE_G;
    float denom = 1.0 + g2 - 2.0 * ATMOS_MIE_G * c;
    return (3.0 / (8.0 * PI)) * ((1.0 - g2) * (1.0 + c * c)) / ((2.0 + g2) * max(denom * sqrt(max(denom, 1e-4)), 1e-4));
}

float atmosAltitude(float camY) {
    return max(camY - ATMOS_SEA_LEVEL, 0.0) * ATMOS_ALTITUDE_SCALE * 1e-6;
}

vec2 atmosTransmittanceUV(float h, float mu) {
    return vec2(saturate(0.5 + 0.5 * mu), sqrt(saturate(h / ATMOS_DEPTH)));
}
float atmosHeightFromV(float v) { return v * v * ATMOS_DEPTH; }

vec2 atmosMultiScatterUV(float h, float muSun) {
    return vec2(saturate(0.5 + 0.5 * muSun), sqrt(saturate(h / ATMOS_DEPTH)));
}

float atmosHorizonDip(float h) {
    float r = ATMOS_GROUND_R + h;
    return 0.5 * PI - atmosSafeAcos(sqrt(max(h * (2.0 * ATMOS_GROUND_R + h), 0.0)) / r);
}

vec3 atmosComputeTransmittance(float h, float mu) {
    vec3 pos = vec3(0.0, ATMOS_GROUND_R + h, 0.0);
    vec3 dir = vec3(sqrt(max(1.0 - mu * mu, 0.0)), mu, 0.0);

    if (atmosRaySphere(pos, dir, ATMOS_GROUND_R) > 0.0) return vec3(0.0);
    float tMax = atmosRaySphere(pos, dir, ATMOS_TOP_R);
    if (tMax <= 0.0) return vec3(1.0);

    const int STEPS = 40;
    float dt = tMax / float(STEPS);
    vec3 tau = vec3(0.0);
    for (int i = 0; i < STEPS; i++) {
        vec3 p = pos + dir * (dt * (float(i) + 0.5));
        vec3 sR, sE; float sM;
        atmosScatter(length(p) - ATMOS_GROUND_R, sR, sM, sE);
        tau += sE * dt;
    }
    return exp(-tau);
}

#ifdef ATMOS_LUT_READ

uniform sampler2D refraxTransmittanceTex;
uniform sampler2D refraxMultiScatterTex;
uniform sampler2D refraxSkyViewTex;

uniform float refraxEyeY;

vec3 atmosTransmittanceLUT(float h, float mu) {
    return texture(refraxTransmittanceTex, atmosTransmittanceUV(h, mu)).rgb;
}
vec3 atmosMultiScatterLUT(float h, float muSun) {
    return texture(refraxMultiScatterTex, atmosMultiScatterUV(h, muSun)).rgb;
}

vec3 atmosRaymarchSky(vec3 pos, vec3 dir, vec3 sunDir, vec3 sunIllum, vec3 moonIllum, float tMax, int steps) {
    vec3 moonDir = -sunDir;
    float cosSun = dot(dir, sunDir);
    float cosMoon = -cosSun;

    float phaseRSun = atmosRayleighPhase(cosSun);
    float phaseMSun = atmosMiePhase(cosSun);
    float phaseRMoon = atmosRayleighPhase(cosMoon);
    float phaseMMoon = atmosMiePhase(cosMoon);

    float camElev = dot(sunDir, pos / max(length(pos), 1e-6));
    bool doSun = (camElev > -0.35) && (luminance(sunIllum) > 1e-6);
    bool doMoon = (-camElev > -0.35) && (luminance(moonIllum) > 1e-6);

    vec3 lum = vec3(0.0);
    vec3 transmittance = vec3(1.0);
    float t = 0.0;
    for (int i = 0; i < steps; i++) {
        float newT = ((float(i) + 0.3) / float(steps)) * tMax;
        float dt = newT - t;
        t = newT;
        vec3 p = pos + dir * t;

        float len = length(p);
        float h = len - ATMOS_GROUND_R;
        vec3 up = p / len;

        vec3 sR, sE; float sM;
        atmosScatter(h, sR, sM, sE);
        vec3 stepT = exp(-dt * sE);

        vec3 inScatter = vec3(0.0);
        if (doSun) {
            float mu = dot(sunDir, up);
            vec3 T = atmosTransmittanceLUT(h, mu);
            vec3 ms = atmosMultiScatterLUT(h, mu);
            inScatter += ((sR * phaseRSun + vec3(sM * phaseMSun)) * T + (sR + vec3(sM)) * ms) * sunIllum;
        }
        if (doMoon) {
            float mu = dot(moonDir, up);
            vec3 T = atmosTransmittanceLUT(h, mu);
            vec3 ms = atmosMultiScatterLUT(h, mu);
            inScatter += ((sR * phaseRMoon + vec3(sM * phaseMMoon)) * T + (sR + vec3(sM)) * ms) * moonIllum;
        }

        lum += transmittance * (inScatter - inScatter * stepT) / sE;
        transmittance *= stepT;
    }
    return lum;
}

vec2 atmosSkyViewUV(vec3 dir, vec3 sunDir, float h) {
    float altitudeAngle = asin(clamp(dir.y, -1.0, 1.0)) - atmosHorizonDip(h);

    float azimuth = 0.0;
    if (abs(altitudeAngle) < 0.5 * PI - 1e-4) {
        vec3 right = cross(sunDir, vec3(0.0, 1.0, 0.0));
        float rl = length(right);
        right = rl > 1e-4 ? right / rl : vec3(1.0, 0.0, 0.0);
        vec3 forward = cross(vec3(0.0, 1.0, 0.0), right);
        vec3 horiz = dir - vec3(0.0, dir.y, 0.0);
        float hl = length(horiz);
        if (hl > 1e-5) {
            horiz /= hl;
            azimuth = atan(dot(horiz, right), dot(horiz, forward)) + PI;
        }
    }
    float v = 0.5 + 0.5 * sign(altitudeAngle) * sqrt(abs(altitudeAngle) * 2.0 / PI);
    return vec2(azimuth / (2.0 * PI), v);
}

void atmosSkyViewDir(vec2 uv, float sunAltitude, float h, out vec3 dir, out vec3 sunDirLocal) {
    float azimuth = (uv.x - 0.5) * 2.0 * PI;
    float coord = uv.y * 2.0 - 1.0;
    float adjV = sign(coord) * coord * coord;
    float dip = atmosHorizonDip(h);
    float altitudeAngle = max(adjV * 0.5 * PI + dip, -dip + 1e-4);
    float ca = cos(altitudeAngle);
    dir = vec3(ca * sin(azimuth), sin(altitudeAngle), -ca * cos(azimuth));
    sunDirLocal = vec3(0.0, sin(sunAltitude), -cos(sunAltitude));
}

vec3 atmosSkyRadiance(vec3 dir, vec3 sunDir) {
    float h = atmosAltitude(refraxEyeY);
    vec3 c = texture(refraxSkyViewTex, atmosSkyViewUV(normalize(dir), sunDir, h)).rgb;
    return max(c, vec3(0.0)) * (ATMOS_SKY_GAIN * SKY_BRIGHTNESS);
}

vec3 atmosLightTransmittance(float mu) {
    return atmosTransmittanceLUT(atmosAltitude(refraxEyeY), mu);
}

#endif

#endif
