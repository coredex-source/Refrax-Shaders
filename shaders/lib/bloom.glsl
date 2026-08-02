/* Refrax — lib/bloom.glsl */
#ifndef REFRAX_BLOOM
#define REFRAX_BLOOM

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

/* Bloom pyramid atlas: level i is the frame at scale 0.5*2^-i, packed as a
   vertical stack hugging the left edge. Level i spans y in
   [1-2^-i, 1-2^-(i+1)), so the stack tiles [0,1) exactly and a fragment's
   level is recoverable from its y coordinate alone. */
#define BLOOM_LEVELS 6
#define bloomLevelScale(i) (0.5 * exp2(-float(i)))
#define bloomLevelY(i) (1.0 - exp2(-float(i)))

const float BLOOM_ADD = 0.30;
const float BLOOM_SOURCE_CLAMP = 16.0;

vec3 bloomPrefilter(vec3 c, float exposure) {
    float br = max(c.r, max(c.g, c.b)) * exposure;
    if (br <= 1e-5) return vec3(0.0);
    float knee = BLOOM_THRESHOLD * BLOOM_KNEE;
    float soft = clamp(br - BLOOM_THRESHOLD + knee, 0.0, 2.0 * knee);
    soft = soft * soft / (4.0 * knee + 1e-4);
    float excess = min(max(soft, br - BLOOM_THRESHOLD), BLOOM_SOURCE_CLAMP);
    return c * (excess / br);
}

#endif
