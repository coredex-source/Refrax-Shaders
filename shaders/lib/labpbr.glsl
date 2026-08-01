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
    float anisotropy;
    float clearcoat;
    float thinFilm;
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
    m.anisotropy = 0.0;
    m.clearcoat = 0.0;
    m.thinFilm = 0.0;
    return m;
}

void applyFallbackMaterial(int id, inout Material m) {
    if (m.roughness <= 0.85) return;
    if (id == 10040) {
        m.roughness = 0.28;
        m.f0 = 0.045;
        m.clearcoat = 0.12;
    } else if (id == 10041) {
        m.roughness = 0.12;
        m.f0 = 0.055;
        m.clearcoat = 0.65;
    } else if (id == 10042 || id == 10060) {
        m.roughness = 0.22;
        m.f0 = 1.0;
        m.anisotropy = 0.35;
    } else if (id == 10043) {
        m.roughness = 0.15;
        m.f0 = 0.060;
        m.clearcoat = 0.55;
        m.thinFilm = 0.65;
    } else if (id == 10044) {
        m.roughness = 0.68;
        m.f0 = 0.035;
        m.porosity = 0.55;
    } else if (id == 10045) {
        m.roughness = 0.95;
        m.f0 = 0.025;
        m.porosity = 0.90;
    } else if (id == 10046) {
        m.roughness = 0.82;
        m.f0 = 0.040;
        m.porosity = 0.72;
    } else if (id == 10047) {
        m.roughness = 0.78;
        m.f0 = 0.040;
        m.porosity = 0.65;
    } else if (id == 10048) {
        m.roughness = 0.20;
        m.f0 = 0.045;
        m.clearcoat = 0.70;
    } else if (id == 10049) {
        m.roughness = 0.16;
        m.f0 = 1.0;
        m.anisotropy = 0.24;
    } else if (id == 10086) {
        m.roughness = 0.24;
        m.f0 = 1.0;
        m.anisotropy = 0.30;
    } else if (id == 10087) {
        m.roughness = 0.34;
        m.f0 = 1.0;
        m.anisotropy = 0.22;
    } else if (id == 10088) {
        m.roughness = 0.48;
        m.f0 = 1.0;
        m.anisotropy = 0.12;
    } else if (id == 10089) {
        m.roughness = 0.70;
        m.f0 = 0.055;
        m.porosity = 0.30;
    } else if (id == 10090) {
        m.roughness = 0.24;
        m.f0 = 0.055;
        m.clearcoat = 0.40;
        m.thinFilm = 0.85;
    } else if (id == 10091 || (id >= 10070 && id <= 10085)) {
        m.roughness = 0.08;
        m.f0 = 0.040;
        m.clearcoat = 0.80;
    }
}

float inferredEmission(vec3 albedo, float blockLight) {
#ifndef EMISSIVE_INFERENCE
    return 0.0;
#else
    float hi = max(albedo.r, max(albedo.g, albedo.b));
    float lo = min(albedo.r, min(albedo.g, albedo.b));
    float saturation = (hi - lo) / max(hi, 1e-4);
    float bright = smoothstep(0.58, 0.92, luminance(albedo));
    float chroma = smoothstep(0.22, 0.62, saturation);
    float lit = smoothstep(0.72, 0.98, blockLight);
    return bright * chroma * lit * EMISSIVE_INFERENCE_STRENGTH;
#endif
}

float packCoating(float clearcoat, float thinFilm) {
    float coat = floor(saturate(clearcoat) * 15.0 + 0.5);
    float film = floor(saturate(thinFilm) * 15.0 + 0.5);
    return (coat + film * 16.0) / 255.0;
}

vec2 unpackCoating(float encoded) {
    float value = floor(saturate(encoded) * 255.0 + 0.5);
    return vec2(mod(value, 16.0), floor(value / 16.0)) / 15.0;
}

vec3 decodeNormalTex(vec4 n) {
    vec3 t;
    t.xy = n.rg * 2.0 - 1.0;
    float lengthSquared = dot(t.xy, t.xy);
    if (lengthSquared > 1.0) t.xy *= inversesqrt(lengthSquared);
    t.z = sqrt(max(1.0 - dot(t.xy, t.xy), 0.0));
    return t;
}

