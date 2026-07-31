/* Refrax — program/atmos_skyview.csh.glsl */

#include "/lib/settings.glsl"
#define ATMOS_LUT_READ
#include "/lib/atmosphere_lut.glsl"

layout(local_size_x = 16, local_size_y = 16) in;
const ivec3 workGroups = ivec3(12, 7, 1);

layout(rgba16f) writeonly uniform image2D refraxSkyViewImg;

uniform vec3 refraxSunDir;

void main() {
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    if (p.x >= ATMOS_SKYVIEW_RES.x || p.y >= ATMOS_SKYVIEW_RES.y) return;

    vec2 uv = (vec2(p) + 0.5) / vec2(ATMOS_SKYVIEW_RES);

    float h = atmosAltitude(refraxEyeY);
    vec3 pos = vec3(0.0, ATMOS_GROUND_R + h, 0.0);

    vec3 sunDir = normalize(refraxSunDir);
    float sunAltitude = 0.5 * PI - atmosSafeAcos(sunDir.y);

    vec3 dir, sunDirLocal;
    atmosSkyViewDir(uv, sunAltitude, h, dir, sunDirLocal);

    float groundDist = atmosRaySphere(pos, dir, ATMOS_GROUND_R);
    float atmoDist = atmosRaySphere(pos, dir, ATMOS_TOP_R);
    float tMax = groundDist > 0.0 ? groundDist : atmoDist;

    vec3 lum = vec3(0.0);
    if (tMax > 0.0) {
        vec3 moonIllum = ATMOS_MOON_SKY * (MOON_BRIGHTNESS * 4.0) * ATMOS_MOON_TINT;
        lum = atmosRaymarchSky(pos, dir, sunDirLocal, vec3(1.0), moonIllum, tMax, PERF_SCALED_COUNT(ATMOS_SKY_STEPS, 8));
        lum *= atmosHorizonRolloff(asin(clamp(dir.y, -1.0, 1.0)));
    }

    imageStore(refraxSkyViewImg, p, vec4(lum, 1.0));
}
