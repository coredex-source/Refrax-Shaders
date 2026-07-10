/* Refrax — program/composite0.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/water.glsl"
#include "/lib/shadows.glsl"
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
*/
const bool colortex5Clear = false;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D depthtex0, depthtex1;
#ifdef LPV_FOG
  #ifdef COLORED_LIGHTING
    uniform sampler3D lpvSampler1;
  #endif
#endif
uniform sampler2D shadowtex0, shadowtex1, shadowcolor0;
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
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

    vec4 waterData = texture(colortex2, suv);
    bool isWater = waterData.a > 1.5 && waterData.a < 2.5 && depth1 > depth0;
    if (isWater) {
        vec3 wn = normalize(waterData.rgb);
        vec3 frontView = screenToView(vec3(uv, depth0), gbufferProjectionInverse);
        vec3 backView = screenToView(vec3(uv, depth1), gbufferProjectionInverse);
        float viewDist = length(frontView);
        float layerDist = abs(length(backView) - viewDist);
        vec2 ruv = suv + wn.xz * (min(layerDist, 8.0) / max(viewDist, 1.0)) * 0.12 * REFRACTION_INTENSITY;
        if (texture(depthtex1, ruv).r > depth0)
            suv = clamp(ruv, vec2(0.001), vec2(0.999));
        depth0 = texture(depthtex0, suv).r;
    }
    if (isEyeInWater == 1) {
        float eyeSkyPre = float(eyeBrightnessSmooth.y) / 240.0;
        vec2 wave = vec2(
            sin(uv.y * 32.0 + frameTimeCounter * 1.9) + sin(uv.y * 13.0 - frameTimeCounter * 1.2),
            cos(uv.x * 29.0 + frameTimeCounter * 1.6) + cos(uv.x * 11.0 + frameTimeCounter * 1.1)
        );
        suv = clamp(suv + wave * (0.0014 + 0.0007 * eyeSkyPre) * UNDERWATER_DISTORTION, vec2(0.001), vec2(0.999));
        depth0 = texture(depthtex0, suv).r;
    }
#ifdef UPSCALING
    vec4 c0 = sampleSceneScaled(suv, 1.0 / vec2(viewWidth, viewHeight));
#else
    vec4 c0 = texture(colortex0, suv);
#endif
    vec3 color = c0.rgb;

    vec3 viewPos = screenToView(vec3(uv, depth0), gbufferProjectionInverse);
    vec3 scenePos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    float dist = length(scenePos);
    vec3 dirW = scenePos / max(dist, 1e-4);
    vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float dither = ignAnim(gl_FragCoord.xy, frameCounter);
    float skyMask = depth0 >= 1.0 ? 1.0 : 0.0;
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

        float shallow = (1.0 - skyMask) * (1.0 - saturate(d / 30.0)) * eyeSky * (1.0 - rainStrength * 0.45);
        float caustic = sin(scenePos.x * 0.74 + frameTimeCounter * 1.4) * sin(scenePos.z * 0.53 - frameTimeCounter * 1.1);
        caustic = pow(saturate(caustic * 0.5 + 0.5), 6.0) * shallow;

        float localContrast = mix(0.56, 0.86, eyeSky) * (1.0 - fogAmt * 0.18);
        color = color * transmittance * vec3(0.54, 0.68, 1.02) * localContrast + scatter * (fogAmt * 0.40);
        color += fogCol * caustic * 0.055;
        if (skyMask > 0.5) color = mix(color, fogCol * (0.26 + lightBeam * 0.38 + upView * eyeSky * 0.12), 0.46);
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
        float border = smoothstep(far * 0.7, far * 0.95, dist);
        color = mix(color, fogCol, saturate(max(fogAmt, border)));
    }

    if (blindness > 0.0)
        color *= exp(-dist * blindness * 0.3);

    outColor = vec4(color, c0.a);
}
