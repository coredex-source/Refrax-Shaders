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

    if (water && N.y > 0.5) {
        vec3 worldPos = scenePos + cameraPosition;
        float vDot = abs(dot(N, viewDirW));
        N = waterNormal(noisetex, worldPos.xz, frameTimeCounter, vDot, lmcoord.y, rainStrength, dist);
    }

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
    vec3 reflDirW = reflect(-viewDirW, N);
#if defined WORLD_NETHER || defined WORLD_END
    vec3 refl = dimensionSky(reflDirW, sunDir, fogColor, frameTimeCounter, rainStrength);
#else
    vec3 refl = skyGradient(reflDirW, sunDir, rainStrength) * mix(0.08, 1.0, lmcoord.y * lmcoord.y);
#endif

    float glintRough = water ? WATER_ROUGHNESS + saturate(dist / 96.0) * 0.018 : 0.03;
    vec3 sunSpecShape = water
        ? waterDiscLightSpecular(N, viewDirW, lightDir, SUN_GLINT_RADIUS, glintRough, vec3(0.02))
        : discLightSpecular(N, viewDirW, lightDir, SUN_GLINT_RADIUS, glintRough, vec3(0.02));
    vec3 sunSpec = sunSpecShape * lightCol * shadow * (water ? SUN_GLINT_STRENGTH : PBR_GLINT_STRENGTH);

    vec3 lit;
    float alpha;
    if (water) {
        float dBack = texture(dhDepthTex1, suv).r;
        vec3 backView = screenToView(vec3(suv, dBack), dhProjectionInverse);
        float waterDepth = max(length(backView) - dist, 0.0);
        vec3 trans = waterTransmittanceTinted(vcolor.rgb, waterDepth);

        vec3 scatter = mix(WATER_COLOR * WATER_COLOR, srgbToLinear(vcolor.rgb) * 0.20, 0.25) * 0.80;
        vec3 body = scatter * (lightCol * NoL * shadow * 0.22 + skyLight * 0.92 + blockLight * 0.52);
        body = mix(body, body * 0.42, saturate(1.0 - trans.g));
        lit = mix(body, refl, fres) + sunSpec * 1.5;
        alpha = waterSurfaceAlpha(trans, fres);
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
