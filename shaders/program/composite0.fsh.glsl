/* Refrax — program/composite0.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/clouds.glsl"
#include "/lib/water.glsl"
#include "/lib/shadows.glsl"
#include "/lib/dh.glsl"
#if HIZ_DEBUG > 0
  #define HIZ_READ
  #include "/lib/hiz.glsl"
#endif
#include "/lib/thunder.glsl"
#if defined UNDERWATER_MOTES || defined UNDERWATER_BUBBLES
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
const int colortex2Format = RGB10_A2;
const int colortex3Format = RGBA8;
const int colortex4Format = R11F_G11F_B10F;
const int colortex5Format = RGBA16F;
const int colortex6Format = R8;
const int colortex8Format = RGBA16F;
const int colortex9Format = RGB10_A2;
const int colortex10Format = RGBA8;
const int colortex11Format = R8;
const int colortex12Format = RGBA16F;
const int colortex13Format = RGBA16F;
const int colortex14Format = R8;
const int colortex15Format = RGBA16F;
*/
const bool colortex5Clear = false;
const bool colortex12Clear = false;
const bool colortex13Clear = false;
const bool colortex14Clear = false;
#ifdef SSR_ACCUM_ACTIVE
const bool colortex15Clear = false;
#endif
const bool colortex9Clear = true;
const vec4 colortex9ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

uniform sampler2D noisetex;
uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex11;
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
uniform float refraxSnowBiome;
uniform float refraxBiomeTemp, refraxBiomeHumid, refraxBiomeSwamp, refraxBiomeAlpine;
#ifdef THUNDER_ACTIVE
uniform vec4 lightningBoltPosition;
#endif

in vec2 uv;

#ifdef REFRAX_MEDIA_ACTIVE
uniform sampler2D refraxMediaTex;

vec3 mediaScatter(vec2 sceneUV, float centreZ) {
    vec2 res = ceil(vec2(viewWidth, viewHeight) * 0.5);
    vec2 mp = sceneUV * res - 0.5;
    vec2 base = floor(mp);
    vec2 f = mp - base;

    vec3 acc = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < 4; i++) {
        vec2 o = vec2(float(i & 1), float(i >> 1));
        ivec2 t = clamp(ivec2(base + o), ivec2(0), ivec2(res) - 1);
        vec2 tUV = (vec2(t) + 0.5) / res;
        float z = screenToView(vec3(tUV, texture(depthtex0, tUV).r), gbufferProjectionInverse).z;
        float w = mix(1.0 - f.x, f.x, o.x) * mix(1.0 - f.y, f.y, o.y)
                * exp2(-abs(z - centreZ) * 0.5) + 1e-5;
        acc += texelFetch(refraxMediaTex, t, 0).rgb * w;
        wsum += w;
    }
    return acc / wsum;
}
#endif


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

