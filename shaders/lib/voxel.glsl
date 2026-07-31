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

vec3 lpvShade(vec3 stored) {
    vec3 light = sqrt(max(stored, 0.0));
    float luma = max(luminance(light), 1e-4);
    vec3 hue = mix(vec3(1.0), light / luma, LPV_COLOR_SATURATION);
    return hue * luma * (BLOCKLIGHT_SCALE * LPV_INTENSITY);
}

float lpvFade(vec3 uvw) {
    vec3 edge = min(uvw, 1.0 - uvw) * vec3(VOXEL_DIM);
    return saturate(min(edge.x, min(edge.y, edge.z)) / 8.0);
}

#ifdef LPV_OCCLUSION_AWARE
vec3 sampleLPVConnected(sampler3D lpv, vec3 vc) {
    vec3 gp = vc - 0.5;
    vec3 gi = floor(gp);
    vec3 gf = gp - gi;
    ivec3 base = ivec3(gi);

    vec3 stored[8];
    float openCell[8];
    for (int i = 0; i < 8; i++) {
        ivec3 o = ivec3(i & 1, (i >> 1) & 1, (i >> 2) & 1);
        vec4 s = texelFetch(lpv, clamp(base + o, ivec3(0), VOXEL_DIM - 1), 0);
        stored[i] = max(s.rgb, vec3(0.0));
        openCell[i] = 1.0 - step(0.5, s.a);
    }

    ivec3 anchorOffset = clamp(ivec3(floor(vc)) - base, ivec3(0), ivec3(1));
    int anchor = anchorOffset.x | (anchorOffset.y << 1) | (anchorOffset.z << 2);
    if (openCell[anchor] < 0.5) return vec3(0.0);

    vec3 acc = vec3(0.0);
    for (int i = 0; i < 8; i++) {
        ivec3 o = ivec3(i & 1, (i >> 1) & 1, (i >> 2) & 1);
        vec3 tw = mix(1.0 - gf, gf, vec3(o));
        float w = tw.x * tw.y * tw.z;
        if (w <= 0.0) continue;

        int path = anchor ^ i;
        float route = 1.0;
        if (path == 3) {
            route = max(openCell[anchor ^ 1], openCell[anchor ^ 2]);
        } else if (path == 5) {
            route = max(openCell[anchor ^ 1], openCell[anchor ^ 4]);
        } else if (path == 6) {
            route = max(openCell[anchor ^ 2], openCell[anchor ^ 4]);
        } else if (path == 7) {
            route = max(
                max(openCell[anchor ^ 1] * openCell[anchor ^ 3],
                    openCell[anchor ^ 1] * openCell[anchor ^ 5]),
                max(
                    max(openCell[anchor ^ 2] * openCell[anchor ^ 3],
                        openCell[anchor ^ 2] * openCell[anchor ^ 6]),
                    max(openCell[anchor ^ 4] * openCell[anchor ^ 5],
                        openCell[anchor ^ 4] * openCell[anchor ^ 6])
                )
            );
        }
        acc += stored[i] * (w * openCell[i] * route);
    }
    return acc;
}
#endif

vec3 sampleLPV(sampler3D lpv, vec3 scenePos, vec3 camPos, vec3 normal, out float fade) {
    vec3 vc = scenePos + fract(camPos) + normal * 0.5 + vec3(VOXEL_DIM) * 0.5;
    vec3 uvw = vc / vec3(VOXEL_DIM);
    fade = lpvFade(uvw);
    if (fade <= 0.0) return vec3(0.0);

#ifdef LPV_OCCLUSION_AWARE
    return lpvShade(sampleLPVConnected(lpv, vc));
#else
    return lpvShade(texture(lpv, uvw).rgb);
#endif
}

vec3 sampleLPVFog(sampler3D lpv, vec3 scenePos, vec3 camPos, out float fade) {
    vec3 vc = scenePos + fract(camPos) + vec3(VOXEL_DIM) * 0.5;
    vec3 uvw = vc / vec3(VOXEL_DIM);
    fade = lpvFade(uvw);
    if (fade <= 0.0) return vec3(0.0);
#ifdef LPV_OCCLUSION_AWARE
    ivec3 cell = clamp(ivec3(floor(vc)), ivec3(0), VOXEL_DIM - 1);
    vec4 s = texelFetch(lpv, cell, 0);
    return s.a < 0.5 ? lpvShade(s.rgb) : vec3(0.0);
#else
    return lpvShade(texture(lpv, uvw).rgb);
#endif
}

#endif
