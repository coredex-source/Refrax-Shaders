/* Refrax — program/dh_water.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/shadows.glsl"
#include "/lib/water.glsl"
#include "/lib/dh.glsl"

uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D shadowtex0, shadowtex1, shadowcolor0;
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform mat4 shadowModelView, shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec3 fogColor;
uniform float frameTimeCounter, rainStrength, viewWidth, viewHeight, far;
uniform int frameCounter;

in vec2 lmcoord;
in vec4 vcolor;
in vec3 normalW;
in vec3 scenePos;
in float viewZ;
flat in int matId;

/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outWaterData;

void main() {
#ifdef DISTANT_HORIZONS
    float dist = length(scenePos);
    float dither = ignAnim(gl_FragCoord.xy, frameCounter);
    if (dither > dhOverdrawFade(dist, far)) discard;
    vec2 suv = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    float vDepth = texture(depthtex1, suv).r;
    if (vDepth < 1.0 && screenToView(vec3(suv, vDepth), gbufferProjectionInverse).z > viewZ) discard;
    bool water = matId == DH_BLOCK_WATER;
    vec3 N = normalize(normalW);
    vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    vec3 viewDirW = normalize(-scenePos);
    vec3 worldPos = scenePos + cameraPosition;
    vec3 geomN = N;
    float waterRoughness = WATER_ROUGHNESS;
    float waterCrest = 0.0;
    float waterFlow = 0.0;
    float waterFootprint = max(max(length(dFdx(scenePos)), length(dFdy(scenePos))), 0.005);

    if (water && N.y > 0.5) {
        float vDot = abs(dot(N, viewDirW));
        vec2 drift = vec2(0.0);
#ifdef WATER_FLOW
        vec3 surfN = normalize(cross(dFdx(scenePos), dFdy(scenePos)));
        if (surfN.y < 0.0) surfN = -surfN;
        vec2 grad = surfN.xz / max(surfN.y, 0.25);
        waterFlow = min(length(grad), 0.9);
        if (waterFlow > 0.02) drift = grad * (frameTimeCounter * WAVE_SPEED * FLOW_SPEED * 1.35);
#endif
        N = waterSurfaceNormalFlow(noisetex, worldPos, drift, frameTimeCounter, vDot, lmcoord.y, rainStrength, waterFlow, waterFootprint, waterRoughness, waterCrest);
    }
#ifdef WATER_FLOW
    else if (water && abs(N.y) < 0.5) {
        waterFlow = 1.0;
        N = waterfallSurfaceNormal(noisetex, worldPos, N, frameTimeCounter, lmcoord.y, rainStrength, waterFlow, waterFootprint, waterRoughness, waterCrest);
    }
#endif

    float NoL = saturate(dot(N, lightDir));
#if defined WORLD_NETHER
    vec3 lightCol = vec3(0.0);
    vec3 shadow = vec3(0.0);
    float facing = netherFacing(N);
    vec3 skyLight = netherAmbient(N, fogColor) * facing;
#elif defined WORLD_END
    vec3 lightCol = endLightColor();
    vec3 shadow = getShadow(scenePos, N, NoL, dither, shadowModelView, shadowProjection, shadowtex0, shadowtex1, shadowcolor0);
    vec3 skyLight = endAmbient(N);
#else
    vec3 lightCol = (sunColor(sunDir.y) + moonColor(-sunDir.y)) * (1.0 - rainStrength * 0.9);
    vec3 shadow = getShadow(scenePos, N, NoL, dither, shadowModelView, shadowProjection, shadowtex0, shadowtex1, shadowcolor0);
    vec3 skyLight = skyAmbientDirectional(N, sunDir, rainStrength) * pow(lmcoord.y, 2.2);
    skyLight += lightCol * 0.05 * saturate(0.6 - 0.4 * N.y) * pow(lmcoord.y, 2.2);
#endif
    vec3 blockLight = FALLBACK_BLOCKLIGHT * pow(lmcoord.x, 3.0) * 1.85;
#ifdef WORLD_NETHER
    blockLight *= NETHER_FALLBACK_SCALE * facing;
#endif
    vec3 minAmb = vec3(0.010, 0.011, 0.014) * MIN_AMBIENT;

    float fres = water ? waterFresnel(dot(viewDirW, N)) : fresnelSchlick(saturate(dot(viewDirW, N)), vec3(0.02)).x;
    vec3 reflDirW = water ? waterReflectionDirection(viewDirW, N) : reflect(-viewDirW, N);
#if defined WORLD_NETHER || defined WORLD_END
    vec3 refl = dimensionSky(reflDirW, sunDir, fogColor, frameTimeCounter, rainStrength);
#else
    vec3 refl = skyGradient(reflDirW, sunDir, rainStrength) * mix(0.08, 1.0, lmcoord.y * lmcoord.y);
#endif

    float glintRough = water ? waterRoughness : 0.03;
    vec3 sunSpecShape = water
        ? vec3(waterSunGlint(N, viewDirW, lightDir))
        : discLightSpecular(N, viewDirW, lightDir, SUN_GLINT_RADIUS, glintRough, vec3(0.02));
    vec3 sunSpec = sunSpecShape * lightCol * shadow * (water ? WATER_GLINT_STRENGTH : PBR_GLINT_STRENGTH);
    if (water) {
        refl = waterReflectionColor(refl);
        sunSpec = waterGlintColor(sunSpec);
    }

    vec3 lit;
    float alpha;
    if (water) {
        float dBack = texture(dhDepthTex1, suv).r;
        vec3 backView = screenToView(vec3(suv, dBack), dhProjectionInverse);
        float waterDepth = max(length(backView) - dist, 0.0);
        vec3 trans = waterTransmittanceTinted(vcolor.rgb, waterDepth);

        vec3 bodyLighting = lightCol * NoL * shadow * 0.22 + skyLight * 0.92 + blockLight * 0.52;
        vec3 body = waterBodyColor(vcolor.rgb, trans, bodyLighting);
        lit = mix(body, refl, fres) + sunSpec;
        alpha = waterSurfaceAlpha(trans, fres);
#ifdef WATER_FOAM
        float waterSlope = geomN.y > 0.5 ? length(N.xz) / max(N.y, 0.1) : 0.0;
        float foam = waterFoamMask(noisetex, worldPos.xz, frameTimeCounter, waterDepth, waterCrest, waterSlope, rainStrength, waterFlow);
        if (foam > 0.001) {
            vec3 foamCol = (skyLight + lightCol * shadow * 0.35) * vec3(0.98, 1.02, 1.08);
            lit = mix(lit, foamCol, foam);
            alpha = max(alpha, foam * 0.92);
        }
#endif
        outWaterData = vec4(N, 2.0);
    } else {
        vec3 albedo = srgbToLinear(vcolor.rgb);
        lit = albedo * (lightCol * NoL * shadow + skyLight + blockLight + minAmb);
        lit += refl * fres * 0.8 + sunSpec * 0.5;
        alpha = max(vcolor.a, fres * 0.5);
        outWaterData = vec4(N, 0.0);
    }

    outColor = vec4(lit, alpha);
#else
    discard;
#endif
}
