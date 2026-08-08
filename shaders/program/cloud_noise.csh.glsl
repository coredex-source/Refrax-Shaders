/* Refrax - cloud_noise.csh.glsl */

#include "/lib/settings.glsl"
#include "/lib/noise.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
const ivec3 workGroups = ivec3((CLOUD_NOISE_DIM + 8) / 8);

#ifdef CLOUD_NOISE_TEXTURE
layout(r8) writeonly uniform image3D cloudNoiseImg;
#endif

void main() {
#ifdef CLOUD_NOISE_TEXTURE
    ivec3 p = ivec3(gl_GlobalInvocationID);
    if (any(greaterThan(p, ivec3(CLOUD_NOISE_DIM)))) return;
    imageStore(cloudNoiseImg, p, vec4(hash13(vec3(p % CLOUD_NOISE_DIM))));
#endif
}
