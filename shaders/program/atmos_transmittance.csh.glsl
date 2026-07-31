/* Refrax — program/atmos_transmittance.csh.glsl */

#include "/lib/settings.glsl"
#include "/lib/atmosphere_lut.glsl"

layout(local_size_x = 16, local_size_y = 16) in;
const ivec3 workGroups = ivec3(16, 4, 1);

layout(rgba16f) writeonly uniform image2D refraxTransmittanceImg;

void main() {
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    if (p.x >= ATMOS_TRANSMITTANCE_RES.x || p.y >= ATMOS_TRANSMITTANCE_RES.y) return;

    vec2 uv = (vec2(p) + 0.5) / vec2(ATMOS_TRANSMITTANCE_RES);
    float mu = uv.x * 2.0 - 1.0;
    float h = atmosHeightFromV(uv.y);

    imageStore(refraxTransmittanceImg, p, vec4(atmosComputeTransmittance(h, mu), 1.0));
}
