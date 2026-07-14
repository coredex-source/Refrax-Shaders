/* Refrax — lib/labpbr.glsl */
#ifndef REFRAX_LABPBR
#define REFRAX_LABPBR

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

struct Material {
    float roughness;
    float f0;
    float emission;
    float sss;
    float porosity;
};

const float MATTE_FOLIAGE_F0 = 1.0 / 255.0;
const float LABPBR_METAL_START = 229.5 / 255.0;
const float LABPBR_ALBEDO_METAL_START = 237.5 / 255.0;

bool isMatteFoliageMaterial(float roughness, float f0) {
    return roughness > 0.995 && abs(f0 - MATTE_FOLIAGE_F0) < (0.75 / 255.0);
}

bool isHardcodedMetal(float f0) {
    return f0 >= LABPBR_METAL_START && f0 < LABPBR_ALBEDO_METAL_START;
}

bool isAlbedoMetal(float f0) {
    return f0 >= LABPBR_ALBEDO_METAL_START;
}

bool isMetal(float f0) {
    return f0 >= LABPBR_METAL_START;
}

vec3 hardcodedMetalF0(float f0) {
    float id = floor(f0 * 255.0 + 0.5) - 230.0;
    if (id < 0.5) return vec3(0.78, 0.77, 0.74);
    if (id < 1.5) return vec3(1.00, 0.90, 0.61);
    if (id < 2.5) return vec3(1.00, 0.98, 1.00);
    if (id < 3.5) return vec3(0.77, 0.80, 0.79);
    if (id < 4.5) return vec3(1.00, 0.89, 0.73);
    if (id < 5.5) return vec3(0.79, 0.87, 0.85);
    if (id < 6.5) return vec3(0.92, 0.90, 0.83);
    return vec3(1.00, 1.00, 0.91);
}

vec3 hardcodedMetalF82(float f0) {
    float id = floor(f0 * 255.0 + 0.5) - 230.0;
    if (id < 0.5) return vec3(0.74, 0.76, 0.76);
    if (id < 1.5) return vec3(1.00, 0.93, 0.73);
    if (id < 2.5) return vec3(0.96, 0.97, 0.98);
    if (id < 3.5) return vec3(0.74, 0.79, 0.78);
    if (id < 4.5) return vec3(1.00, 0.90, 0.80);
    if (id < 5.5) return vec3(0.83, 0.80, 0.83);
    if (id < 6.5) return vec3(0.89, 0.90, 0.83);
    return vec3(1.00, 1.00, 0.95);
}

vec3 materialF0(float f0, vec3 albedo) {
    if (isHardcodedMetal(f0)) return hardcodedMetalF0(f0);
    if (isAlbedoMetal(f0)) return max(albedo, vec3(0.0));
    return vec3(max(f0, 0.02));
}

vec3 fresnelLazanyi(float cosTheta, vec3 f0, vec3 f82) {
    float c = saturate(cosTheta);
    float m = pow(1.0 - c, 5.0);
    vec3 a = 17.6513846 * (f0 - f82) + 8.16666667 * (1.0 - f0);
    return saturate(f0 + (1.0 - f0) * m - a * c * (m - m * c));
}

vec3 materialFresnel(float cosTheta, float f0, vec3 albedo) {
    vec3 baseF0 = materialF0(f0, albedo);
    return isHardcodedMetal(f0)
        ? max(fresnelLazanyi(cosTheta, baseF0, hardcodedMetalF82(f0)), vec3(0.0))
        : fresnelSchlick(cosTheta, baseF0);
}

Material decodeSpecular(vec4 s) {
    Material m;
    float smoothness = s.r;
    m.roughness = (1.0 - smoothness) * (1.0 - smoothness);
    m.f0 = s.g;
    m.emission = s.a * 255.0 < 254.5 ? s.a * (255.0 / 254.0) : 0.0;
    m.sss = s.b > (65.0 / 255.0) ? (s.b - 65.0 / 255.0) / (190.0 / 255.0) : 0.0;
    m.porosity = s.b < (65.0 / 255.0) ? s.b * (255.0 / 64.0) : 0.0;
    return m;
}

