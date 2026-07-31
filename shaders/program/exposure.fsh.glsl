/* Refrax — program/exposure.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex12;
uniform float frameTime;

in vec2 uv;

/* RENDERTARGETS: 12 */
layout(location = 0) out vec4 outExposure;

void main() {
#ifndef AUTO_EXPOSURE
    outExposure = vec4(1.0);
#else
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
    outExposure = vec4(mix(prev, target, saturate(blend)), 0.0, 0.0, 1.0);
#endif
}
