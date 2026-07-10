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

#endif