#ifdef UPSCALING
vec4 sampleSceneScaled(vec2 suv, vec2 px) {
    vec2 r = px * (0.5 * max(1.0 / UPSCALE_SCALE - 1.0, 0.0));
    return 0.25 * (texture(colortex0, suv + vec2(-r.x, -r.y)) +
                   texture(colortex0, suv + vec2( r.x, -r.y)) +
                   texture(colortex0, suv + vec2(-r.x, r.y)) +
                   texture(colortex0, suv + vec2( r.x, r.y)));
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
    bool waterMask = unpackSurfaceWater(waterData);
#ifdef VOXY
    vec4 voxyWaterData = texture(colortex9, suv);
    bool voxyWaterMask = unpackSurfaceWater(voxyWaterData);
    if (voxyWaterMask) waterData = voxyWaterData;
    waterMask = waterMask || voxyWaterMask;
#endif
    bool isWater = waterMask && depth1 > depth0;
    bool lodWater = false;
#ifdef LOD_ACTIVE
    lodWater = waterMask && !isWater && depth0 >= 1.0 && texture(lodDepthTex1, suv).r > lodDepth0;
#endif
    if (isWater || lodWater) {
        vec3 wn = unpackSurfaceNormal(waterData);
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
    color *= 1.0 - saturate(texture(colortex11, suv).r);

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
    BiomeAtmos biome = biomeAtmos(refraxBiomeTemp, refraxBiomeHumid, refraxBiomeSwamp, refraxBiomeAlpine);

#ifdef REFRAX_MEDIA_ACTIVE
    color += mediaScatter(uv, viewPos.z);
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
#ifdef UNDERWATER_BUBBLES
        color += underwaterBubbles(dirW, cameraPosition, min(dist, BUBBLE_DISTANCE),
                                   frameTimeCounter, dither, lightDir, eyeSky) * BUBBLE_STRENGTH;
#endif
    } else if (skyMask < 0.5) {
#ifdef LOD_ACTIVE
        float border = 0.0;
        float maxOpacity = 0.90;
#else
        float border = smoothstep(far * 0.7, far * 0.95, dist);
        float maxOpacity = 1.0;
#endif

        float snowFall = rainStrength * refraxSnowBiome;
#ifdef ATMOS_AERIAL_ACTIVE
        float lightVis = 1.0;
  #ifdef CLOUD_SHADOWS
        lightVis = cloudShadow(cameraPosition + dirW * (fogDist * 0.5), cameraPosition, lightDir,
                               frameTimeCounter, rainStrength);
  #endif
        AerialResult ap = aerialPerspective(dirW, fogDist, cameraPosition.y + scenePos.y * 0.5, sunDir, lightDir, sunColor(sunDir.y) + moonColor(-sunDir.y), rainStrength, snowFall, lightVis, maxOpacity, biome);
  #ifdef THUNDER_ACTIVE
        ap.inscatter += THUNDER_TINT * (thunderSkyGlow(lightningBoltPosition) * 0.35
                      * (1.0 - luminance(ap.transmittance)));
  #endif
        color = color * ap.transmittance + ap.inscatter;
        if (border > 0.0)
            color = mix(color, skyGradient(dirW, sunDir, rainStrength), border);
#else
  #if defined WORLD_NETHER
        vec3 fogCol = netherFogColor(dirW, fogColor);
        float fogAmt = 1.0 - exp(-fogDist * FOG_BASE * 6.0 * FOG_DENSITY);
  #elif defined WORLD_END
        vec3 fogCol = endFogColor() * 1.6;
        float fogAmt = 1.0 - exp(-fogDist * FOG_BASE * 8.0 * FOG_DENSITY);
  #else
        vec3 fogCol = skyGradient(dirW, sunDir, rainStrength) * biome.tint;
        if (snowFall > 0.001)
            fogCol = mix(fogCol, luminance(fogCol) * vec3(0.92, 0.99, 1.14) * 1.22, saturate(snowFall * SNOW_FOG) * 0.80);
        float hFall = exp(-max(cameraPosition.y + scenePos.y * 0.5 - 64.0, 0.0) * FOG_HEIGHT_FALLOFF);
        float wetFog = rainStrength * FOG_RAIN_DENSITY + snowFall * SNOW_FOG * 0.90;
        float density = FOG_BASE * FOG_DENSITY * (mix(biome.density, 1.0, saturate(rainStrength + snowFall)) + wetFog) * hFall;
        float fogAmt = 1.0 - exp(-fogDist * density);
  #endif
  #ifdef THUNDER_ACTIVE
        fogCol += THUNDER_TINT * (thunderSkyGlow(lightningBoltPosition) * 0.35);
  #endif
        fogAmt = min(fogAmt, maxOpacity);
        color = mix(color, fogCol, saturate(max(fogAmt, border)));
#endif
    }

    if (blindness > 0.0)
        color *= exp(-dist * blindness * 0.3);

    outColor = vec4(color, c0.a);
#if HIZ_DEBUG > 0
    {
        ivec2 full = ivec2(viewWidth, viewHeight);
        vec2 mm = hizFetchUV(full, HIZ_DEBUG, uv);
        float near = 1.0 - pow(mm.x, 64.0);
        float thick = clamp((mm.y - mm.x) * 400.0, 0.0, 1.0);
        outColor = vec4(near, thick, mm.y >= 1.0 ? 1.0 : 0.0, 1.0);
    }
#endif
}
