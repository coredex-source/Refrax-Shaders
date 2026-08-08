/* Refrax — program/deferred0.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/clouds.glsl"
#include "/lib/dh.glsl"

#if CLOUD_MODE > 0 && !defined WORLD_NETHER && !defined WORLD_END
  #define REFRAX_CLOUDS_ACTIVE
  #if CLOUD_TEMPORAL > 1 && CLOUD_MODE == 2
    #define REFRAX_CLOUD_TEMPORAL
  #endif
#endif

uniform sampler2D depthtex0;
#ifdef REFRAX_CLOUD_TEMPORAL
uniform sampler2D colortex13;
uniform sampler2D colortex14;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;
uniform vec3 previousCameraPosition;
#endif
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform float frameTimeCounter, rainStrength, viewWidth, viewHeight;
uniform int frameCounter;

in vec2 uv;

#ifdef REFRAX_CLOUD_TEMPORAL
/* RENDERTARGETS: 13,14 */
layout(location = 0) out vec4 outClouds;
layout(location = 1) out vec4 outCloudValid;
#else
/* RENDERTARGETS: 13 */
layout(location = 0) out vec4 outClouds;
#endif

#ifdef REFRAX_CLOUD_TEMPORAL
bool cloudHistory(vec3 dirW, vec2 texel, out vec4 hist) {
    hist = vec4(0.0, 0.0, 0.0, 1.0);
    if (abs(dirW.y) < 0.002) return false;

    float tMid = (CU_BOTTOM + CLOUD_THICKNESS * 0.5 - cameraPosition.y) / dirW.y;
    if (tMid <= 0.0 || tMid > CLOUD_FADE_DIST) return false;

    vec3 prev = reprojectScene(dirW * tMid, gbufferPreviousModelView, gbufferPreviousProjection, cameraPosition, previousCameraPosition);
    if (clamp(prev.xy, 0.0, 1.0) != prev.xy) return false;

    vec2 huv = cloudRegionUV(prev.xy, texel);
    if (texture(colortex14, huv).r < 0.99) return false;

    vec4 h = texture(colortex13, huv);
    float s = dot(h.rgb, vec3(1.0));
    if (!(h.a >= 0.0 && h.a <= 1.0 && s >= 0.0 && s < 1e5)) return false;

    hist = h;
    return true;
}
#endif

void main() {
    float depth = texture(depthtex0, uv).r;
    float dither = ignAnim(gl_FragCoord.xy, frameCounter);
    vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);
    float cloudValid = 0.0;

#ifdef REFRAX_CLOUDS_ACTIVE
  #if CLOUD_RES > 1
    vec2 dil = 2.0 / vec2(viewWidth, viewHeight);
    bool skyHere = depth >= 1.0
        || texture(depthtex0, clamp(uv + dil, vec2(0.0), vec2(1.0))).r >= 1.0
        || texture(depthtex0, clamp(uv - dil, vec2(0.0), vec2(1.0))).r >= 1.0
        || texture(depthtex0, clamp(uv + vec2(dil.x, -dil.y), vec2(0.0), vec2(1.0))).r >= 1.0
        || texture(depthtex0, clamp(uv + vec2(-dil.x, dil.y), vec2(0.0), vec2(1.0))).r >= 1.0;
  #else
    bool skyHere = depth >= 1.0;
  #endif
    if (skyHere) {
        cloudValid = 1.0;
        float cloudMaxDist = 1e9;
  #ifdef LOD_ACTIVE
        float lodDepth = texture(lodDepthTex1, uv).r;
        if (lodDepth < 1.0)
            cloudMaxDist = length(screenToView(vec3(uv, lodDepth), lodProjectionInverse));
  #endif
        vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
        vec3 viewDir = normalize(screenToView(vec3(uv, 1.0), gbufferProjectionInverse));
        vec3 dirW = normalize(mat3(gbufferModelViewInverse) * viewDir);

        bool march = true;
  #ifdef REFRAX_CLOUD_TEMPORAL
        ivec2 px = ivec2(gl_FragCoord.xy);
    #if CLOUD_TEMPORAL == 2
        int slot = (px.x + px.y) & 1;
        int activeSlot = frameCounter & 1;
    #else
        int slot = (px.x & 1) + 2 * (px.y & 1);
        const int order[4] = int[4](0, 3, 1, 2);
        int activeSlot = order[frameCounter & 3];
    #endif
        vec4 hist;
        if (slot != activeSlot && cloudHistory(dirW, 1.0 / vec2(viewWidth, viewHeight), hist)) {
            clouds = hist;
            march = false;
        }
  #endif
        if (march) {
  #if CLOUD_MODE == 2
            clouds = volumetricClouds(cameraPosition, dirW, sunDir, frameTimeCounter, rainStrength, dither, cloudMaxDist);
  #else
            clouds = clouds2D(cameraPosition, dirW, sunDir, frameTimeCounter, rainStrength, cloudMaxDist);
  #endif
        }
    }
#endif

    outClouds = clouds;
#ifdef REFRAX_CLOUD_TEMPORAL
    outCloudValid = vec4(cloudValid, 0.0, 0.0, 1.0);
#endif
}
