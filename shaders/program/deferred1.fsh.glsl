/* Refrax — program/deferred1.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/blockid.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/shadows.glsl"
#include "/lib/dh.glsl"
#include "/lib/voxel.glsl"
#include "/lib/labpbr.glsl"
#include "/lib/ssr.glsl"
#include "/lib/wetness.glsl"

uniform sampler2D depthtex0;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
#ifdef VOXY
uniform sampler2D colortex8;
#endif
uniform sampler2D shadowtex0, shadowtex1, shadowcolor0;
#ifdef COLORED_LIGHTING
uniform sampler3D lpvSampler1;
#endif
uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;
uniform mat4 shadowModelView, shadowProjection;
uniform vec3 cameraPosition, previousCameraPosition;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec3 fogColor;
uniform float frameTimeCounter, rainStrength, viewWidth, viewHeight;
uniform float wetness;
uniform float nightVision;
uniform int frameCounter, isEyeInWater;
uniform int heldBlockLightValue, heldBlockLightValue2;
uniform int heldItemId, heldItemId2;
#ifdef IS_IRIS
uniform vec3 relativeEyePosition;
#endif
uniform float refraxWetBiome;

in vec2 uv;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

#if MC_VERSION < 260100
uniform sampler2D colortex7;
vec4 lineOverlay(vec4 color) {
    vec4 line = texture(colortex7, uv);
    return vec4(color.rgb * (1.0 - line.a) + line.rgb, color.a);
}
#else
#define lineOverlay(c) (c)
#endif

vec3 blockLightAt(vec3 pos, vec3 N, float lmBlock) {
    vec3 fallback = FALLBACK_BLOCKLIGHT * pow(lmBlock, 3.0) * 1.85;
#ifdef WORLD_NETHER
    fallback *= NETHER_FALLBACK_SCALE;
#endif
#ifdef COLORED_LIGHTING
    float fade;
    vec3 lpv = sampleLPV(lpvSampler1, pos, cameraPosition, N, fade);
  #ifdef WORLD_NETHER
    lpv *= NETHER_LPV_SCALE;
  #endif
    float vanillaContribution = exp2(-4.0 * luminance(lpv));
    vec3 colored = lpv + fallback * vanillaContribution * 0.35;
    vec3 light = mix(fallback, max(colored, fallback * 0.25), fade);
#else
    vec3 light = fallback;
#endif
#ifdef HAND_LIGHT
  #ifdef IS_IRIS
    light += heldLightAt(pos + relativeEyePosition, heldItemId, heldBlockLightValue, heldItemId2, heldBlockLightValue2);
  #else
    light += heldLightAt(pos, heldItemId, heldBlockLightValue, heldItemId2, heldBlockLightValue2);
  #endif
#endif
    return light;
}

void main() {
    vec2 viewTexel = 1.0 / vec2(viewWidth, viewHeight);
    vec4 prev = texture(colortex0, uv);
    if (prev.a > 0.15 && prev.a < 0.85) { outColor = lineOverlay(prev); return; }

    float depth = texture(depthtex0, uv).r;
    vec3 viewPos = screenToView(vec3(uv, depth), gbufferProjectionInverse);
    bool lodPixel = false;
#ifdef LOD_ACTIVE
    if (depth >= 1.0) {
        float lodDepth = texture(lodDepthTex1, uv).r;
        if (lodDepth < 1.0) {
            lodPixel = true;
            viewPos = screenToView(vec3(uv, lodDepth), lodProjectionInverse);
        }
    }
#endif
    vec3 scenePos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 dirW = normalize(scenePos);
    vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

    if (depth >= 1.0 && !lodPixel) {
        vec3 sky = dimensionSky(dirW, sunDir, fogColor, frameTimeCounter, rainStrength);
        vec4 clouds = texture(colortex4, fsrRegionUV(uv, viewTexel));
        sky = sky * clouds.a + clouds.rgb;
#ifdef VOXY
        vec4 lodLayer = texture(colortex8, uv);
        sky = sky * (1.0 - lodLayer.a) + lodLayer.rgb;
#endif
        outColor = lineOverlay(vec4(sky, 1.0));
        return;
    }

    vec4 c1 = texture(colortex1, uv);
    vec3 albedo = srgbToLinear(c1.rgb);
    float pomShadow = c1.a;
    vec4 c2 = texture(colortex2, uv);
    vec3 N = normalize(c2.rgb);
    float emission = c2.a;
    vec4 c3 = texture(colortex3, uv);
    vec2 lm = c3.xy;
    float roughness = c3.z;
    float f0raw = c3.w;
    float ao = texture(colortex6, fsrRegionUV(uv, viewTexel)).r;
    float dither = ignAnim(gl_FragCoord.xy, frameCounter);

#if defined RAIN_PUDDLES && !defined WORLD_NETHER && !defined WORLD_END
    vec3 puddleN = N;
    float puddleCover = 0.0;
    {
        vec3 geomNV = cross(dFdx(viewPos), dFdy(viewPos));
        geomNV = normalize(dot(geomNV, viewPos) > 0.0 ? -geomNV : geomNV);
        vec3 geomNW = normalize(mat3(gbufferModelViewInverse) * geomNV);
        if (wetness * refraxWetBiome > 0.001 && !isMetal(f0raw) && !isMatteFoliageMaterial(roughness, f0raw)) {
            vec3 worldPos = scenePos + cameraPosition;
            WetResult wr = computeWetness(worldPos, geomNW.y, lm.y, wetness, refraxWetBiome);
            float notEmit = 1.0 - saturate(emission);
            albedo *= mix(1.0, WETNESS_DARKEN, max(wr.wet * 0.85, wr.puddle) * notEmit);
            roughness = mix(roughness, roughness * 0.55, wr.wet * 0.6 * notEmit);
            puddleCover = wr.puddle * notEmit;
            if (puddleCover > 0.001) {
                vec3 flatPuddleN = normalize(mix(geomNW, vec3(0.0, 1.0, 0.0), 0.9));
                vec3 rippleN = puddleNormal(worldPos.xz, geomNW, frameTimeCounter, rainStrength);
                float rippleBlend = puddleCover * smoothstep(0.10, 0.85, rainStrength) * 0.42;
                puddleN = normalize(mix(flatPuddleN, rippleN, rippleBlend));
            }
        }
    }
#endif

#ifdef DEBUG_LPV
  #ifdef COLORED_LIGHTING
    { float dfade; outColor = vec4(sampleLPV(lpvSampler1, scenePos, cameraPosition, N, dfade), 1.0); return; }
  #endif
#endif

    float NoL = saturate(dot(N, lightDir));
    vec3 lightCol;
    vec3 shadow;

#if defined WORLD_NETHER
    lightCol = vec3(0.0);
    shadow = vec3(0.0);
    float facing = netherFacing(N);
    vec3 skyLight = netherAmbient(N, fogColor) * facing;
  #ifdef COLORED_LIGHTING
    skyLight += vec3(texture(shadowtex1, vec2(0.5)).r * 1e-8);
  #endif
#elif defined WORLD_END
    lightCol = endLightColor();
    shadow = getShadow(scenePos, N, NoL, dither, shadowModelView, shadowProjection, shadowtex0, shadowtex1, shadowcolor0);
    vec3 skyLight = endAmbient(N);
#else
    lightCol = (sunColor(sunDir.y) + moonColor(-sunDir.y)) * (1.0 - rainStrength * 0.9);
    shadow = getShadow(scenePos, N, NoL, dither, shadowModelView, shadowProjection, shadowtex0, shadowtex1, shadowcolor0);
    vec3 skyLight = skyAmbientDirectional(N, sunDir, rainStrength) * pow(lm.y, 2.2);
    skyLight += lightCol * 0.05 * saturate(0.6 - 0.4 * N.y) * pow(lm.y, 2.2);
#endif
    vec3 blockLight = blockLightAt(scenePos, N, lm.x);
#ifdef WORLD_NETHER
    blockLight *= facing;
#endif
    vec3 minAmb = vec3(0.010, 0.011, 0.014) * MIN_AMBIENT * (1.0 + nightVision * 6.0);

    vec3 directShadow = shadow * pomShadow;
    vec3 diffuse = lightCol * NoL * directShadow + (skyLight + minAmb) * ao + blockLight * mix(ao, 1.0, 0.5);

#if defined PBR_MATERIALS || REFLECTION_MODE > 0
    bool matteFoliage = isMatteFoliageMaterial(roughness, f0raw);
    bool metal = !matteFoliage && isMetal(f0raw);
    if (metal) diffuse *= 0.2;
#endif

    vec3 color = albedo * diffuse;
    color += albedo * sqrt(albedo) * (emission * EMISSION_STRENGTH * EMISSION_SCALE);

#if defined PBR_MATERIALS || REFLECTION_MODE > 0
    vec3 V = -dirW;
    float smoothness = saturate(1.0 - sqrt(saturate(roughness)));
    vec3 f0 = matteFoliage ? vec3(0.0) : (metal ? albedo : vec3(clamp(f0raw, 0.025, 0.08)));
    float directSpecWeight = metal ? 1.0 : smoothstep(0.35, 0.80, smoothness) * 0.6;
    if (!matteFoliage && directSpecWeight > 0.0)
        color += discLightSpecular(N, V, lightDir, SUN_GLINT_RADIUS, roughness, f0) * lightCol * directShadow * directSpecWeight * PBR_GLINT_STRENGTH;

  #if REFLECTION_MODE > 0
    bool envReflect = !matteFoliage && metal;
    bool ssrReflect = metal;
    if (envReflect) {
        vec3 reflDirW = reflect(dirW, N);
    #if defined WORLD_NETHER || defined WORLD_END
        float skyVis = 1.0;
    #else
        float skyVis = pow(lm.y, 2.0);
    #endif
        vec3 refl = dimensionSky(reflDirW, sunDir, fogColor, frameTimeCounter, rainStrength) * skyVis;
        if (ssrReflect) {
            vec3 reflDirV = mat3(gbufferModelView) * reflDirW;
            vec3 hit;
            float hitS = raymarchSSR(depthtex0, viewPos, reflDirV, gbufferProjection, gbufferProjectionInverse, dither, hit);
            if (hitS > 0.0) {
                vec3 hitView = screenToView(hit, gbufferProjectionInverse);
                vec3 hitScene = (gbufferModelViewInverse * vec4(hitView, 1.0)).xyz;
                vec3 prevUV = reprojectScene(hitScene, gbufferPreviousModelView, gbufferPreviousProjection, cameraPosition, previousCameraPosition);
                if (clamp(prevUV.xy, 0.0, 1.0) == prevUV.xy) {
                    vec4 hist = texture(colortex5, historyUV(prevUV.xy, viewTexel));
                    refl = mix(refl, hist.rgb, hitS * saturate(hist.a));
                }
            }
        }
        float NoV = saturate(dot(V, N));
        vec3 F = f0 + (max(vec3(1.0 - roughness), f0) - f0) * pow(1.0 - NoV, 5.0);
        float reflWeight = metal ? 1.0 - 0.75 * saturate(roughness) : pow(smoothness, 5.0) * 0.04;
        color += refl * F * reflWeight;
    }
  #endif
#endif

#if defined RAIN_PUDDLES && !defined WORLD_NETHER && !defined WORLD_END
    if (puddleCover > 0.001) {
        vec3 Vw = -dirW;
        float NoV = saturate(dot(puddleN, Vw));
        float fres = 0.02 + 0.98 * pow(1.0 - NoV, 5.0);
        vec3 reflDir = reflect(dirW, puddleN);
        float skyVis = pow(lm.y, 2.0);

  #if RAIN_PUDDLE_REFLECTIONS == 0
        vec3 env = skyAmbient(sunDir, rainStrength) * (0.7 + 0.6 * skyVis);
  #else
        vec3 env = dimensionSky(reflDir, sunDir, fogColor, frameTimeCounter, rainStrength) * skyVis;
    #if RAIN_PUDDLE_REFLECTIONS == 2
        {
            vec3 reflDirV = mat3(gbufferModelView) * reflDir;
            vec3 hit;
            float hitS = raymarchSSR(depthtex0, viewPos, reflDirV, gbufferProjection, gbufferProjectionInverse, dither, hit);
            if (hitS > 0.0) {
                vec3 hitView = screenToView(hit, gbufferProjectionInverse);
                vec3 hitScene = (gbufferModelViewInverse * vec4(hitView, 1.0)).xyz;
                vec3 prevUV = reprojectScene(hitScene, gbufferPreviousModelView, gbufferPreviousProjection, cameraPosition, previousCameraPosition);
                if (clamp(prevUV.xy, 0.0, 1.0) == prevUV.xy) {
                    vec4 hist = texture(colortex5, historyUV(prevUV.xy, viewTexel));
                    env = mix(env, hist.rgb, hitS * saturate(hist.a));
                }
            }
        }
    #endif
  #endif
        vec3 glint = discLightSpecular(puddleN, Vw, lightDir, SUN_GLINT_RADIUS, 0.015, vec3(0.02))
                   * lightCol * directShadow * (SUN_GLINT_STRENGTH * 0.6);

        float reflMix = puddleCover * fres;
        color = mix(color, env, reflMix) + glint * puddleCover;
    }
#endif

#ifdef LOD_ACTIVE
    if (lodPixel) {
        vec4 clouds = texture(colortex4, fsrRegionUV(uv, viewTexel));
        color = color * clouds.a + clouds.rgb;
    }
#endif

#ifdef VOXY
    {
        vec4 lodLayer = texture(colortex8, uv);
        if (lodLayer.a > 0.001) {
            float lodTransDepth = texture(lodDepthTex0, uv).r;
            if (lodTransDepth < 1.0) {
                float lodDist = length(screenToView(vec3(uv, lodTransDepth), lodProjectionInverse));
                float vanillaDist = depth < 1.0
                    ? length(screenToView(vec3(uv, depth), gbufferProjectionInverse))
                    : 1e9;
                if (lodDist < vanillaDist)
                    color = color * (1.0 - lodLayer.a) + lodLayer.rgb;
            }
        }
    }
#endif

    outColor = lineOverlay(vec4(color, 1.0));
}
