/* Refrax — program/forward.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/blockid.glsl"
#include "/lib/noise.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/clouds.glsl"
#include "/lib/shadows.glsl"
#include "/lib/voxel.glsl"
#include "/lib/water.glsl"
#include "/lib/ssr.glsl"
#include "/lib/labpbr.glsl"
#include "/lib/dh.glsl"
#include "/lib/thunder.glsl"

#include "/lib/wetness.glsl"

#ifdef WATER_RAIN_RIPPLES
  #if defined WATER && !defined WORLD_NETHER && !defined WORLD_END
    #define WATER_RIPPLES_ACTIVE
  #endif
#endif

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D noisetex;
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
uniform int heldItemId, heldItemId2;
#ifdef IS_IRIS
uniform vec3 relativeEyePosition;
#endif
#ifdef ENTITY
uniform vec4 entityColor;
#endif
#ifdef THUNDER_ACTIVE
uniform vec4 lightningBoltPosition;
#endif
#ifdef WATER_RIPPLES_ACTIVE
uniform float refraxSnowBiome;
#endif

in vec2 uv;
in vec2 lmcoord;
in vec4 vcolor;
in vec3 normalW;
in vec3 tangentW;
in float tangentSign;
in vec3 scenePos;
flat in int blockId;
flat in vec2 tileBase;
flat in vec2 tileSize;
#if defined PBR_MATERIALS && !defined PARTICLE
flat in vec2 tileAlphaRange;
#endif

#if defined WATER || defined HAND
/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outWaterData;
#else
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;
#endif

vec3 blockLightAt(vec3 pos, vec3 N, float lmBlock) {
    vec3 fallback = FALLBACK_BLOCKLIGHT * pow3(lmBlock) * 1.85;
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
    vec3 colored = lpv + fallback * vanillaContribution * LPV_VANILLA_MIX;
    vec3 light = mix(fallback, max(colored, fallback * LPV_VANILLA_MIX * 0.7), fade);
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
    vec2 uvDx = dFdx(uv);
    vec2 uvDy = dFdy(uv);
    vec2 texcoord = uv;
    vec4 albedo = textureGrad(gtexture, texcoord, uvDx, uvDy) * vcolor;

#ifdef PARTICLE_MARKER
    if (rainStrength > 0.01) {
        float splashBlue = albedo.b - max(albedo.r, albedo.g);
        if (albedo.b > 0.68 && splashBlue > 0.22 && albedo.r < 0.40)
            discard;
    }
#endif
#if defined PARTICLE && !defined WEATHER
    bool splashPalette = albedo.r < 0.42 && albedo.g < 0.62 && albedo.b > 0.55
                      && albedo.b > albedo.r * 1.70
                      && albedo.b > albedo.g * 1.15;
    if (rainStrength > 0.01 && splashPalette)
        discard;
#endif

    bool realWaterFwd = false;
#ifdef WATER
    realWaterFwd = blockId == 10061;
#endif
    bool alphaCutoutTile = false;
#if defined PBR_MATERIALS && !defined PARTICLE
    float tileMinAlpha = tileAlphaRange.x * vcolor.a;
    float tileMaxAlpha = tileAlphaRange.y * vcolor.a;
    alphaCutoutTile = !realWaterFwd && tileMinAlpha < 0.05 && tileMaxAlpha > 0.95;
#endif
    bool cutoutFoliage = isFoliage(blockId) || alphaCutoutTile;
    if (cutoutFoliage) {
        if (albedo.a < max(alphaTestRef, 0.5)) discard;
        albedo.a = 1.0;
    }
    float pomShadow = 1.0;
    vec3 pomSlopeN = vec3(0.0, 0.0, 1.0);
    float pomSlopeW = 0.0;
#if defined HAND && defined PBR_MATERIALS && defined POM
    if (!cutoutFoliage && dot(tangentW, tangentW) > 1e-6) {
        mat3 handTBN = makeTBN(normalize(normalW), tangentW, tangentSign);
        vec3 viewDirT = normalize(transpose(handTBN) * -normalize(scenePos));
        vec3 lightDirW = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
        vec3 lightDirT = normalize(transpose(handTBN) * lightDirW);
        float pomHeight;
        texcoord = pomOffset(normals, texcoord, tileBase, tileSize, viewDirT, uvDx, uvDy, 0.0, pomHeight, pomSlopeN, pomSlopeW);
        pomShadow = pomDirectShadow(normals, texcoord, tileBase, tileSize, lightDirT, uvDx, uvDy, pomHeight, 0.0);
        albedo = textureGrad(gtexture, texcoord, uvDx, uvDy) * vcolor;
    }
#endif
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
    vec3 geomN = N;
    vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float dither = ignAnim(gl_FragCoord.xy, frameCounter);
    float ssrDither = ign(gl_FragCoord.xy);
    vec2 ssrJitter = taaJitterUV(vec2(viewWidth, viewHeight), frameCounter);
    float materialAO = 1.0;

  #if defined PBR_MATERIALS && !defined PARTICLE
    // labPBR for translucents (stained glass, ice, held water...). Real water
    // tops get their normal replaced by the procedural waves below.
    Material mat;
    mat.roughness = 0.9;
    mat.f0 = 0.04;
    mat.emission = 0.0;
    mat.sss = 0.0;
    mat.porosity = 0.0;
    mat.anisotropy = 0.0;
    mat.clearcoat = 0.0;
    mat.thinFilm = 0.0;
    if (!cutoutFoliage) mat = decodeSpecular(textureGrad(specular, texcoord, uvDx, uvDy));
    if (!cutoutFoliage) applyFallbackMaterial(blockId, mat);
  #if !defined HAND && !defined ENTITY
    if (mat.emission <= 0.0 && blockId == 0)
        mat.emission = inferredEmission(linearToSrgb(albedo.rgb), lmcoord.x);
  #endif
    if (!cutoutFoliage && dot(tangentW, tangentW) > 1e-6) {
        mat3 TBN = makeTBN(N, tangentW, tangentSign);
        vec4 nTex = textureGrad(normals, texcoord, uvDx, uvDy);
        if (nTex.r + nTex.g > 0.0005) {
            vec3 tanN = filteredNormalTex(nTex, uvDx, uvDy, vec2(textureSize(normals, 0)));
  #if defined HAND && defined POM
            if (pomSlopeW > 0.0) tanN = normalize(mix(tanN, pomSlopeN, pomSlopeW));
  #endif
            N = normalize(TBN * tanN);
            float decodedAO = decodeTexAO(nTex);
            materialAO = mix(decodedAO, decodedAO * decodedAO, PBR_AO_DEPTH);
        }
    }
    mat.roughness = materialSpecularRoughness(mat.roughness, N);
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
    float waterRoughness = WATER_ROUGHNESS;
    float waterCrest = 0.0;
    float waterFlow = 0.0;
    float waterFootprint = max(max(length(dFdx(scenePos)), length(dFdy(scenePos))), 0.005);
    if (realWater && N.y > 0.5) {
        float vDot = abs(dot(N, normalize(-scenePos)));
        float waterDist = length(scenePos);
        vec2 drift = vec2(0.0);
    #ifdef WATER_FLOW
        {
            vec3 surfN = normalize(cross(dFdx(scenePos), dFdy(scenePos)));
            if (surfN.y < 0.0) surfN = -surfN;
            vec2 grad = surfN.xz / max(surfN.y, 0.25);
            waterFlow = min(length(grad), 0.9);
            if (waterFlow > 0.02)
                drift = grad * (frameTimeCounter * WAVE_SPEED * FLOW_SPEED * 1.35);
        }
    #endif
        N = waterSurfaceNormalFlow(noisetex, worldPos, drift, frameTimeCounter, vDot, lmcoord.y, rainStrength, waterFlow, waterFootprint, waterRoughness, waterCrest);
    #ifdef WATER_RIPPLES_ACTIVE
        {
            float ripple = (1.0 - smoothstep(16.0, 40.0, waterDist))
                         * smoothstep(0.35, 0.85, lmcoord.y)
                         * smoothstep(0.05, 0.60, rainStrength)
                         * (1.0 - refraxSnowBiome) * RAIN_RIPPLE_STRENGTH;
            if (ripple > 0.002) {
                const float e = 0.07;
                float h0 = puddleRippleHeight(worldPos.xz, frameTimeCounter);
                float hx = puddleRippleHeight(worldPos.xz + vec2(e, 0.0), frameTimeCounter);
                float hz = puddleRippleHeight(worldPos.xz + vec2(0.0, e), frameTimeCounter);
                vec2 slope = vec2(h0 - hx, h0 - hz) / e;
                N = normalize(N + vec3(slope.x, 0.0, slope.y) * (0.005 * ripple));
            }
        }
    #endif
    }
  #ifdef WATER_FLOW
    else if (realWater && abs(N.y) < 0.5) {
        waterFlow = 1.0;
        N = waterfallSurfaceNormal(noisetex, worldPos, N, frameTimeCounter, lmcoord.y, rainStrength, waterFlow, waterFootprint, waterRoughness, waterCrest);
    }
  #endif
  #endif

    float NoL = saturate(dot(N, lightDir));
  #if defined WORLD_NETHER
    vec3 shadow = vec3(0.0);
  #elif defined PARTICLE
    #ifdef WORLD_END
    vec3 shadow = vec3(0.75);
    #else
    vec3 shadow = vec3(pow2(lmcoord.y));
    #endif
    NoL = 0.6;
  #elif defined HAND
    vec3 shadow = vec3(pomShadow * pow2(lmcoord.y));
  #else
    vec3 shadow = getShadow(scenePos, N, NoL, dither, shadowModelView, shadowProjection, shadowtex0, shadowtex1, shadowcolor0);
    #if defined CLOUD_SHADOWS && !defined WORLD_NETHER && !defined WORLD_END
    if (NoL > 0.0 && shadow.g > 0.001)
        shadow *= cloudShadow(scenePos + cameraPosition, cameraPosition, lightDir, frameTimeCounter, rainStrength);
    #endif
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
    vec3 blockLight = blockLightAt(scenePos, geomN, lmcoord.x);
  #ifdef WORLD_NETHER
    blockLight *= facing;
  #endif
    vec3 minAmb = vec3(0.010, 0.011, 0.014) * MIN_AMBIENT;
    vec3 flash = vec3(0.0);
  #ifdef THUNDER_ACTIVE
    flash = thunderLight(scenePos, N, lmcoord.y, lightningBoltPosition);
  #endif
    vec3 lit = albedo.rgb * (lightCol * NoL * shadow * mix(materialAO, 1.0, 0.35) + (skyLight + blockLight + minAmb) * materialAO + flash);
    float alpha = albedo.a;
  #if defined PBR_MATERIALS && !defined PARTICLE
    lit += albedo.rgb * sqrt(albedo.rgb) * (mat.emission * EMISSION_STRENGTH * EMISSION_SCALE);
    #ifdef SUBSURFACE_SCATTERING
    {
        float fwdSss = mat.sss;
        if (cutoutFoliage && fwdSss <= 0.0 && isFoliage(blockId)) fwdSss = FOLIAGE_SSS;
        if (fwdSss > 0.0)
            lit += subsurfaceTransmission(albedo.rgb, N, normalize(scenePos), lightDir, fwdSss)
                 * lightCol * mix(shadow, vec3(1.0), 0.65);
    }
    #endif
  #endif

  #if defined HAND && defined PBR_MATERIALS && !defined PARTICLE
    {
        vec3 V = normalize(-scenePos);
        bool matteHand = isMatteFoliageMaterial(mat.roughness, mat.f0);
        bool metalHand = !matteHand && isMetal(mat.f0);
        float handSmoothness = saturate(1.0 - sqrt(saturate(mat.roughness)));
        vec3 handF0 = matteHand ? vec3(0.0) : materialF0(mat.f0, albedo.rgb);
        float handSpecWeight = metalHand ? 1.0 : mix(0.08, 0.60, smoothstep(0.10, 0.85, handSmoothness));
        handSpecWeight = max(handSpecWeight, mat.clearcoat * 0.35);
        if (!matteHand && handSpecWeight > 0.0) {
            vec3 handSpecular = materialDiscLightSpecular(N, V, lightDir, SUN_GLINT_RADIUS, mat.roughness, handF0, mat.anisotropy, mat.clearcoat, mat.thinFilm) * lightCol * shadow * handSpecWeight * PBR_GLINT_STRENGTH;
            lit += compressMaterialHighlight(handSpecular);
        }
        float handNoV = saturate(dot(V, N));
        float handReflectionRoughness = materialReflectionRoughness(mat.roughness, mat.clearcoat);
        vec3 handFresnel = matteHand ? vec3(0.0) : materialReflectionFresnel(handNoV, mat.f0, albedo.rgb, mat.clearcoat, mat.thinFilm);
        float handReflectionWeight = metalHand ? mix(0.35, 0.85, 1.0 - saturate(handReflectionRoughness)) : pow2(1.0 - saturate(handReflectionRoughness));
        vec3 handReflectionDirection = reflect(-V, N);
        vec3 handReflection = dimensionSkyReflection(handReflectionDirection, sunDir, fogColor, frameTimeCounter, rainStrength);
        handReflection *= mix(0.02, 1.0, lmcoord.y * lmcoord.y);
        lit += handReflection * handFresnel * handReflectionWeight;
    }
  #endif

  #ifdef WATER
    if (!realWater && cutoutFoliage) {
        outWaterData = packSurfaceData(N, 0.0, SURF_STATIC);
        outColor = vec4(lit, 1.0);
        return;
    }

    vec3 viewDirW = normalize(-scenePos);
    vec3 surfaceFresnel = fresnelSchlick(saturate(dot(viewDirW, N)), vec3(0.02));
  #if defined PBR_MATERIALS && !defined PARTICLE
    if (!realWater) surfaceFresnel = materialReflectionFresnel(dot(viewDirW, N), mat.f0, albedo.rgb, mat.clearcoat, mat.thinFilm);
  #endif
    float fres = realWater ? waterFresnel(dot(viewDirW, N)) : luminance(surfaceFresnel);

    vec3 reflDirW = realWater ? waterReflectionDirection(viewDirW, N) : reflect(-viewDirW, N);
  #if defined WORLD_NETHER || defined WORLD_END
    vec3 refl = dimensionSkyReflection(reflDirW, sunDir, fogColor, frameTimeCounter, rainStrength);
  #else
    float skyReflectionVisibility = mix(0.08, 1.0, lmcoord.y * lmcoord.y);
    vec3 refl = skyReflection(reflDirW, sunDir, rainStrength) * skyReflectionVisibility;
  #endif
    if (realWater && WATER_REFLECTION_MODE > 0 && fres > 0.025) {
        vec3 viewPos = (gbufferModelView * vec4(scenePos, 1.0)).xyz;
        vec3 reflDirV = mat3(gbufferModelView) * reflDirW;
        vec3 hit;
        float ssrQuality = ssrRayQuality(waterRoughness);
        float hitS = WATER_REFLECTION_MODE == 1
            ? raymarchSSRFast(depthtex1, ivec2(viewWidth, viewHeight), viewPos, reflDirV, gbufferProjection, gbufferProjectionInverse, ssrDither, ssrJitter, ssrQuality, hit)
            : raymarchSSR(depthtex1, ivec2(viewWidth, viewHeight), viewPos, reflDirV, gbufferProjection, gbufferProjectionInverse, ssrDither, ssrJitter, ssrQuality, hit);
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
  #ifdef THUNDER_ACTIVE
    refl *= 1.0 + thunderSkyGlow(lightningBoltPosition) * 1.5;
  #endif
    float glintRough = waterRoughness;
    float glintRadius = SUN_GLINT_RADIUS;
    vec3 glintF0 = vec3(WATER_FRESNEL);
  #if defined PBR_MATERIALS && !defined PARTICLE
    if (!realWater) {
        glintRough = max(materialReflectionRoughness(mat.roughness, mat.clearcoat) * 0.5, 0.03);
        glintRadius = SUN_GLINT_RADIUS;
        glintF0 = materialF0(mat.f0, albedo.rgb);
    }
  #else
    if (!realWater) {
        glintRough = 0.03;
        glintRadius = SUN_GLINT_RADIUS;
    }
  #endif
    vec3 sunSpecShape = realWater
        ? vec3(waterSunGlint(N, viewDirW, lightDir))
  #if defined PBR_MATERIALS && !defined PARTICLE
        : materialDiscLightSpecular(N, viewDirW, lightDir, glintRadius, glintRough, glintF0, mat.anisotropy, mat.clearcoat, mat.thinFilm);
  #else
        : discLightSpecular(N, viewDirW, lightDir, glintRadius, glintRough, glintF0);
  #endif
    vec3 sunSpec = sunSpecShape * lightCol * shadow * (realWater ? WATER_GLINT_STRENGTH : PBR_GLINT_STRENGTH);
  #if defined PBR_MATERIALS && !defined PARTICLE
    if (!realWater) sunSpec = compressMaterialHighlight(sunSpec);
  #endif
    if (realWater) {
        refl = waterReflectionColor(refl);
        sunSpec = waterGlintColor(sunSpec);
    }

    if (realWater) {
        vec2 suv = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
        float dBack = texture(depthtex1, suv).r;
        vec3 backView = screenToView(vec3(suv, dBack), gbufferProjectionInverse);
        float backDist = length(backView);
#ifdef LOD_ACTIVE
        if (dBack >= 1.0) {
            float lodBack = texture(lodDepthTex1, suv).r;
            if (lodBack < 1.0)
                backDist = length(screenToView(vec3(suv, lodBack), lodProjectionInverse));
        }
#endif
        float waterDepth = max(backDist - length(scenePos), 0.0);
        vec3 trans = waterTransmittanceTinted(vcolor.rgb, waterDepth);

        vec3 bodyLighting = lightCol * NoL * shadow * 0.22 + skyLight * 0.92 + blockLight * 0.52 + flash * 0.60;
        vec3 body = waterBodyColor(vcolor.rgb, trans, bodyLighting);
        lit = mix(body, refl, fres) + sunSpec;
        alpha = waterSurfaceAlpha(trans, fres);

#ifdef WATER_FOAM
        float waterSlope = geomN.y > 0.5 ? length(N.xz) / max(N.y, 0.1) : 0.0;
        float mask = waterFoamMask(noisetex, worldPos.xz, frameTimeCounter, waterDepth, waterCrest, waterSlope, rainStrength, waterFlow);
        if (mask > 0.001) {
            vec3 foamCol = (skyLight + lightCol * shadow * 0.35) * vec3(0.98, 1.02, 1.08);
            lit = mix(lit, foamCol, mask);
            alpha = max(alpha, mask * 0.92);
        }
#endif
        outWaterData = packSurfaceData(N, 0.0, SURF_WATER);
    } else {
      #if defined PBR_MATERIALS && !defined PARTICLE
        float glassSmooth = 1.0 - sqrt(saturate(mat.roughness));
        vec3 reflW = surfaceFresnel * (0.8 + 4.5 * glassSmooth * glassSmooth);
        lit += refl * reflW + sunSpec * mix(0.5, 1.0, glassSmooth);
        alpha = max(alpha, saturate(luminance(reflW)) * 0.6);
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
            lit = portal * (NETHER_PORTAL_BRIGHTNESS * EMISSION_STRENGTH) + portal * blockLight * 0.12;
            alpha = saturate(max(texA.a, texB.a) * (0.68 + 0.26 * veil));
            alpha *= smoothstep(0.08, 0.55, length(scenePos));
        }
        outWaterData = packSurfaceData(N, 0.0, blockId == 10018 ? SURF_PORTAL : SURF_STATIC);
    }
  #endif

#if defined HAND && !defined WATER
    outWaterData = packSurfaceData(N, 0.0, SURF_STATIC);
#endif
    outColor = vec4(lit, alpha);
#ifdef HAND_OPAQUE
    outColor.a = 0.49;
#endif
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
#ifdef WEATHER
    {
        bool isRain = abs(albedo.r - albedo.b) > 0.015;
        float streakLum = luminance(outColor.rgb);
        vec3 neutral = vec3(streakLum);
        vec3 cool = vec3(0.45, 0.60, 1.00);
        cool *= streakLum / max(luminance(cool), 1e-3);

        vec3 target = isRain ? mix(neutral, cool, RAIN_TINT) : mix(neutral, vec3(0.94, 0.97, 1.00) * (streakLum / 0.918) * 1.15, 0.45);
        outColor.rgb = mix(outColor.rgb, target, isRain ? 0.85 : 0.45);
        outColor.a *= RAIN_OPACITY * (0.55 + 0.45 * rainStrength) * (isRain ? 1.0 : 1.30);
    }
#endif
#endif
}