float normalDetailWeight(vec2 normalXY, vec2 dx, vec2 dy, vec2 texturePixels) {
#ifndef PBR_NORMAL_FILTERING
    return 1.0;
#else
    float footprint = max(length(dx * texturePixels), length(dy * texturePixels));
    float variation = max(length(dFdx(normalXY)), length(dFdy(normalXY)));
    float level = max(log2(max(footprint, 1.0)), 0.0);
    float mipWeight = exp2(-level * PBR_NORMAL_FILTER_STRENGTH);
    float signalWeight = 1.0 / (1.0 + variation * PBR_NORMAL_FILTER_STRENGTH * 2.0);
    float minification = saturate(footprint - 1.0);
    return mix(1.0, mipWeight * signalWeight, minification);
#endif
}

vec3 filteredNormalTex(vec4 n, vec2 dx, vec2 dy, vec2 texturePixels) {
    vec3 t = decodeNormalTex(n);
    t.xy *= normalDetailWeight(t.xy, dx, dy, texturePixels);
    t.z = sqrt(max(1.0 - dot(t.xy, t.xy), 0.0));
    return t;
}

float materialSpecularRoughness(float roughness, vec3 N) {
#ifndef PBR_SPECULAR_AA
    return roughness;
#else
    vec3 nx = dFdx(N);
    vec3 ny = dFdy(N);
    float variance = min(max(dot(nx, nx), dot(ny, ny)) * PBR_SPECULAR_AA_STRENGTH, 0.12);
    return sqrt(saturate(roughness * roughness + variance));
#endif
}

vec3 materialLobeNormal(vec3 geometricNormal, vec3 detailNormal, float roughness, float clearcoat) {
    float smoothness = saturate(1.0 - sqrt(saturate(roughness)));
    float detailWeight = smoothstep(0.04, 0.84, smoothness);
#ifdef CLEARCOAT_MATERIALS
    detailWeight = max(detailWeight, saturate(clearcoat * CLEARCOAT_STRENGTH) * 0.75);
#endif
    return normalize(mix(geometricNormal, detailNormal, mix(0.08, 1.0, detailWeight)));
}

