/* Refrax — program/deferred0.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/clouds.glsl"
#include "/lib/dh.glsl"

uniform sampler2D depthtex0;
uniform sampler2D colortex2;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform float frameTimeCounter, rainStrength, viewWidth, viewHeight;
uniform int frameCounter;

in vec2 uv;

/* RENDERTARGETS: 4,6 */
layout(location = 0) out vec4 outClouds;
layout(location = 1) out vec4 outAO;

float computeAO(vec3 viewPos, vec3 normalV, float dither) {
#if AO_MODE == 0
    return 1.0;
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
    float ao = 1.0 - occ / float(samples);
  #if AO_MODE == 2
    ao = pow(ao, 1.6);
  #endif
    return ao;
#endif
}

void main() {
    float depth = texture(depthtex0, uv).r;
    float dither = ignAnim(gl_FragCoord.xy, frameCounter);
    vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);
#if CLOUD_MODE > 0 && !defined WORLD_NETHER && !defined WORLD_END
    if (depth >= 1.0) {
        float cloudMaxDist = 1e9;
  #ifdef LOD_ACTIVE
        float lodDepth = texture(lodDepthTex1, uv).r;
        if (lodDepth < 1.0)
            cloudMaxDist = length(screenToView(vec3(uv, lodDepth), lodProjectionInverse));
  #endif
        vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
        vec3 viewDir = normalize(screenToView(vec3(uv, 1.0), gbufferProjectionInverse));
        vec3 dirW = normalize(mat3(gbufferModelViewInverse) * viewDir);
  #if CLOUD_MODE == 2
        clouds = volumetricClouds(cameraPosition, dirW, sunDir, frameTimeCounter, rainStrength, dither, cloudMaxDist);
  #else
        clouds = clouds2D(cameraPosition, dirW, sunDir, frameTimeCounter, rainStrength, cloudMaxDist);
  #endif
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
}
