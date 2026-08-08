/* Refrax — program/atmos_skycache.csh.glsl */

#define REFRAX_SKY_CACHE_GEN
#include "/lib/settings.glsl"
#include "/lib/atmosphere.glsl"

layout(local_size_x = 1, local_size_y = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

layout(rgba16f) writeonly uniform image2D refraxSkyCacheImg;

uniform vec3 refraxSunDir;
uniform float rainStrength;

void main() {
    imageStore(refraxSkyCacheImg, ivec2(0), vec4(skyAmbient(normalize(refraxSunDir), rainStrength), 1.0));
}
