/* Refrax — program/composite0.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/water.glsl"
#include "/lib/shadows.glsl"
#include "/lib/dh.glsl"
#ifdef UNDERWATER_MOTES
  #include "/lib/underwater.glsl"
#endif
#ifdef LPV_FOG
  #ifdef COLORED_LIGHTING
    #include "/lib/voxel.glsl"
  #endif
#endif

/* ---- Buffer formats ----
const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA8;
const int colortex2Format = RGBA16F;
const int colortex3Format = RGBA8;
const int colortex4Format = RGBA16F;
const int colortex5Format = RGBA16F;
const int colortex6Format = R8;
const int colortex8Format = RGBA16F;
const int colortex9Format = RGBA16F;
*/
const bool colortex5Clear = false;
const bool colortex9Clear = true;
const vec4 colortex9ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

uniform sampler2D colortex0;
uniform sampler2D colortex2;
#if MC_VERSION >= 260100
uniform sampler2D colortex7;
#endif
#ifdef VOXY
uniform sampler2D colortex9;
#endif
uniform sampler2D depthtex0, depthtex1;
#ifdef LPV_FOG
  #ifdef COLORED_LIGHTING
    uniform sampler3D lpvSampler1;
  #endif
#endif
uniform sampler2D shadowtex0, shadowtex1, shadowcolor0;
uniform mat4 gbufferModelView, gbufferModelViewInverse, gbufferProjection, gbufferProjectionInverse;
uniform mat4 shadowModelView, shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec3 fogColor;
uniform float frameTimeCounter, rainStrength, viewWidth, viewHeight, far, blindness;
uniform int frameCounter, isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

in vec2 uv;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

#ifdef UPSCALING
vec4 sampleSceneScaled(vec2 suv, vec2 px) {
    vec2 r = px * (0.5 * max(1.0 / UPSCALE_SCALE - 1.0, 0.0));
    return 0.25 * (texture(colortex0, suv + vec2(-r.x, -r.y)) +
                   texture(colortex0, suv + vec2( r.x, -r.y)) +
                   texture(colortex0, suv + vec2(-r.x,  r.y)) +
                   texture(colortex0, suv + vec2( r.x,  r.y)));
}
#endif

