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
uniform sampler2D colortex2;
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
/* RENDERTARGETS: 13,6,14 */
layout(location = 0) out vec4 outClouds;
layout(location = 1) out vec4 outAO;
layout(location = 2) out vec4 outCloudValid;
#else
/* RENDERTARGETS: 13,6 */
layout(location = 0) out vec4 outClouds;
layout(location = 1) out vec4 outAO;
#endif

float horizonAO(vec3 viewPos, vec3 normalV, float dither) {
    int dirs = max(PERF_SCALED_COUNT(SSAO_SAMPLES, 3) / 2, 2);
    const int STEPS = 4;
    float radius = 0.85;
    float ang = dither * 2.0 * PI;
    float visibility = 0.0;

    for (int d = 0; d < dirs; d++) {
        float theta = ang + float(d) * (PI / float(dirs));
        vec2 dir2 = vec2(cos(theta), sin(theta));

        float maxHorizon = -1.0;
        for (int s = 1; s <= STEPS; s++) {
            float stepFrac = (float(s) - 0.5 * dither) / float(STEPS);
            vec3 sp = viewPos + vec3(dir2 * (radius * stepFrac), 0.0);
            vec3 spScreen = viewToScreen(sp, gbufferProjection);
            if (clamp(spScreen.xy, 0.0, 1.0) != spScreen.xy) break;
            float dep = texture(depthtex0, spScreen.xy).r;
            if (dep >= 1.0) continue;
            vec3 sv = screenToView(vec3(spScreen.xy, dep), gbufferProjectionInverse);

            vec3 delta = sv - viewPos;
            float len = length(delta);
            if (len < 1e-4) continue;

            float atten = 1.0 - saturate(len / radius);
            float horizon = dot(delta / len, normalV) * atten;
            maxHorizon = max(maxHorizon, horizon);
        }
        visibility += 1.0 - saturate(maxHorizon);
    }
    return saturate(visibility / float(dirs));
}

float computeAO(vec3 viewPos, vec3 normalV, float dither) {
#if AO_MODE == 0
    return 1.0;
#elif AO_MODE == 2
    return horizonAO(viewPos, normalV, dither);
#else
    int samples = PERF_SCALED_COUNT(SSAO_SAMPLES, 3);
    float radius = 0.55;
    float occ = 0.0;
    float ang = dither * 2.0 * PI;
    for (int i = 0; i < samples; i++) {
        float r = sqrt((float(i) + 0.5) / float(samples)) * radius;
        float t = float(i) * 2.39996 + ang;
        vec3 dir = normalize(vec3(cos(t), sin(t), 0.8));
        dir = dir - normalV * min(dot(dir, normalV), 0.0) * 2.0;
        vec3 sp = viewPos + dir * r;
        vec3 spScreen = viewToScreen(sp, gbufferProjection);
        if (clamp(spScreen.xy, 0.0, 1.0) != spScreen.xy) continue;
        float d = texture(depthtex0, spScreen.xy).r;
        vec3 sv = screenToView(vec3(spScreen.xy, d), gbufferProjectionInverse);
        float diff = sv.z - sp.z;
        float rangeCheck = smoothstep(0.0, 1.0, radius / max(abs(viewPos.z - sv.z), 1e-4));
        occ += (diff > 0.02 ? 1.0 : 0.0) * rangeCheck;
    }
    return 1.0 - occ / float(samples);
#endif
}

#ifdef REFRAX_CLOUD_TEMPORAL
bool cloudHistory(vec3 dirW, vec2 texel, out vec4 hist) {
    hist = vec4(0.0, 0.0, 0.0, 1.0);
    if (abs(dirW.y) < 0.002) return false;

    float tMid = (CU_BOTTOM + CLOUD_THICKNESS * 0.5 - cameraPosition.y) / dirW.y;
    if (tMid <= 0.0 || tMid > CLOUD_FADE_DIST) return false;

    vec3 prev = reprojectScene(dirW * tMid, gbufferPreviousModelView, gbufferPreviousProjection, cameraPosition, previousCameraPosition);
    if (clamp(prev.xy, 0.0, 1.0) != prev.xy) return false;

    vec2 huv = fsrRegionUV(prev.xy, texel);
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
    if (depth >= 1.0) {
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
    float ao = 1.0;
    if (depth < 1.0) {
        vec3 viewPos = screenToView(vec3(uv, depth), gbufferProjectionInverse);
        vec3 normalW = normalize(texture(colortex2, uv).rgb);
        vec3 normalV = mat3(gbufferModelView) * normalW;
        ao = computeAO(viewPos, normalV, dither);
    }
    outAO = vec4(ao, 0.0, 0.0, 1.0);
#ifdef REFRAX_CLOUD_TEMPORAL
    outCloudValid = vec4(cloudValid, 0.0, 0.0, 1.0);
#endif
}
