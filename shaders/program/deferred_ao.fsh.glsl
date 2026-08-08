/* Refrax — program/deferred_ao.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform sampler2D depthtex0;
uniform sampler2D colortex2;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform int frameCounter;

in vec2 uv;

/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 outAO;

float horizonAO(vec3 viewPos, vec3 normalV, float dither) {
    int dirs = max(PERF_SCALED_COUNT(SSAO_SAMPLES, 3) / 2, 2);
    const int STEPS = 4;
    float radius = 0.85;
    float ang = dither * 2.0 * PI;
    float visibility = 0.0;

    for (int d = 0; d < dirs; d++) {
        float theta = ang + float(d) * (PI / float(dirs));
        vec2 dir2 = vec2(cos(theta), sin(theta));

        float maxHorizon = -1.0;
        for (int s = 1; s <= STEPS; s++) {
            float stepFrac = (float(s) - 0.5 * dither) / float(STEPS);
            vec3 sp = viewPos + vec3(dir2 * (radius * stepFrac), 0.0);
            vec3 spScreen = viewToScreen(sp, gbufferProjection);
            if (clamp(spScreen.xy, 0.0, 1.0) != spScreen.xy) break;
            float dep = texture(depthtex0, spScreen.xy).r;
            if (dep >= 1.0) continue;
            vec3 sv = screenToView(vec3(spScreen.xy, dep), gbufferProjectionInverse);

            vec3 delta = sv - viewPos;
            float len = length(delta);
            if (len < 1e-4) continue;

            float atten = 1.0 - saturate(len / radius);
            float horizon = dot(delta / len, normalV) * atten;
            maxHorizon = max(maxHorizon, horizon);
        }
        visibility += 1.0 - saturate(maxHorizon);
    }
    return saturate(visibility / float(dirs));
}

float computeAO(vec3 viewPos, vec3 normalV, float dither) {
#if AO_MODE == 0
    return 1.0;
#elif AO_MODE == 2
    return horizonAO(viewPos, normalV, dither);
#else
    int samples = PERF_SCALED_COUNT(SSAO_SAMPLES, 3);
    float radius = 0.55;
    float occ = 0.0;
    float ang = dither * 2.0 * PI;
    for (int i = 0; i < samples; i++) {
        float r = sqrt((float(i) + 0.5) / float(samples)) * radius;
        float t = float(i) * 2.39996 + ang;
        vec3 dir = normalize(vec3(cos(t), sin(t), 0.8));
        dir = dir - normalV * min(dot(dir, normalV), 0.0) * 2.0;
        vec3 sp = viewPos + dir * r;
        vec3 spScreen = viewToScreen(sp, gbufferProjection);
        if (clamp(spScreen.xy, 0.0, 1.0) != spScreen.xy) continue;
        float d = texture(depthtex0, spScreen.xy).r;
        vec3 sv = screenToView(vec3(spScreen.xy, d), gbufferProjectionInverse);
        float diff = sv.z - sp.z;
        float rangeCheck = smoothstep(0.0, 1.0, radius / max(abs(viewPos.z - sv.z), 1e-4));
        occ += (diff > 0.02 ? 1.0 : 0.0) * rangeCheck;
    }
    return 1.0 - occ / float(samples);
#endif
}

void main() {
    float depth = texture(depthtex0, uv).r;
    float ao = 1.0;
    if (depth < 1.0) {
        float dither = ignAnim(gl_FragCoord.xy, frameCounter);
        vec3 viewPos = screenToView(vec3(uv, depth), gbufferProjectionInverse);
        vec3 normalW = unpackSurfaceNormal(texture(colortex2, uv));
        vec3 normalV = mat3(gbufferModelView) * normalW;
        ao = computeAO(viewPos, normalV, dither);
    }
    outAO = vec4(ao, 0.0, 0.0, 1.0);
}