void main() {
    vec2 suv = uv;
    float depth0 = texture(depthtex0, suv).r;
    float depth1 = texture(depthtex1, suv).r;
#ifdef LOD_ACTIVE
    float lodDepth0 = texture(lodDepthTex0, suv).r;
#endif

    vec4 waterData = texture(colortex2, suv);
    bool waterMask = waterData.a > 1.5 && waterData.a < 2.5;
#ifdef VOXY
    vec4 voxyWaterData = texture(colortex9, suv);
    bool voxyWaterMask = voxyWaterData.a > 1.5 && voxyWaterData.a < 2.5;
    if (voxyWaterMask) waterData = voxyWaterData;
    waterMask = waterMask || voxyWaterMask;
#endif
    bool isWater = waterMask && depth1 > depth0;
    bool lodWater = false;
#ifdef LOD_ACTIVE
    lodWater = waterMask && !isWater && depth0 >= 1.0 && texture(lodDepthTex1, suv).r > lodDepth0;
#endif
    if (isWater || lodWater) {
        vec3 wn = normalize(waterData.rgb);
#ifdef LOD_ACTIVE
        vec3 frontView = lodWater ? screenToView(vec3(uv, lodDepth0), lodProjectionInverse)
                                  : screenToView(vec3(uv, depth0), gbufferProjectionInverse);
#else
        vec3 frontView = screenToView(vec3(uv, depth0), gbufferProjectionInverse);
#endif
        vec3 viewNormal = normalize(mat3(gbufferModelView) * wn);
        vec2 projScale = vec2(gbufferProjection[0][0], gbufferProjection[1][1]) * 0.5;
        vec2 ruv = suv + waterRefractOffset(frontView, viewNormal, projScale);
        bool refrClear = texture(depthtex1, ruv).r > depth0
                      && texture(depthtex0, ruv).r >= HAND_DEPTH_LIMIT;
#ifdef LOD_ACTIVE
        if (lodWater) refrClear = texture(depthtex1, ruv).r >= 1.0 && texture(lodDepthTex1, ruv).r > lodDepth0;
#endif
#if MC_VERSION >= 260100
        refrClear = refrClear && texture(colortex7, suv).a < 0.001 && texture(colortex7, ruv).a < 0.001;
#endif
        if (refrClear)
            suv = clamp(ruv, vec2(0.001), vec2(0.999));
        depth0 = texture(depthtex0, suv).r;
#ifdef LOD_ACTIVE
        lodDepth0 = texture(lodDepthTex0, suv).r;
#endif
    }
    if (isEyeInWater == 1) {
        float eyeSkyPre = float(eyeBrightnessSmooth.y) / 240.0;
        vec2 p = uv * vec2(viewWidth / max(viewHeight, 1.0), 1.0);
        float t = frameTimeCounter;
        vec2 wave = vec2(
            sin(p.y * 58.0 + p.x * 19.0 + t * 2.3) + 0.5 * sin(p.y * 121.0 - p.x * 37.0 - t * 3.1),
            cos(p.x * 54.0 - p.y * 23.0 + t * 2.0) + 0.5 * cos(p.x * 113.0 + p.y * 41.0 - t * 2.7)
        );
        suv = clamp(suv + wave * (0.00055 + 0.00030 * eyeSkyPre) * UNDERWATER_DISTORTION, vec2(0.001), vec2(0.999));
        depth0 = texture(depthtex0, suv).r;
#ifdef LOD_ACTIVE
        lodDepth0 = texture(lodDepthTex0, suv).r;
#endif
    }
#ifdef UPSCALING
    vec4 c0 = sampleSceneScaled(suv, 1.0 / vec2(viewWidth, viewHeight));
#else
    vec4 c0 = texture(colortex0, suv);
#endif
    vec3 color = c0.rgb;

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
    float dither = ignAnim(gl_FragCoord.xy, frameCounter);
    float fogDist = mix(dist, far, skyMask);

#ifdef GOD_RAYS
#ifndef WORLD_NETHER
    {
  #ifdef WORLD_END
        vec3 vlCol = vec3(0.22, 0.19, 0.30) * (1.0 - skyMask);
  #else
        vec3 vlCol = sunColor(sunDir.y) + moonColor(-sunDir.y) * 2.0;
  #endif
        if (luminance(vlCol) > 0.002) {
            int steps = PERF_SCALED_COUNT(VL_STEPS, 3);
            float maxD = min(fogDist, VL_DISTANCE);
            float dt = maxD / float(steps);
            vec3 accum = vec3(0.0);
            for (int i = 0; i < steps; i++) {
                vec3 p = dirW * (dt * (float(i) + dither));
                vec4 sclip = shadowProjection * (shadowModelView * vec4(p, 1.0));
                vec3 sp = distortShadowClip(sclip.xyz / sclip.w) * 0.5 + 0.5;
                float s = 1.0;
                if (clamp(sp.xy, 0.0, 1.0) == sp.xy)
                    s = step(sp.z - 0.0004, texture(shadowtex1, sp.xy).r);
                accum += vec3(s);
            }
            float phase = pow(saturate(dot(dirW, lightDir)), 5.0) * 0.75 + 0.12;
            float media = isEyeInWater == 1 ? 0.05 : 0.006 * (1.0 + rainStrength * 2.0);
            color += (accum / float(steps)) * vlCol * phase * media * maxD * VL_STRENGTH * (isEyeInWater == 1 ? WATER_COLOR * 3.0 : vec3(1.0));
        }
    }
#endif
#endif

#ifdef LPV_FOG
  #ifdef COLORED_LIGHTING
    {
        int steps = PERF_SCALED_COUNT(12, 4);
        float maxD = min(fogDist, LPV_FOG_DISTANCE);
        float dt = maxD / float(steps);
        vec3 glow = vec3(0.0);
        for (int i = 0; i < steps; i++) {
            vec3 p = dirW * (dt * (float(i) + dither));
            float fade;
            glow += sampleLPV(lpvSampler1, p, cameraPosition, vec3(0.0), fade) * fade;
        }
        float media = LPV_FOG_DENSITY * (1.0 + rainStrength) * LPV_FOG_STRENGTH;
#ifdef WORLD_NETHER
        media *= 0.5;
#endif
        color += (glow / float(steps)) * maxD * media;
    }
  #endif
#endif

    if (isEyeInWater == 1) {
        float eyeSky = float(eyeBrightnessSmooth.y) / 240.0;
        float d = max(fogDist, 1.0);
        vec3 fogCol = underwaterFogTint(fogColor, sunDir, eyeSky, rainStrength);
        vec3 transmittance = exp(-(WATER_ABSORB * WATER_ABSORPTION * vec3(0.55, 0.72, 1.05) + vec3(WATER_SCATTER * 0.22 + 0.004)) * d);
        float fogRange = mix(34.0, 58.0, eyeSky) / max(WATER_ABSORPTION, 0.25);
        float fogCurve = d / fogRange;
        float fogAmt = 1.0 - exp(-fogCurve * fogCurve);

        float upView = saturate(dirW.y * 0.5 + 0.5);
        float lightBeam = pow(saturate(dot(dirW, lightDir)), 7.0) * eyeSky * (1.0 - rainStrength * 0.65);
        vec3 ambient = skyAmbient(sunDir, rainStrength) * (0.06 + eyeSky * 0.24) + vec3(0.002, 0.004, 0.007);
        vec3 scatter = fogCol * (0.18 + upView * eyeSky * 0.18 + lightBeam * 0.54) + ambient * 0.10;

        float localContrast = mix(0.56, 0.86, eyeSky) * (1.0 - fogAmt * 0.18);
        color = color * transmittance * vec3(0.54, 0.68, 1.02) * localContrast + scatter * (fogAmt * 0.40);
        if (skyMask > 0.5) color = mix(color, fogCol * (0.26 + lightBeam * 0.38 + upView * eyeSky * 0.12), 0.46);

#ifdef UNDERWATER_MOTES
  #ifdef WORLD_END
        vec3 moteLight = endLightColor();
  #else
        vec3 moteLight = sunColor(sunDir.y) + moonColor(-sunDir.y);
  #endif
        color += underwaterMotes(shadowtex1, dirW, cameraPosition, min(dist, MOTE_DISTANCE),
                                 frameTimeCounter, dither, shadowModelView, shadowProjection,
                                 moteLight, eyeSky) * MOTE_STRENGTH;
#endif
    } else if (skyMask < 0.5) {
#if defined WORLD_NETHER
        vec3 fogCol = netherSky(dirW, fogColor, frameTimeCounter);
        float fogAmt = 1.0 - exp(-fogDist * FOG_BASE * 6.0 * FOG_DENSITY);
#elif defined WORLD_END
        vec3 fogCol = endFogColor() * 1.6;
        float fogAmt = 1.0 - exp(-fogDist * FOG_BASE * 8.0 * FOG_DENSITY);
#else
        vec3 fogCol = skyGradient(dirW, sunDir, rainStrength);
        float hFall = exp(-max(cameraPosition.y + scenePos.y * 0.5 - 64.0, 0.0) * FOG_HEIGHT_FALLOFF);
        float density = FOG_BASE * FOG_DENSITY * (1.0 + rainStrength * 3.0) * hFall;
        float fogAmt = 1.0 - exp(-fogDist * density);
#endif
#ifdef LOD_ACTIVE
        // LOD terrain continues past the far plane: no border fade, and the
        // fog never fully swallows distant silhouettes.
        float border = 0.0;
        fogAmt = min(fogAmt, 0.90);
#else
        float border = smoothstep(far * 0.7, far * 0.95, dist);
#endif
        color = mix(color, fogCol, saturate(max(fogAmt, border)));
    }

    if (blindness > 0.0)
        color *= exp(-dist * blindness * 0.3);

    outColor = vec4(color, c0.a);
}
