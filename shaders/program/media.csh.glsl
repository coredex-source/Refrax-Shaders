/* Refrax — program/media.csh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/clouds.glsl"
#include "/lib/water.glsl"
#include "/lib/shadows.glsl"
#include "/lib/dh.glsl"
#ifdef LPV_FOG
  #ifdef COLORED_LIGHTING
    #include "/lib/voxel.glsl"
  #endif
#endif

layout(local_size_x = 16, local_size_y = 16) in;
const vec2 workGroupsRender = vec2(0.5f, 0.5f);

layout(rgba16f) writeonly uniform image2D refraxMediaImg;

uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0, shadowtex1, shadowcolor0;
#ifdef LPV_FOG
  #ifdef COLORED_LIGHTING
    uniform sampler3D lpvSampler1;
  #endif
#endif
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform mat4 shadowModelView, shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform float frameTimeCounter, rainStrength, viewWidth, viewHeight, far;
uniform int frameCounter, isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
uniform float refraxBiomeTemp, refraxBiomeHumid, refraxBiomeSwamp, refraxBiomeAlpine;

void main() {
    ivec2 px = ivec2(gl_GlobalInvocationID.xy);
    ivec2 res = ivec2(ceil(vec2(viewWidth, viewHeight) * 0.5));
    if (px.x >= res.x || px.y >= res.y) return;

    vec2 uv = (vec2(px) + 0.5) / vec2(res);

    float depth0 = texture(depthtex0, uv).r;
#ifdef LOD_ACTIVE
    float lodDepth0 = texture(lodDepthTex0, uv).r;
#endif

    vec3 viewPos = screenToView(vec3(uv, depth0), gbufferProjectionInverse);
    float skyMask = depth0 >= 1.0 ? 1.0 : 0.0;
#ifdef LOD_ACTIVE
    if (depth0 >= 1.0 && lodDepth0 < 1.0) {
        viewPos = screenToView(vec3(uv, lodDepth0), lodProjectionInverse);
        skyMask = 0.0;
    }
#endif
    vec3 scenePos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    float dist = length(scenePos);
    vec3 dirW = scenePos / max(dist, 1e-4);
    vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float dither = ignAnim(vec2(px), frameCounter);
    float fogDist = mix(dist, far, skyMask);
    BiomeAtmos biome = biomeAtmos(refraxBiomeTemp, refraxBiomeHumid, refraxBiomeSwamp, refraxBiomeAlpine);

    vec3 scatter = vec3(0.0);

#ifdef GOD_RAYS
#ifndef WORLD_NETHER
    {
  #ifdef WORLD_END
        vec3 vlCol = (endLightColor() * 0.30 + endAmbient(vec3(0.0, 1.0, 0.0)) * 4.0)
                   * (1.0 - skyMask);
  #else
        vec3 vlCol = sunColor(sunDir.y) + moonColor(-sunDir.y) * 2.0;
  #endif
        if (luminance(vlCol) > 0.002) {
            int steps = PERF_SCALED_COUNT(VL_STEPS, 3);
            float maxD = min(fogDist, VL_DISTANCE);
#if defined CLOUD_SHADOWS && !defined WORLD_END
            vlCol *= cloudShadow(cameraPosition + dirW * (maxD * 0.5), cameraPosition, lightDir, frameTimeCounter, rainStrength);
#endif
            vec3 accum = vec3(0.0);
            bool submergedRays = isEyeInWater == 1;
#ifdef UNDERWATER_RAYS
            float rayTime = frameTimeCounter * WAVE_SPEED;
#endif
            for (int i = 0; i < steps; i++) {
                float u = max((float(i) + dither) / float(steps), 1e-4);
                float ub = pow(u, VL_NEAR_BIAS);
                float weight = VL_NEAR_BIAS * ub / u;
                vec3 p = dirW * (maxD * ub);
                vec4 sclip = shadowProjection * (shadowModelView * vec4(p, 1.0));
                vec3 sp = distortShadowClip(sclip.xyz / sclip.w) * 0.5 + 0.5;
                vec3 s = vec3(1.0);
                if (clamp(sp.xy, 0.0, 1.0) == sp.xy) {
                    float z = sp.z - 0.0004;
                    float lit = step(z, textureLod(shadowtex1, sp.xy, 0.0).r);
                    s = vec3(lit);
#ifdef VL_SHAFT_TINT_ACTIVE
                    if (!submergedRays && lit > 0.0) {
                        float litT = step(z, textureLod(shadowtex0, sp.xy, 0.0).r);
                        if (litT < 1.0)
                            s *= min(textureLod(shadowcolor0, sp.xy, 0.0).rgb / SHADOW_COLOR_ENCODE, vec3(VL_SHAFT_TINT_CLAMP));
                    }
#endif
                }
#ifdef UNDERWATER_RAYS
                if (submergedRays)
                    s *= 0.30 + 1.55 * waterDetailField(noisetex,
                        (cameraPosition + p).xz + lightDir.xz * 5.0, rayTime);
#endif
                accum += s * weight;
            }
            float lobe = saturate(dot(dirW, lightDir));
            float phase = pow(lobe, 5.0) * 0.75 + 0.12;
            float media = isEyeInWater == 1 ? 0.05 : 0.006 * (1.0 + rainStrength * 2.0) * mix(1.0, biome.haze, 0.6);
#ifdef UNDERWATER_RAYS
            if (submergedRays) {
                phase = pow(lobe, 9.0) * 1.30 + 0.10;
                media *= 0.30 + 0.70 * (float(eyeBrightnessSmooth.y) / 240.0);
            }
#endif
            scatter += (accum / float(steps)) * vlCol * phase * media * maxD * VL_STRENGTH * (isEyeInWater == 1 ? WATER_COLOR * 3.0 : vec3(1.0));

#ifdef CLOUD_RAYS_ACTIVE
            if (isEyeInWater != 1 && lightDir.y > 0.06) {
                float farD = skyMask > 0.5 ? CLOUD_RAY_DISTANCE : min(dist, CLOUD_RAY_DISTANCE);
                float seg = farD - maxD;
                if (seg > 0.5) {
                    int csteps = PERF_SCALED_COUNT(CLOUD_RAY_STEPS, 4);
                    vec2 rayWind = cloudWind(frameTimeCounter);
                    float rayBias = cloudDailyBias();
                    float cdt = seg / float(csteps);
                    float cacc = 0.0;
                    for (int i = 0; i < csteps; i++) {
                        vec3 p = dirW * (maxD + cdt * (float(i) + dither));
                        cacc += cloudShadowSlice(cameraPosition + p, lightDir, rayWind, rainStrength, rayBias, CLOUD_RAY_STRENGTH);
                    }
                    scatter += (cacc / float(csteps)) * vlCol * phase * media * min(seg, maxD) * VL_STRENGTH * CLOUD_RAY_GAIN;
                }
            }
#endif
        }
    }
#endif
#endif

#ifdef LPV_FOG
  #ifdef COLORED_LIGHTING
    {
#ifdef WORLD_NETHER
        int steps = PERF_SCALED_COUNT(NETHER_VL_STEPS, 6);
        float maxD = min(fogDist, NETHER_VL_DISTANCE);
        float media = LPV_FOG_DENSITY * LPV_FOG_STRENGTH * NETHER_FOG_GLOW;
#else
        int steps = PERF_SCALED_COUNT(12, 4);
        float maxD = min(fogDist, LPV_FOG_DISTANCE);
        float media = LPV_FOG_DENSITY * (1.0 + rainStrength) * LPV_FOG_STRENGTH;
#endif
        float dt = maxD / float(steps);
        vec3 glow = vec3(0.0);
        for (int i = 0; i < steps; i++) {
            vec3 p = dirW * (dt * (float(i) + dither));
            float fade;
            glow += sampleLPVFog(lpvSampler1, p, cameraPosition, fade) * fade;
        }
        scatter += (glow / float(steps)) * maxD * media;
    }
  #endif
#endif

    imageStore(refraxMediaImg, px, vec4(scatter, 1.0));
}
