/* Refrax — lib/floodfill.glsl */
#ifndef REFRAX_FLOODFILL
#define REFRAX_FLOODFILL

#include "/lib/settings.glsl"

const ivec3 FF_DIM = ivec3(128, 64, 128);

vec3 ffFetch(sampler3D s, ivec3 p) {
    if (any(lessThan(p, ivec3(0))) || any(greaterThanEqual(p, FF_DIM))) return vec3(0.0);
    return texelFetch(s, p, 0).rgb;
}


vec4 floodfillStep(sampler3D prevLight, sampler3D voxels, ivec3 p, ivec3 shift) {
    vec4 vox = texelFetch(voxels, p, 0);
    if (vox.a > 0.5) {
        
        if (any(greaterThan(vox.rgb, vec3(0.0)))) return vec4(vox.rgb, 1.0);
        return vec4(ffFetch(prevLight, p + shift) * 0.5, 1.0);
    }

    ivec3 q = p + shift;
    vec3 sum = ffFetch(prevLight, q)
             + ffFetch(prevLight, q + ivec3( 1, 0, 0))
             + ffFetch(prevLight, q + ivec3(-1, 0, 0))
             + ffFetch(prevLight, q + ivec3( 0, 1, 0))
             + ffFetch(prevLight, q + ivec3( 0,-1, 0))
             + ffFetch(prevLight, q + ivec3( 0, 0, 1))
             + ffFetch(prevLight, q + ivec3( 0, 0,-1));
    
    float divisor = 7.0 + (0.90 - LPV_FALLOFF) * 8.0;
    
    return vec4(clamp(sum / divisor, 0.0, 64.0), 0.0);
}

#endif
