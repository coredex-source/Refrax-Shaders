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

    if (water && N.y > 0.5) {
        vec3 worldPos = scenePos + refraxCameraPosition;
        float vDot = abs(dot(N, viewDirW));
        N = waterNormal(noisetex, worldPos.xz, refraxFrameTimeCounter, vDot, lm.y, rainStrength, dist);
    }

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
    vec3 reflDirW = reflect(-viewDirW, N);
#if defined WORLD_NETHER
    vec3 refl = dimensionSky(reflDirW, sunDir, VOXY_NETHER_FOG, refraxFrameTimeCounter, rainStrength);
#elif defined WORLD_END
    vec3 refl = dimensionSky(reflDirW, sunDir, vec3(0.0), refraxFrameTimeCounter, rainStrength);
#else
    vec3 refl = skyGradient(reflDirW, sunDir, rainStrength) * mix(0.08, 1.0, lm.y * lm.y);
#endif

    float glintRough = water ? WATER_ROUGHNESS + saturate(dist / 96.0) * 0.018 : 0.03;
    vec3 sunSpecShape = water
        ? waterDiscLightSpecular(N, viewDirW, lightDir, SUN_GLINT_RADIUS, glintRough, vec3(0.02))
        : discLightSpecular(N, viewDirW, lightDir, SUN_GLINT_RADIUS, glintRough, vec3(0.02));
    vec3 sunSpec = sunSpecShape * lightCol * shadow * (water ? SUN_GLINT_STRENGTH : PBR_GLINT_STRENGTH);

    vec3 lit;
    float alpha;
    if (water) {
        float dBack = texelFetch(vxDepthTexOpaque, ivec2(gl_FragCoord.xy), 0).r;
        vec3 backView = screenToView(vec3(suv, dBack), projInv);
        float waterDepth = max(length(backView) - dist, 0.0);
        vec3 trans = waterTransmittanceTinted(tint, waterDepth);

        vec3 scatter = mix(WATER_COLOR * WATER_COLOR, srgbToLinear(tint) * 0.20, 0.25) * 0.80;
        vec3 body = scatter * (lightCol * NoL * shadow * 0.22 + skyLight * 0.92 + blockLight * 0.52);
        body = mix(body, body * 0.42, saturate(1.0 - trans.g));
        lit = mix(body, refl, fres) + sunSpec * 1.5;
        alpha = waterSurfaceAlpha(trans, fres);
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
