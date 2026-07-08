/* Refrax :: shadowcomp1 */

#include "/lib/settings.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
const ivec3 workGroups = ivec3(16, 8, 16);

#ifdef COLORED_LIGHTING
#include "/lib/floodfill.glsl"

layout(rgba16f) writeonly uniform image3D lpvImg1;
uniform sampler3D lpvSampler2;
uniform sampler3D voxelSampler;
#endif

void main() {
#ifdef COLORED_LIGHTING
    ivec3 p = ivec3(gl_GlobalInvocationID);
    imageStore(lpvImg1, p, floodfillStep(lpvSampler2, voxelSampler, p, ivec3(0)));
#endif
}
