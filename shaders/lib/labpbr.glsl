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
};

const float MATTE_FOLIAGE_F0 = 1.0 / 255.0;
bool isMatteFoliageMaterial(float roughness, float f0) {
    return roughness > 0.995 && abs(f0 - MATTE_FOLIAGE_F0) < (0.75 / 255.0);
}


Material decodeSpecular(vec4 s) {
    Material m;
    float smoothness = s.r;
    m.roughness = (1.0 - smoothness) * (1.0 - smoothness);
    m.f0 = s.g;
    m.emission = s.a * 255.0 < 254.5 ? s.a * (255.0 / 254.0) : 0.0;
    m.sss = s.b > (65.0 / 255.0) ? (s.b - 65.0 / 255.0) / (190.0 / 255.0) : 0.0;
    return m;
}
bool isMetal(float f0) { return f0 * 255.0 > 229.5; }


vec3 decodeNormalTex(vec4 n) {
    vec3 t;
    t.xy = n.rg * 2.0 - 1.0;
    t.z = sqrt(saturate(1.0 - dot(t.xy, t.xy)));
    return t;
}
float decodeTexAO(vec4 n) { return n.b; }


vec2 wrapTile(vec2 uv, vec2 base, vec2 size) {
    return fract((uv - base) / size) * size + base;
}


vec2 pomOffset(sampler2D normalsTex, vec2 uv, vec2 base, vec2 size,
               vec3 viewDirTangent, vec2 dx, vec2 dy, out float surfaceHeight) {
    surfaceHeight = 1.0;
#ifndef POM
    return uv;
#else
    if (viewDirTangent.z <= 0.02) return uv;

    vec4 first = textureGrad(normalsTex, wrapTile(uv, base, size), dx, dy);
    if (first.r + first.g <= 0.0005) return uv;

    float layerDepth = 1.0 / float(POM_SAMPLES);
    vec2 slope = viewDirTangent.xy / viewDirTangent.z;
    slope /= max(1.0, length(slope) * 0.25);
    vec2 shift = -slope * POM_DEPTH * size;
    vec2 delta = shift * layerDepth;
    float rayHeight = 1.0;
    float texHeight = first.a;
    for (int i = 0; i < POM_SAMPLES && rayHeight > texHeight; i++) {
        uv += delta;
        rayHeight -= layerDepth;
        texHeight = textureGrad(normalsTex, wrapTile(uv, base, size), dx, dy).a;
    }
    surfaceHeight = rayHeight;
    return uv;
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
