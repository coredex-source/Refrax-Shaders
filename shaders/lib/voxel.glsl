/* Refrax — lib/voxel.glsl */
#ifndef REFRAX_VOXEL
#define REFRAX_VOXEL

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

const ivec3 VOXEL_DIM = ivec3(128, 64, 128);


ivec3 sceneToVoxelIndex(vec3 scenePos, vec3 camPos) {
    return ivec3(floor(scenePos + fract(camPos))) + VOXEL_DIM / 2;
}
bool voxelInBounds(ivec3 idx) {
    return all(greaterThanEqual(idx, ivec3(0))) && all(lessThan(idx, VOXEL_DIM));
}

vec3 sampleLPV(sampler3D lpv, vec3 scenePos, vec3 camPos, vec3 normal, out float fade) {
    vec3 vc = scenePos + fract(camPos) + normal * 0.5 + vec3(VOXEL_DIM) * 0.5;
    vec3 uvw = vc / vec3(VOXEL_DIM);
    vec3 edge = min(uvw, 1.0 - uvw) * vec3(VOXEL_DIM); 
    float e = min(edge.x, min(edge.y, edge.z));
    fade = saturate(e / 8.0);
    if (fade <= 0.0) return vec3(0.0);
    vec3 light = sqrt(max(texture(lpv, uvw).rgb, 0.0));
    float luma = max(luminance(light), 1e-4);
    vec3 hue = light / luma;
    hue = mix(vec3(1.0), hue, LPV_COLOR_SATURATION);
    return hue * luma * (BLOCKLIGHT_SCALE * LPV_INTENSITY);
}

#endif
