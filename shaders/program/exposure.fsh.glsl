/* Refrax — program/exposure.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/lens.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex12;
uniform float frameTime;
#ifdef LENS_FLARE_ACTIVE
uniform sampler2D depthtex0;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float viewWidth, viewHeight, rainStrength, blindness;
uniform int isEyeInWater;
#endif

in vec2 uv;

/* RENDERTARGETS: 12 */
layout(location = 0) out vec4 outExposure;

void main() {
    float exposure = 1.0;

#ifdef AUTO_EXPOSURE
    const int GRID = 5;
    float logSum = 0.0;
    float weightSum = 0.0;

    for (int y = 0; y < GRID; y++) {
        for (int x = 0; x < GRID; x++) {
            vec2 t = (vec2(x, y) + fract(uv * 64.0)) / float(GRID);
            vec3 c = texture(colortex0, clamp(t, 0.001, 0.999)).rgb;
            float l = luminance(max(c, vec3(0.0)));

            vec2 d = t - 0.5;
            float w = exp(-dot(d, d) * 2.2);

            logSum += log2(max(l, 1e-4)) * w;
            weightSum += w;
        }
    }

    float avgLum = exp2(logSum / max(weightSum, 1e-4));
    float target = clamp(EXPOSURE_KEY / max(avgLum, 1e-4), EXPOSURE_MIN, EXPOSURE_MAX);

    float prev = texture(colortex12, EXPOSURE_UV).r;
    if (prev <= 0.0 || isnan(prev)) prev = target;

    float speed = target < prev ? EXPOSURE_SPEED_UP : EXPOSURE_SPEED_DOWN;
    float blend = 1.0 - exp(-max(frameTime, 1e-4) * speed);
    exposure = mix(prev, target, saturate(blend));
#endif

    vec3 flareLight = vec3(0.0);

#ifdef LENS_FLARE_ACTIVE
    float aspect = viewWidth / max(viewHeight, 1.0);
    vec2 origin = flareOriginUV(sunPosition, gbufferProjection);
    float clarity = (1.0 - rainStrength * 0.85) * (1.0 - saturate(blindness)) * float(isEyeInWater == 0);
    flareLight = flareLightSample(colortex0, depthtex0, origin, sunPosition,
                                  gbufferModelViewInverse, aspect, clarity);

    vec3 prevLight = texture(colortex12, EXPOSURE_UV).gba;
    if (any(isnan(prevLight))) prevLight = flareLight;
    flareLight = mix(flareLight, prevLight, exp2(-max(frameTime, 1e-4) * 12.5));
#endif

    outExposure = vec4(exposure, flareLight);
}
