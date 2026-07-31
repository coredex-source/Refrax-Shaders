/* Refrax — program/atmos_multiscatter.csh.glsl */

#include "/lib/settings.glsl"
#define ATMOS_LUT_READ
#include "/lib/atmosphere_lut.glsl"

layout(local_size_x = 8, local_size_y = 8) in;
const ivec3 workGroups = ivec3(4, 4, 1);

layout(rgba16f) writeonly uniform image2D refraxMultiScatterImg;

const int MS_SQRT_DIRS = 4;
const int MS_STEPS = 20;

void main() {
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    if (p.x >= ATMOS_MULTISCATTER_RES.x || p.y >= ATMOS_MULTISCATTER_RES.y) return;

    vec2 uv = (vec2(p) + 0.5) / vec2(ATMOS_MULTISCATTER_RES);
    float muSun = uv.x * 2.0 - 1.0;
    float h = atmosHeightFromV(uv.y);

    vec3 pos = vec3(0.0, ATMOS_GROUND_R + h, 0.0);
    vec3 sunDir = vec3(0.0, muSun, -sqrt(max(1.0 - muSun * muSun, 0.0)));

    vec3 lumTotal = vec3(0.0);
    vec3 fms = vec3(0.0);
    float invSamples = 1.0 / float(MS_SQRT_DIRS * MS_SQRT_DIRS);

    for (int i = 0; i < MS_SQRT_DIRS; i++) {
        for (int j = 0; j < MS_SQRT_DIRS; j++) {
            float theta = PI * (float(i) + 0.5) / float(MS_SQRT_DIRS);
            float phi = atmosSafeAcos(1.0 - 2.0 * (float(j) + 0.5) / float(MS_SQRT_DIRS));
            float cp = cos(phi), sp = sin(phi), ct = cos(theta), st = sin(theta);
            vec3 dir = vec3(sp * st, cp, sp * ct);

            float groundDist = atmosRaySphere(pos, dir, ATMOS_GROUND_R);
            float atmoDist = atmosRaySphere(pos, dir, ATMOS_TOP_R);
            float tMax = groundDist > 0.0 ? groundDist : atmoDist;
            if (tMax <= 0.0) continue;

            float cosT = dot(dir, sunDir);
            float phaseR = atmosRayleighPhase(cosT);
            float phaseM = atmosMiePhase(cosT);

            vec3 lum = vec3(0.0), lumFactor = vec3(0.0), transmittance = vec3(1.0);
            float t = 0.0;
            for (int s = 0; s < MS_STEPS; s++) {
                float newT = ((float(s) + 0.3) / float(MS_STEPS)) * tMax;
                float dt = newT - t;
                t = newT;
                vec3 q = pos + dir * t;

                float len = length(q);
                float qh = len - ATMOS_GROUND_R;
                vec3 sR, sE; float sM;
                atmosScatter(qh, sR, sM, sE);
                vec3 stepT = exp(-dt * sE);

                vec3 noPhase = sR + vec3(sM);
                lumFactor += transmittance * ((noPhase - noPhase * stepT) / sE);

                vec3 sunT = atmosTransmittanceLUT(qh, dot(sunDir, q / len));
                vec3 inScatter = (sR * phaseR + vec3(sM * phaseM)) * sunT;
                lum += transmittance * ((inScatter - inScatter * stepT) / sE);

                transmittance *= stepT;
            }

            if (groundDist > 0.0 && dot(pos, sunDir) > 0.0) {
                vec3 hit = normalize(pos + dir * groundDist) * ATMOS_GROUND_R;
                lum += transmittance * ATMOS_GROUND_ALBEDO
                     * atmosTransmittanceLUT(0.0, dot(normalize(hit), sunDir));
            }

            lumTotal += lum * invSamples;
            fms += lumFactor * invSamples;
        }
    }

    vec3 psi = lumTotal / max(1.0 - fms, vec3(1e-3));
    imageStore(refraxMultiScatterImg, p, vec4(psi * MULTI_SCATTER_STRENGTH, 1.0));
}
