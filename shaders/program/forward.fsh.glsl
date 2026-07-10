/* Refrax — program/forward.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/blockid.glsl"
#include "/lib/noise.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/shadows.glsl"
#include "/lib/voxel.glsl"
#include "/lib/water.glsl"
#include "/lib/ssr.glsl"
#include "/lib/labpbr.glsl"

uniform sampler2D gtexture;
uniform sampler2D lightmap;
#if defined PBR_MATERIALS && !defined PARTICLE
uniform sampler2D normals;
uniform sampler2D specular;
#endif
uniform sampler2D depthtex1;
uniform sampler2D colortex5;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
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
uniform float frameTimeCounter, rainStrength, viewWidth, viewHeight, near, far;
uniform int frameCounter, isEyeInWater;
uniform float alphaTestRef;
uniform int heldBlockLightValue, heldBlockLightValue2;
#ifdef ENTITY
uniform vec4 entityColor;
#endif

in vec2 uv;
in vec2 lmcoord;
in vec4 vcolor;
in vec3 normalW;
in vec3 tangentW;
in float tangentSign;
in vec3 scenePos;
flat in int blockId;
in vec2 tileBase;
in vec2 tileSize;

#ifdef WATER
/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outWaterData;
#else
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;
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
    float held = float(max(heldBlockLightValue, heldBlockLightValue2));
    if (held > 0.0) {
        float d = length(pos);
        light += FALLBACK_BLOCKLIGHT * pow(saturate(1.0 - d / held), 2.0) * held * 0.12;
    }
#endif
    return light;
}

void main() {
    vec4 albedo = texture(gtexture, uv) * vcolor;
    bool realWaterFwd = false;
#ifdef WATER
    realWaterFwd = blockId == 10061;
#endif
    bool alphaCutoutTile = false;
#if defined PBR_MATERIALS && !defined PARTICLE
    float a00 = texture(gtexture, tileBase + tileSize * vec2(0.125, 0.125)).a;
    float a10 = texture(gtexture, tileBase + tileSize * vec2(0.500, 0.125)).a;
    float a20 = texture(gtexture, tileBase + tileSize * vec2(0.875, 0.125)).a;
    float a01 = texture(gtexture, tileBase + tileSize * vec2(0.125, 0.500)).a;
    float a11 = texture(gtexture, tileBase + tileSize * vec2(0.500, 0.500)).a;
    float a21 = texture(gtexture, tileBase + tileSize * vec2(0.875, 0.500)).a;
    float a02 = texture(gtexture, tileBase + tileSize * vec2(0.125, 0.875)).a;
    float a12 = texture(gtexture, tileBase + tileSize * vec2(0.500, 0.875)).a;
    float a22 = texture(gtexture, tileBase + tileSize * vec2(0.875, 0.875)).a;
    float tileMinAlpha = min(min(min(a00, a10), min(a20, a01)), min(min(a11, a21), min(a02, min(a12, a22)))) * vcolor.a;
    float tileMaxAlpha = max(max(max(a00, a10), max(a20, a01)), max(max(a11, a21), max(a02, max(a12, a22)))) * vcolor.a;
    alphaCutoutTile = !realWaterFwd && tileMinAlpha < 0.05 && tileMaxAlpha > 0.95;
#endif
    bool cutoutFoliage = isFoliage(blockId) || alphaCutoutTile;
    if (cutoutFoliage) {
        if (albedo.a < max(alphaTestRef, 0.5)) discard;
        albedo.a = 1.0;
    }
#ifdef ENTITY
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
#endif
#ifndef WATER
    if (albedo.a < alphaTestRef) discard;
#endif
#ifdef OPAQUE_PARTICLE
    albedo.a = 1.0;
#endif
#ifdef STOCHASTIC_PARTICLE
    float particleSoft = albedo.a < 0.98 ? 1.0 : 0.0;
    if (particleSoft > 0.5) {
  #ifdef TAA
        if (albedo.a < ignAnim(gl_FragCoord.xy, frameCounter)) discard;
  #else
        if (albedo.a < ign(gl_FragCoord.xy)) discard;
  #endif
    }
    albedo.a = 1.0;
#endif
    albedo.rgb = srgbToLinear(albedo.rgb);

#ifdef UNLIT
    outColor = albedo;
  #ifdef OPAQUE_PARTICLE
    outColor.a = 0.0;
  #endif
    return;
#else
    vec3 N = normalize(normalW);
    vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float dither = ignAnim(gl_FragCoord.xy, frameCounter);

  #if defined PBR_MATERIALS && !defined PARTICLE
    // labPBR for translucents (stained glass, ice, held water...). Real water
    // tops get their normal replaced by the procedural waves below.
    Material mat;
    mat.roughness = 0.9; mat.f0 = 0.04; mat.emission = 0.0; mat.sss = 0.0;
    if (!cutoutFoliage) mat = decodeSpecular(texture(specular, uv));
    if (!cutoutFoliage && dot(tangentW, tangentW) > 1e-6) {
        vec3 T = normalize(tangentW);
        vec3 B = cross(N, T) * tangentSign;
        vec4 nTex = texture(normals, uv);
        if (nTex.r + nTex.g > 0.0005) N = normalize(mat3(T, B, N) * decodeNormalTex(nTex));
    }
  #endif
  #if defined WORLD_NETHER
    vec3 lightCol = vec3(0.0);
  #elif defined WORLD_END
    vec3 lightCol = endLightColor();
  #else
    vec3 lightCol = (sunColor(sunDir.y) + moonColor(-sunDir.y)) * (1.0 - rainStrength * 0.9);
  #endif

  #ifdef WATER
    bool realWater = realWaterFwd;
    vec3 worldPos = scenePos + cameraPosition;
    if (realWater && N.y > 0.5) {
        float vDot = abs(dot(N, normalize(-scenePos)));
        N = waterNormal(worldPos.xz, frameTimeCounter, vDot, lmcoord.y, rainStrength);
    }
  #endif

    float NoL = saturate(dot(N, lightDir));
  #if defined WORLD_NETHER
    vec3 shadow = vec3(0.0);
  #elif defined PARTICLE
    #ifdef WORLD_END
    vec3 shadow = vec3(0.75);
    #else
    vec3 shadow = vec3(pow(lmcoord.y, 2.0));
    #endif
    NoL = 0.6;
  #else
    vec3 shadow = getShadow(scenePos, N, NoL, dither, shadowModelView, shadowProjection, shadowtex0, shadowtex1, shadowcolor0);
  #endif

  #if defined WORLD_NETHER
    float facing = netherFacing(N);
    vec3 skyLight = netherAmbient(N, fogColor) * facing;
  #elif defined WORLD_END
    vec3 skyLight = endAmbient(N);
  #else
    vec3 skyLight = skyAmbientDirectional(N, sunDir, rainStrength) * pow(lmcoord.y, 2.2);
    skyLight += lightCol * 0.05 * saturate(0.6 - 0.4 * N.y) * pow(lmcoord.y, 2.2);
  #endif
    vec3 blockLight = blockLightAt(scenePos, N, lmcoord.x);
  #ifdef WORLD_NETHER
    blockLight *= facing;
  #endif
    vec3 minAmb = vec3(0.010, 0.011, 0.014) * MIN_AMBIENT;
    vec3 lit = albedo.rgb * (lightCol * NoL * shadow + skyLight + blockLight + minAmb);
    float alpha = albedo.a;
  #if defined PBR_MATERIALS && !defined PARTICLE
    lit += albedo.rgb * sqrt(albedo.rgb) * (mat.emission * EMISSION_STRENGTH * EMISSION_SCALE);
  #endif

  #ifdef WATER
    if (!realWater && cutoutFoliage) {
        outWaterData = vec4(N, 0.0);
        outColor = vec4(lit, 1.0);
        return;
    }

    vec3 viewDirW = normalize(-scenePos);
    float fres = saturate(fresnelSchlick(saturate(dot(viewDirW, N)), vec3(0.02)).x * 1.35 + 0.015);

    vec3 reflDirW = reflect(-viewDirW, N);
  #if defined WORLD_NETHER || defined WORLD_END
    vec3 refl = dimensionSky(reflDirW, sunDir, fogColor, frameTimeCounter, rainStrength);
  #else
    vec3 refl = skyGradient(reflDirW, sunDir, rainStrength) * pow(lmcoord.y, 2.0);
  #endif
    if (realWater && WATER_REFLECTION_MODE > 0 && fres > 0.045) {
        vec3 viewPos = (gbufferModelView * vec4(scenePos, 1.0)).xyz;
        vec3 reflDirV = mat3(gbufferModelView) * reflDirW;
        vec3 hit;
        float hitS = WATER_REFLECTION_MODE == 1
            ? raymarchSSRFast(depthtex1, viewPos, reflDirV, gbufferProjection, gbufferProjectionInverse, dither, hit)
            : raymarchSSR(depthtex1, viewPos, reflDirV, gbufferProjection, gbufferProjectionInverse, dither, hit);
        if (hitS > 0.0) {
            vec3 hitView = screenToView(hit, gbufferProjectionInverse);
            vec3 hitScene = (gbufferModelViewInverse * vec4(hitView, 1.0)).xyz;
            vec3 prevUV = reprojectScene(hitScene, gbufferPreviousModelView, gbufferPreviousProjection, cameraPosition, previousCameraPosition);
            if (clamp(prevUV.xy, 0.0, 1.0) == prevUV.xy) {
                vec4 hist = texture(colortex5, historyUV(prevUV.xy, 1.0 / vec2(viewWidth, viewHeight)));
                refl = mix(refl, hist.rgb, hitS * saturate(hist.a));
            }
        }
    }
    float glintRough = WATER_ROUGHNESS + saturate(length(scenePos) / 80.0) * 0.06;
    vec3 glintF0 = vec3(0.02);
  #if defined PBR_MATERIALS && !defined PARTICLE
    if (!realWater) {
        glintRough = max(mat.roughness * 0.5, 0.03);
        glintF0 = vec3(max(mat.f0, 0.02));
    }
  #else
    if (!realWater) glintRough = 0.03;
  #endif
    vec3 sunSpecShape = realWater
        ? waterDiscLightSpecular(N, viewDirW, lightDir, SUN_GLINT_RADIUS, glintRough, glintF0)
        : discLightSpecular(N, viewDirW, lightDir, SUN_GLINT_RADIUS, glintRough, glintF0);
    vec3 sunSpec = sunSpecShape * lightCol * shadow * (realWater ? SUN_GLINT_STRENGTH : PBR_GLINT_STRENGTH);

    if (realWater) {
        vec2 suv = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
        float dBack = texture(depthtex1, suv).r;
        vec3 backView = screenToView(vec3(suv, dBack), gbufferProjectionInverse);
        float waterDepth = max(length(backView) - length(scenePos), 0.0);
        vec3 trans = waterTransmittanceTinted(vcolor.rgb, waterDepth);

        vec3 scatter = mix(WATER_COLOR, srgbToLinear(vcolor.rgb), 0.45) * 0.48;
        vec3 body = scatter * (lightCol * NoL * shadow * 0.22 + skyLight * 0.85 + blockLight * 0.55);
        body = mix(body, body * 0.45, saturate(1.0 - trans.g));
        lit = mix(body, refl, fres) + sunSpec * 1.5;
        alpha = saturate(0.16 + (1.0 - trans.g) * 0.46 + fres * 0.55);
        outWaterData = vec4(N, 2.0);
    } else {
      #if defined PBR_MATERIALS && !defined PARTICLE
        float glassSmooth = 1.0 - sqrt(saturate(mat.roughness));
        float reflW = fres * (0.8 + 4.5 * glassSmooth * glassSmooth);
        lit += refl * reflW + sunSpec * mix(0.5, 1.0, glassSmooth);
        alpha = max(alpha, saturate(reflW) * 0.6);
      #else
        lit += refl * fres * 0.8 + sunSpec * 0.5;
        alpha = max(alpha, fres * 0.5);
      #endif
        if (blockId == 10018) {
            float t = frameTimeCounter;
            vec3 worldPos = scenePos + cameraPosition;
            vec3 nAbs = abs(N);
            vec2 portalCoord;
            if (nAbs.x > nAbs.z && nAbs.x > nAbs.y) {
                portalCoord = vec2(worldPos.z, worldPos.y);
            } else if (nAbs.z > nAbs.x && nAbs.z > nAbs.y) {
                portalCoord = vec2(worldPos.x, worldPos.y);
            } else {
                portalCoord = worldPos.xz;
            }

            vec2 field = portalCoord * vec2(0.62, 0.48);
            float flowNoise = fbm3(vec3(portalCoord * vec2(1.55, 2.40), t * 0.20), 4);
            vec2 warp = vec2(
                sin(portalCoord.y * 4.7 + t * 1.15 + flowNoise * 4.0) * 0.045,
                (flowNoise - 0.5) * 0.070
            );
            vec2 flowA = fract(field + warp + vec2(0.020 * dither, -t * 0.055));
            vec2 flowB = fract(field * vec2(1.28, 0.76) - warp.yx + vec2(0.045 * sin(t * 0.33), t * 0.035));
            vec4 texA = texture(gtexture, tileBase + tileSize * flowA);
            vec4 texB = texture(gtexture, tileBase + tileSize * flowB);

            vec3 violet = vec3(0.48, 0.14, 1.00);
            vec3 magenta = vec3(1.00, 0.22, 0.78);
            vec3 blue = vec3(0.18, 0.38, 1.00);
            float streak = 0.5 + 0.5 * sin(portalCoord.x * 5.5 + portalCoord.y * 1.7 + flowNoise * 5.0 - t * 1.7);
            float sheet = smoothstep(0.25, 0.95, flowNoise) * 0.65 + smoothstep(0.62, 1.0, streak) * 0.35;
            vec3 tint = mix(mix(blue, violet, flowNoise), magenta, sheet * 0.45);
            float veil = saturate(0.42 + flowNoise * 0.38 + sheet * 0.28);

            vec3 portalTex = mix(texA.rgb, texB.rgb, 0.35);
            vec3 portal = srgbToLinear(portalTex * tint) * (2.0 + 2.5 * veil) + srgbToLinear(tint) * (0.35 + 0.55 * sheet);
            lit = portal * (3.8 * EMISSION_STRENGTH) + portal * blockLight * 0.12;
            alpha = saturate(max(texA.a, texB.a) * (0.68 + 0.26 * veil));
            alpha *= smoothstep(0.08, 0.55, length(scenePos));
        }
        outWaterData = vec4(N, blockId == 10018 ? 3.0 : 0.0);
    }
  #endif

    outColor = vec4(lit, alpha);
#ifdef OPAQUE_PARTICLE
  #ifdef PARTICLE_MARKER
    outColor.a = 0.25;
  #else
    outColor.a = 0.0;
  #endif
#endif
#ifdef STOCHASTIC_PARTICLE
    outColor.a = particleSoft > 0.5 ? 0.75 : 0.25;
#endif
#endif
}
