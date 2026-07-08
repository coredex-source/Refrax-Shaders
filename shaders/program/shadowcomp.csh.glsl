/* Refrax :: shadowcomp */

#include "/lib/settings.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
const ivec3 workGroups = ivec3(16, 8, 16); // 128x64x128 / 8

#ifdef COLORED_LIGHTING
#include "/lib/floodfill.glsl"

layout(rgba16f) writeonly uniform image3D lpvImg2;
uniform sampler3D lpvSampler1;
uniform sampler3D voxelSampler;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
#endif

void main() {
#ifdef COLORED_LIGHTING
    ivec3 p = ivec3(gl_GlobalInvocationID);
    ivec3 shift = ivec3(floor(cameraPosition) - floor(previousCameraPosition));
    imageStore(lpvImg2, p, floodfillStep(lpvSampler1, voxelSampler, p, shift));
#endif
}