vec3 compressMaterialHighlight(vec3 highlight) {
    float peak = max(highlight.r, max(highlight.g, highlight.b));
    return highlight / (1.0 + peak * PBR_HIGHLIGHT_COMPRESSION);
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

vec3 subsurfaceTransmission(vec3 albedo, vec3 N, vec3 viewRayW, vec3 lightDir, float sss) {
#ifndef SUBSURFACE_SCATTERING
    return vec3(0.0);
#else
    if (sss <= 0.0) return vec3(0.0);
    float NoL = dot(N, lightDir);
    float wrapped = saturate((NoL + sss) / (1.0 + sss));
    float extra = max(wrapped - saturate(NoL), 0.0);
    float forward = pow(saturate(dot(viewRayW, lightDir)), 6.0) * 0.75 + 0.20;
    return albedo * sqrt(albedo) * (extra * forward * sss * SSS_STRENGTH);
#endif
}

struct WetModulation {
    float darken;
    float smoothen;
    float puddle;
};

WetModulation porosityResponse(float porosity) {
    float p = saturate(porosity) * POROSITY_WETNESS;
    WetModulation w;
    w.darken = mix(0.80, 1.40, p);
    w.smoothen = 1.0 - p * 0.70;
    w.puddle = 1.0 - p * 0.50;
    return w;
}

vec2 wrapTile(vec2 uv, vec2 base, vec2 size) {
    return fract((uv - base) / size) * size + base;
}

const float POM_MAX_RAY = 1.5;

vec2 pomOffset(sampler2D normalsTex, vec2 uv, vec2 base, vec2 size,
               vec3 viewDirTangent, vec2 dx, vec2 dy, float distanceFade,
               out float surfaceHeight, out vec3 slopeNormalT, out float slopeWeight) {
    surfaceHeight = 1.0;
    slopeNormalT = vec3(0.0, 0.0, 1.0);
    slopeWeight = 0.0;
#ifndef POM
    return uv;
#else
    float viewZ = viewDirTangent.z;
    if (viewZ <= 0.02) return uv;

    vec4 first = textureGrad(normalsTex, wrapTile(uv, base, size), dx, dy);
    if (first.r + first.g <= 0.0005 || first.a >= (254.0 / 255.0)) return uv;
    if (distanceFade >= 0.999) return uv;

    vec2 fullRay = -viewDirTangent.xy / viewZ * (POM_DEPTH * (1.0 - distanceFade));
    float fullLength = length(fullRay);
    float depthRange = fullLength > POM_MAX_RAY ? POM_MAX_RAY / fullLength : 1.0;
    vec2 rayOffset = fullRay * depthRange;

    vec2 atlasPixels = vec2(textureSize(normalsTex, 0));
    float footprint = max(max(length(dx * atlasPixels), length(dy * atlasPixels)), 1.0);
    float rayTexels = length(rayOffset * size * atlasPixels);
    const int maxLayers = POM_SAMPLES * 3;
    int layerCount = clamp(int(ceil(rayTexels * 3.0 / footprint)), POM_SAMPLES, maxLayers);
    float layerStep = depthRange / float(layerCount);
    vec2 uvStep = rayOffset / float(layerCount);
    vec2 localUV = (uv - base) / size;
    vec2 previousUV = localUV;
    float previousRayDepth = 0.0;
    float previousMapDepth = 1.0 - first.a;

    vec2 currentUV = previousUV;
    float currentRayDepth = previousRayDepth;
    float currentMapDepth = previousMapDepth;
    bool hitSurface = false;

    for (int i = 0; i < maxLayers; i++) {
        if (i >= layerCount) break;
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

    float wallGap = currentRayDepth - currentMapDepth;

    if (!hitSurface) {
        surfaceHeight = 1.0 - currentRayDepth;
        return base + fract(currentUV) * size;
    }

    for (int i = 0; i < 8; i++) {
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

    if (wallGap > max(layerStep * 2.0, 0.05)) {
        slopeNormalT = vec3(0.0, 0.0, 1.0);
        slopeWeight = 0.6 * saturate(1.0 - distanceFade * 2.0);
    }
    return base + fract(hitUV) * size;
#endif
}

float pomDirectShadow(sampler2D normalsTex, vec2 uv, vec2 base, vec2 size,
                      vec3 lightDirTangent, vec2 dx, vec2 dy,
                      float surfaceHeight, float distanceFade) {
#ifndef POM
    return 1.0;
#else
#ifndef POM_SELF_SHADOWS
    return 1.0;
#else
    float lightZ = lightDirTangent.z;
    if (lightZ <= 0.0 || surfaceHeight >= 0.995 || distanceFade >= 0.999) return 1.0;
    vec2 lateral = lightDirTangent.xy * (POM_DEPTH * 4.0);
    vec2 localUV = (uv - base) / size;
    float shadow = 1.0;
    for (int i = 0; i < POM_SHADOW_SAMPLES; i++) {
        if (shadow < 0.01) break;
        float t = 0.1 * (float(i) + 0.5) / float(POM_SHADOW_SAMPLES);
        float mapHeight = textureGrad(normalsTex, wrapTile(base + (localUV + lateral * t) * size, base, size), dx, dy).a;
        float rayHeight = surfaceHeight + lightZ * t;
        shadow *= saturate(1.0 - (mapHeight - rayHeight) * 4.0);
    }
    float visibility = mix(1.0, shadow, POM_SHADOW_STRENGTH);
    return mix(1.0, visibility, 1.0 - distanceFade);
#endif
#endif
}

vec3 materialTangent(vec3 N) {
    vec3 axis = abs(N.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    return normalize(cross(axis, N));
}

vec3 thinFilmFresnel(float cosTheta, vec3 baseF, float strength) {
#ifndef THIN_FILM
    return baseF;
#else
    if (strength <= 0.0) return baseF;
    float c = saturate(cosTheta);
    float thickness = mix(180.0, 620.0, strength);
    float opticalPath = 2.0 * 1.46 * thickness * sqrt(max(1.0 - (1.0 - c * c) / (1.46 * 1.46), 0.0));
    vec3 phase = 2.0 * PI * opticalPath / vec3(650.0, 510.0, 475.0);
    vec3 fringe = 0.5 + 0.5 * cos(phase);
    float visibility = strength * mix(0.35, 1.0, pow(1.0 - c, 2.0));
    return saturate(baseF + (fringe - 0.5) * (1.0 - baseF) * (0.32 * visibility));
#endif
}

vec3 anisotropicDiscLightSpecular(vec3 N, vec3 V, vec3 L, float sinRadius,
                                  float roughness, vec3 f0, float anisotropy,
                                  float thinFilm) {
    vec3 R = reflect(-V, N);
    vec3 toRay = R * dot(L, R) - L;
    vec3 Lr = normalize(L + toRay * saturate(sinRadius / max(length(toRay), 1e-5)));
    vec3 H = normalize(V + Lr);
    float NoH = saturate(dot(N, H));
    float NoV = max(dot(N, V), 1e-4);
    float NoL = saturate(dot(N, Lr));
    float a = max(roughness * roughness, 2e-3);
    float ap = min(a + 0.5 * sinRadius, 1.0);
    float norm = a / ap;
    norm *= norm;
    float aspect = sqrt(max(1.0 - 0.90 * anisotropy, 0.10));
    float ax = max(ap / aspect, 2e-3);
    float ay = max(ap * aspect, 2e-3);
    vec3 T = materialTangent(N);
    vec3 B = cross(N, T);
    float ToH = dot(T, H);
    float BoH = dot(B, H);
    float d = ToH * ToH / (ax * ax) + BoH * BoH / (ay * ay) + NoH * NoH;
    float D = norm / (PI * ax * ay * d * d);
    float ToV = dot(T, V);
    float BoV = dot(B, V);
    float ToL = dot(T, Lr);
    float BoL = dot(B, Lr);
    float lambdaV = NoL * length(vec3(ax * ToV, ay * BoV, NoV));
    float lambdaL = NoV * length(vec3(ax * ToL, ay * BoL, NoL));
    float G = 0.5 / max(lambdaV + lambdaL, 1e-5);
    vec3 F = fresnelSchlick(dot(V, H), f0);
    F = thinFilmFresnel(dot(V, H), F, thinFilm);
    return min(D * G * NoL, 32.0) * F;
}

vec3 materialDiscLightSpecular(vec3 N, vec3 V, vec3 L, float sinRadius,
                               float roughness, vec3 f0, float anisotropy,
                               float clearcoat, float thinFilm) {
    float aniso = 0.0;
#ifdef ANISOTROPIC_MATERIALS
    aniso = saturate(anisotropy * ANISOTROPY_STRENGTH);
#endif
    float film = 0.0;
#ifdef THIN_FILM
    film = saturate(thinFilm * THIN_FILM_STRENGTH);
#endif
    vec3 base = aniso > 0.001 || film > 0.001
        ? anisotropicDiscLightSpecular(N, V, L, sinRadius, roughness, f0, aniso, film)
        : discLightSpecular(N, V, L, sinRadius, roughness, f0);
#ifdef CLEARCOAT_MATERIALS
    float coat = saturate(clearcoat * CLEARCOAT_STRENGTH);
    if (coat > 0.001) {
        vec3 coatF0 = thinFilmFresnel(dot(N, V), vec3(0.04), film);
        vec3 coatSpec = discLightSpecular(N, V, L, sinRadius, 0.06, coatF0);
        base = base * (1.0 - coat * 0.25) + coatSpec * (coat * 0.25);
    }
#endif
    return base;
}

vec3 materialReflectionFresnel(float cosTheta, float f0, vec3 albedo,
                               float clearcoat, float thinFilm) {
    float film = 0.0;
#ifdef THIN_FILM
    film = saturate(thinFilm * THIN_FILM_STRENGTH);
#endif
    vec3 base = thinFilmFresnel(cosTheta, materialFresnel(cosTheta, f0, albedo), film);
#ifdef CLEARCOAT_MATERIALS
    float coat = saturate(clearcoat * CLEARCOAT_STRENGTH);
    vec3 coatF = thinFilmFresnel(cosTheta, fresnelSchlick(cosTheta, vec3(0.04)), film);
    base = base * (1.0 - coatF * coat) + coatF * coat;
#endif
    return base;
}

float materialReflectionRoughness(float roughness, float clearcoat) {
#ifdef CLEARCOAT_MATERIALS
    return mix(roughness, 0.06, saturate(clearcoat * CLEARCOAT_STRENGTH));
#else
    return roughness;
#endif
}

#endif
