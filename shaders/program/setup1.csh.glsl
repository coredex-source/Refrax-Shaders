/* Refrax - setup1.csh.glsl */

#include "/lib/settings.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
const ivec3 workGroups = ivec3(16, 8, 16); // 128x64x128 / 8

#ifdef COLORED_LIGHTING
layout(rgba16f) writeonly uniform image3D lpvImg1;
layout(rgba16f) writeonly uniform image3D lpvImg2;
#endif

void main() {
#ifdef COLORED_LIGHTING
    ivec3 p = ivec3(gl_GlobalInvocationID);
    imageStore(lpvImg1, p, vec4(0.0));
    imageStore(lpvImg2, p, vec4(0.0));
#endif
}