vec3 decodeNormalTex(vec4 n) {
    vec3 t;
    t.xy = n.rg * 2.0 - 1.0;
    t.z = sqrt(saturate(1.0 - dot(t.xy, t.xy)));
    return t;
}
float decodeTexAO(vec4 n) { return n.b; }

mat3 makeTBN(vec3 normal, vec3 tangent, float tangentSign) {
    vec3 N = normalize(normal);
    vec3 T = tangent - N * dot(N, tangent);
    float t2 = dot(T, T);
    if (t2 < 1e-6) {
        vec3 axis = abs(N.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
        T = normalize(cross(axis, N));
    } else {
        T *= inversesqrt(t2);
    }
    vec3 B = normalize(cross(T, N)) * (tangentSign < 0.0 ? -1.0 : 1.0);
    return mat3(T, B, N);
}


vec2 wrapTile(vec2 uv, vec2 base, vec2 size) {
    return fract((uv - base) / size) * size + base;
}


vec2 pomOffset(sampler2D normalsTex, vec2 uv, vec2 base, vec2 size,
               vec3 viewDirTangent, vec2 dx, vec2 dy, out float surfaceHeight) {
    surfaceHeight = 1.0;
#ifndef POM
    return uv;
#else
    float viewZ = viewDirTangent.z;
    if (viewZ <= 0.02) return uv;

    vec4 first = textureGrad(normalsTex, wrapTile(uv, base, size), dx, dy);
    if (first.r + first.g <= 0.0005 || first.a >= (254.0 / 255.0)) return uv;

    float grazingFade = smoothstep(0.035, 0.16, viewZ);
    if (grazingFade <= 0.0) return uv;

    vec2 localUV = (uv - base) / size;
    vec2 rayOffset = -viewDirTangent.xy / viewZ * (POM_DEPTH * grazingFade);
    float offsetLength = length(rayOffset);
    if (offsetLength > 0.85) rayOffset *= 0.85 / offsetLength;

    float layerStep = 1.0 / float(POM_SAMPLES);
    vec2 uvStep = rayOffset * layerStep;
    vec2 previousUV = localUV;
    float previousRayDepth = 0.0;
    float previousMapDepth = 1.0 - first.a;

    vec2 currentUV = previousUV;
    float currentRayDepth = previousRayDepth;
    float currentMapDepth = previousMapDepth;
    bool hitSurface = false;

    for (int i = 0; i < POM_SAMPLES; i++) {
        currentUV += uvStep;
        currentRayDepth += layerStep;
        float height = textureGrad(normalsTex, wrapTile(base + currentUV * size, base, size), dx, dy).a;
        currentMapDepth = 1.0 - height;

        if (currentRayDepth >= currentMapDepth) {
            hitSurface = true;
            break;
        }

        previousUV = currentUV;
        previousRayDepth = currentRayDepth;
        previousMapDepth = currentMapDepth;
    }

    if (!hitSurface) return uv;

    for (int i = 0; i < 2; i++) {
        vec2 midUV = (previousUV + currentUV) * 0.5;
        float midRayDepth = (previousRayDepth + currentRayDepth) * 0.5;
        float midHeight = textureGrad(normalsTex, wrapTile(base + midUV * size, base, size), dx, dy).a;
        float midMapDepth = 1.0 - midHeight;
        if (midRayDepth < midMapDepth) {
            previousUV = midUV;
            previousRayDepth = midRayDepth;
            previousMapDepth = midMapDepth;
        } else {
            currentUV = midUV;
            currentRayDepth = midRayDepth;
            currentMapDepth = midMapDepth;
        }
    }

    float before = max(previousMapDepth - previousRayDepth, 0.0);
    float after = max(currentRayDepth - currentMapDepth, 0.0);
    float intersection = before / max(before + after, 1e-5);
    vec2 hitUV = mix(previousUV, currentUV, intersection);
    surfaceHeight = 1.0 - mix(previousRayDepth, currentRayDepth, intersection);
    return base + fract(hitUV) * size;
#endif
}

float pomDirectShadow(float surfaceHeight, float fade) {
#ifndef POM
    return 1.0;
#else
    float recess = saturate(1.0 - surfaceHeight);
    float shade = 1.0 - recess * (0.28 + 0.22 * recess);
    return mix(shade, 1.0, fade);
#endif
}

#endif
