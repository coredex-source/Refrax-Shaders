#ifndef REFRAX_UNDERWATER
#define REFRAX_UNDERWATER

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/noise.glsl"
#include "/lib/shadows.glsl"

const float SUSPENSION_WRAP = 256.0;
const float MOTE_NEAR = 1.5;
const float MOTE_ANGULAR = 0.0032;
const float MOTE_BLOB_RADIUS = 0.34;
const float MOTE_BASE_COVERAGE = 0.040;

float suspendedBlob(vec3 q, float coverage, float radius) {
    vec3 cell = floor(q);
    if (hash13(cell) < 1.0 - coverage) return 0.0;
    vec3 jit = vec3(hash13(cell + vec3(19.0, 3.0, 41.0)),
                    hash13(cell + vec3(53.0, 71.0, 7.0)),
                    hash13(cell + vec3(97.0, 29.0, 61.0)));
    float f = saturate(1.0 - length(q - cell - jit) / radius);
    return f * f * f;
}

#ifdef UNDERWATER_MOTES
vec3 underwaterMotes(sampler2D stex, vec3 dirW, vec3 camPos, float maxDist, float time, float dither, mat4 shadowMV, mat4 shadowProj, vec3 lightCol, float eyeSky) {
    const float ratio = pow(MOTE_DISTANCE / MOTE_NEAR, 1.0 / float(MOTE_LAYERS));
    float t = MOTE_NEAR * pow(ratio, dither);
    vec3 anchor = mod(camPos, SUSPENSION_WRAP) + vec3(0.085, 0.020, 0.062) * time;

    float sunlit = 0.0;
    float ambient = 0.0;
    for (int k = 0; k < MOTE_LAYERS; k++, t *= ratio) {
        if (t >= maxDist) break;
        vec3 marchPos = dirW * t;
        float blob = suspendedBlob((anchor + marchPos) / (t * MOTE_ANGULAR),
                                   MOTE_BASE_COVERAGE * MOTE_DENSITY, MOTE_BLOB_RADIUS);
        if (blob <= 0.0) continue;

        blob *= smoothstep(0.0, MOTE_NEAR * 2.0, t)
              * (1.0 - smoothstep(maxDist * 0.55, maxDist, t))
              * exp(-t * 0.055);

        float s = 1.0;
        vec4 sclip = shadowProj * (shadowMV * vec4(marchPos, 1.0));
        vec3 sp = distortShadowClip(sclip.xyz / sclip.w) * 0.5 + 0.5;
        if (clamp(sp.xy, 0.0, 1.0) == sp.xy)
            s = step(sp.z - 0.0006, texture(stex, sp.xy).r);

        sunlit += blob * s;
        ambient += blob;
    }
    return lightCol * vec3(0.42, 0.78, 1.00) * (sunlit * 0.13 * eyeSky)
         + vec3(0.62, 0.86, 1.00) * (ambient * 0.035 * (0.25 + 0.75 * eyeSky));
}
#endif

#endif
