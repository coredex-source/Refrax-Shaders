/* Refrax — program/voxy_translucent.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/noise.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/water.glsl"

layout(location = 0) out vec4 outLayer;
layout(location = 1) out vec4 outWaterData;

#ifdef WORLD_NETHER
const vec3 VOXY_NETHER_FOG = vec3(0.23, 0.08, 0.05);
#endif

void voxy_emitFragment(VoxyFragmentParameters p) {
    vec2 suv = gl_FragCoord.xy / refraxViewSize;
    mat4 projInv = mat4(refraxVxProjInv0, refraxVxProjInv1,
                        refraxVxProjInv2, refraxVxProjInv3);
    mat4 modelViewInv = mat4(refraxModelViewInv0, refraxModelViewInv1,
                             refraxModelViewInv2, refraxModelViewInv3);
    vec4 v = projInv * vec4(suv * 2.0 - 1.0, gl_FragCoord.z * 2.0 - 1.0, 1.0);
    if (abs(v.w) < 1e-8) {
        outLayer = vec4(0.0);
        outWaterData = vec4(0.0);
        return;
    }
    vec3 viewPos = v.xyz / v.w;
    vec3 scenePos = (modelViewInv * vec4(viewPos, 1.0)).xyz;
    float dist = length(scenePos);

    vec4 base = p.sampledColour * p.tinting;
    vec3 tint = p.tinting.rgb;
    vec2 lm = saturate(p.lightMap);
    bool water = int(p.customId) == 10061;

    int axis = int(p.face) >> 1;
    vec3 N = vec3(float(axis == 2), float(axis == 0), float(axis == 1))
           * (float(int(p.face) & 1) * 2.0 - 1.0);

    vec3 sunDir = normalize(refraxSunDir);
    vec3 lightDir = normalize(refraxLightDir);
    vec3 viewDirW = normalize(-scenePos);
    vec3 worldPos = scenePos + refraxCameraPosition;
    vec3 geomN = N;
    float waterRoughness = WATER_ROUGHNESS;
    float waterCrest = 0.0;
    float waterFlow = 0.0;
    float waterFootprint = clamp(dist * 0.0025, 0.015, 2.0);

    if (water && N.y > 0.5) {
        float vDot = abs(dot(N, viewDirW));
        vec2 drift = vec2(0.0);
        N = waterSurfaceNormalFlow(noisetex, worldPos, drift, refraxFrameTimeCounter, vDot, lm.y, rainStrength, waterFlow, waterFootprint, waterRoughness, waterCrest);
    }
#ifdef WATER_FLOW
    else if (water && abs(N.y) < 0.5) {
        waterFlow = 1.0;
        N = waterfallSurfaceNormal(noisetex, worldPos, N, refraxFrameTimeCounter, lm.y, rainStrength, waterFlow, waterFootprint, waterRoughness, waterCrest);
    }
#endif

    float NoL = saturate(dot(N, lightDir));
#if defined WORLD_NETHER
    vec3 lightCol = vec3(0.0);
    vec3 shadow = vec3(0.0);
    float facing = netherFacing(N);
    vec3 skyLight = netherAmbient(N, VOXY_NETHER_FOG) * facing;
#elif defined WORLD_END
    vec3 lightCol = endLightColor();
    vec3 shadow = vec3(0.75);
    vec3 skyLight = endAmbient(N);
#else
    vec3 lightCol = (sunColor(sunDir.y) + moonColor(-sunDir.y)) * (1.0 - rainStrength * 0.9);
    vec3 shadow = vec3(pow(lm.y, 4.0));
    vec3 skyLight = skyAmbientDirectional(N, sunDir, rainStrength) * pow(lm.y, 2.2);
    skyLight += lightCol * 0.05 * saturate(0.6 - 0.4 * N.y) * pow(lm.y, 2.2);
#endif
    vec3 blockLight = FALLBACK_BLOCKLIGHT * pow(lm.x, 3.0) * 1.85;
#ifdef WORLD_NETHER
    blockLight *= NETHER_FALLBACK_SCALE * facing;
#endif
    vec3 minAmb = vec3(0.010, 0.011, 0.014) * MIN_AMBIENT;

    float fres = water ? waterFresnel(dot(viewDirW, N)) : fresnelSchlick(saturate(dot(viewDirW, N)), vec3(0.02)).x;
    vec3 reflDirW = water ? waterReflectionDirection(viewDirW, N) : reflect(-viewDirW, N);
#if defined WORLD_NETHER
    vec3 refl = dimensionSky(reflDirW, sunDir, VOXY_NETHER_FOG, refraxFrameTimeCounter, rainStrength);
#elif defined WORLD_END
    vec3 refl = dimensionSky(reflDirW, sunDir, vec3(0.0), refraxFrameTimeCounter, rainStrength);
#else
    vec3 refl = skyGradient(reflDirW, sunDir, rainStrength) * mix(0.08, 1.0, lm.y * lm.y);
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
        float dBack = texelFetch(vxDepthTexOpaque, ivec2(gl_FragCoord.xy), 0).r;
        vec3 backView = screenToView(vec3(suv, dBack), projInv);
        float waterDepth = max(length(backView) - dist, 0.0);
        vec3 trans = waterTransmittanceTinted(tint, waterDepth);

        vec3 bodyLighting = lightCol * NoL * shadow * 0.22 + skyLight * 0.92 + blockLight * 0.52;
        vec3 body = waterBodyColor(tint, trans, bodyLighting);
        lit = mix(body, refl, fres) + sunSpec;
        alpha = waterSurfaceAlpha(trans, fres);
#ifdef WATER_FOAM
        float waterSlope = geomN.y > 0.5 ? length(N.xz) / max(N.y, 0.1) : 0.0;
        float foam = waterFoamMask(noisetex, worldPos.xz, refraxFrameTimeCounter, waterDepth, waterCrest, waterSlope, rainStrength, waterFlow);
        if (foam > 0.001) {
            vec3 foamCol = (skyLight + lightCol * shadow * 0.35) * vec3(0.98, 1.02, 1.08);
            lit = mix(lit, foamCol, foam);
            alpha = max(alpha, foam * 0.92);
        }
#endif
        outWaterData = vec4(N, 2.0);
    } else {
        vec3 albedo = srgbToLinear(base.rgb);
        lit = albedo * (lightCol * NoL * shadow + skyLight + blockLight + minAmb);
        lit += refl * fres * 0.8 + sunSpec * 0.5;
        alpha = max(base.a, fres * 0.5);
        outWaterData = vec4(0.0);
    }

    outLayer = vec4(lit * alpha, alpha);
}
