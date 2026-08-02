/* Refrax — program/grade.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/post.glsl"
#include "/lib/bloom.glsl"
#include "/lib/lens.glsl"

uniform sampler2D colortex0;
#ifdef BLOOM
uniform sampler2D colortex4;
#endif
#ifdef AUTO_EXPOSURE
uniform sampler2D colortex12;
#endif
uniform float viewWidth, viewHeight;
uniform ivec2 eyeBrightnessSmooth;
#if defined LENS_GATHER || defined LENS_FLARE_ACTIVE
uniform sampler2D depthtex0;
uniform int frameCounter;
#endif
#ifdef DEPTH_OF_FIELD
uniform float near, far;
  #ifdef DOF_AUTOFOCUS
uniform float centerDepthSmooth;
  #endif
  #ifdef DOF_SPYGLASS
uniform int heldItemId, heldItemId2;
  #endif
#endif
#ifdef MOTION_BLUR
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;
uniform vec3 cameraPosition, previousCameraPosition;
uniform float frameTime;
#endif
#if defined MOTION_BLUR || defined LENS_FLARE_ACTIVE
uniform mat4 gbufferModelViewInverse;
#endif
#ifdef LENS_FLARE_ACTIVE
uniform mat4 gbufferProjection;
uniform vec3 sunPosition;
uniform float rainStrength;
#endif
#ifdef PURKINJE
uniform float nightVision;
#endif

in vec2 uv;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

#ifdef BLOOM
vec3 bloomSample(vec2 coord) {
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    vec3 bloom = vec3(0.0);
    for (int i = 0; i < BLOOM_LEVELS; i++) {
        float s = bloomLevelScale(i);
        vec2 pad = 0.75 * px / s;
        vec2 uvT = vec2(0.0, bloomLevelY(i)) + clamp(coord, pad, 1.0 - pad) * s;
        bloom += texture(colortex4, uvT).rgb;
    }
    return bloom / float(BLOOM_LEVELS);
}
#endif

#ifdef MOTION_BLUR
vec2 cameraMotion(vec2 coord, float depth) {
    vec3 viewPos = screenToView(vec3(coord, depth), gbufferProjectionInverse);
    vec3 scenePos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 prev = depth >= 1.0
        ? reprojectScene(scenePos, gbufferPreviousModelView, gbufferPreviousProjection, previousCameraPosition, previousCameraPosition)
        : reprojectScene(scenePos, gbufferPreviousModelView, gbufferPreviousProjection, cameraPosition, previousCameraPosition);
    return coord - prev.xy;
}
#endif

#ifdef LENS_FLARE_ACTIVE
vec3 flareContribution(vec2 coord, float aspect) {
    if (sunPosition.z >= 0.0) return vec3(0.0);
    vec2 sunUV = viewToScreen(sunPosition, gbufferProjection).xy;
    if (any(lessThan(sunUV, vec2(-0.35))) || any(greaterThan(sunUV, vec2(1.35)))) return vec3(0.0);

    vec3 sunDirW = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    float altitude = smoothstep(-0.06, 0.08, sunDirW.y);
    if (altitude <= 0.0) return vec3(0.0);

    vec3 tint = vec3(0.0);
    float sky = 0.0;
    for (int i = 0; i < 9; i++) {
        float a = float(i) * 0.6981317;
        vec2 o = i == 0 ? vec2(0.0) : vec2(cos(a), sin(a)) * 0.011;
        vec2 s = clamp(sunUV + o * vec2(1.0 / aspect, 1.0), vec2(0.0), vec2(1.0));
        if (texture(depthtex0, s).r < 1.0) continue;
        tint += texture(colortex0, s).rgb;
        sky += 1.0;
    }
    if (sky <= 0.0) return vec3(0.0);

    tint = clamp(tint / sky, vec3(0.0), vec3(12.0));
    float visibility = sky / 9.0;
    vec2 edge = min(sunUV, 1.0 - sunUV);
    visibility *= saturate(min(edge.x, edge.y) * 8.0 + 1.0);
    float weight = visibility * altitude * (1.0 - rainStrength * 0.85) * LENS_FLARE_STRENGTH;
    if (weight <= 0.001) return vec3(0.0);
    return lensFlare(coord, sunUV, tint, aspect) * weight;
}
#endif

void main() {
    float aspect = viewWidth / max(viewHeight, 1.0);
    vec3 hdr = texture(colortex0, uv).rgb;

#ifdef LENS_GATHER
    {
        float rawDepth = texture(depthtex0, uv).r;
        float dither = ignAnim(gl_FragCoord.xy, frameCounter);
        bool nearHand = rawDepth < HAND_DEPTH_LIMIT;

  #ifdef DEPTH_OF_FIELD
        float focus = DOF_FOCUS;
    #ifdef DOF_AUTOFOCUS
        focus = linearizeDepth(clamp(centerDepthSmooth, 0.0, 0.9999), near, far);
    #endif
        float aperture = 1.0;
    #ifdef DOF_SPYGLASS
        if (heldItemId == SPYGLASS_ITEM_ID || heldItemId2 == SPYGLASS_ITEM_ID) aperture = 0.25;
    #endif
        float centerDist = linearizeDepth(rawDepth, near, far);
        float coc = nearHand ? 0.0 : dofCoc(centerDist, focus) * aperture;
        vec2 dofRadius = vec2(DOF_MAX_RADIUS / aspect, DOF_MAX_RADIUS) * coc;
  #endif

  #ifdef MOTION_BLUR
        vec2 velocity = nearHand ? vec2(0.0) : cameraMotion(uv, rawDepth);
        velocity *= MOTION_BLUR_SHUTTER / max(frameTime, 1e-4);
        float speed = length(velocity);
        if (speed > MOTION_BLUR_MAX) velocity *= MOTION_BLUR_MAX / speed;
  #endif

        bool gather = false;
  #ifdef DEPTH_OF_FIELD
        gather = gather || coc > 0.004;
  #endif
  #ifdef MOTION_BLUR
        gather = gather || min(speed, MOTION_BLUR_MAX) > 0.0006;
  #endif
        if (gather) {
            int count = PERF_SCALED_COUNT(LENS_BASE_SAMPLES, 4);
            vec3 acc = hdr;
            float wsum = 1.0;
            for (int i = 0; i < count; i++) {
                vec2 o = vec2(0.0);
                float w = 1.0;
  #ifdef DEPTH_OF_FIELD
                vec2 hexOff = dofHexOffset(i, count, dither * 6.28318530);
                o += hexOff * dofRadius;
  #endif
  #ifdef MOTION_BLUR
                o += velocity * ((float(i) + dither) / float(count) - 0.5);
  #endif
                vec2 suv = clamp(uv + o, vec2(0.0), vec2(1.0));
  #ifdef DEPTH_OF_FIELD
                if (coc > 0.004) {
                    float sRaw = texture(depthtex0, suv).r;
                    float sCoc = sRaw < HAND_DEPTH_LIMIT ? 0.0
                               : dofCoc(linearizeDepth(sRaw, near, far), focus) * aperture;
                    w = saturate((sCoc - length(hexOff) * coc) * 8.0 + 1.0);
                }
  #endif
                acc += texture(colortex0, suv).rgb * w;
                wsum += w;
            }
            hdr = acc / max(wsum, 1e-4);
        }
    }
#endif

#ifdef LENS_FLARE_ACTIVE
    hdr += flareContribution(uv, aspect);
#endif

#ifdef BLOOM
    hdr += bloomSample(uv) * (BLOOM_STRENGTH * CALM_BLOOM * BLOOM_ADD);
#endif

#ifdef PURKINJE
    hdr = purkinjeShift(hdr, PURKINJE_STRENGTH * saturate(1.0 - nightVision));
#endif

#ifdef AUTO_EXPOSURE
    hdr *= sceneExposure(texture(colortex12, EXPOSURE_UV).r, 0.0);
#else
    hdr *= sceneExposure(1.0, float(eyeBrightnessSmooth.y) / 240.0);
#endif
    outColor = vec4(colorGrade(applyTonemap(hdr)), 1.0);
}
