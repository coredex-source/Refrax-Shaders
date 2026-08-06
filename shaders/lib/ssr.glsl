/* Refrax — lib/ssr.glsl */
#ifndef REFRAX_SSR
#define REFRAX_SSR

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

vec2 ssrLobeRandom(sampler2D noiseTex, vec2 px, int frame) {
    const vec2 r2 = vec2(0.7548776662466927, 0.5698402909980532);
    float b = texelFetch(noiseTex, ivec2(px) & 255, 0).a;
    return fract(vec2(b, fract(b * 91.7 + 0.37)) + r2 * float(frame % 64));
}

vec3 ssrLobeDir(vec3 R, vec3 N, float roughness, vec2 xi) {
    float a = roughness * roughness;
    if (a < 5e-4) return R;
    vec3 tangent = normalize(cross(abs(R.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0), R));
    vec3 bitangent = cross(R, tangent);
    float phi = xi.x * 2.0 * PI;
    float r = min(a * sqrt(xi.y / max(1.0 - xi.y, 1e-3)), 0.30);
    vec3 dir = normalize(R + (tangent * cos(phi) + bitangent * sin(phi)) * r);
    return dot(dir, N) > 0.02 ? dir : R;
}

float raymarchSSRCustom(sampler2D depthTex, vec3 viewPos, vec3 reflDirView, mat4 proj, mat4 projInv, float dither, vec2 jitterUV, int steps, int refineSteps, float baseStep, float stepGrowth, out vec3 hitScreen) {
    hitScreen = vec3(0.0);
    float stepLen = baseStep;
    vec3 p = viewPos + reflDirView * stepLen * (0.75 + dither * 0.50);
    for (int i = 0; i < steps; i++) {
        vec3 sp = viewToScreen(p, proj);
        if (clamp(sp.xy, 0.0, 1.0) != sp.xy || sp.z <= 0.0 || sp.z >= 1.0) return 0.0;
        float d = texture(depthTex, sp.xy + jitterUV).r;
        vec3 sceneView = screenToView(vec3(sp.xy, d), projInv);
        float diff = sceneView.z - p.z;
        float thickness = min(max(stepLen * 2.2, abs(p.z) * 0.01), abs(p.z) * 0.50);
        if (diff > 0.0 && diff < thickness && d < 1.0) {

            vec3 lo = p - reflDirView * stepLen, hi = p;
            for (int j = 0; j < refineSteps; j++) {
                vec3 mid = (lo + hi) * 0.5;
                vec3 msp = viewToScreen(mid, proj);
                float md = texture(depthTex, msp.xy + jitterUV).r;
                vec3 mv = screenToView(vec3(msp.xy, md), projInv);
                if (mv.z - mid.z > 0.0) hi = mid; else lo = mid;
            }
            hitScreen = viewToScreen((lo + hi) * 0.5, proj);
            vec2 border = min(hitScreen.xy, 1.0 - hitScreen.xy);
            float edge = saturate(min(border.x, border.y) * 16.0);
            float certainty = saturate(1.0 - stepLen / max(abs(p.z) * 0.5, 1e-3));
            return edge * mix(0.55, 1.0, certainty);
        }
        p += reflDirView * stepLen;
        stepLen *= stepGrowth;
    }
    return 0.0;
}

float ssrStepGrowth(float baseStep, float maxStepLen, int steps) {
    return pow(maxStepLen / baseStep, 1.0 / float(max(steps - 1, 1)));
}

float raymarchSSR(sampler2D depthTex, vec3 viewPos, vec3 reflDirView, mat4 proj, mat4 projInv, float dither, vec2 jitterUV, out vec3 hitScreen) {
    int steps = PERF_SCALED_COUNT(SSR_STEPS, 6);
    const float baseStep = 0.40;
    return raymarchSSRCustom(depthTex, viewPos, reflDirView, proj, projInv, dither, jitterUV, steps, 4, baseStep, ssrStepGrowth(baseStep, 40.0, steps), hitScreen);
}

float raymarchSSRFast(sampler2D depthTex, vec3 viewPos, vec3 reflDirView,
                      mat4 proj, mat4 projInv, float dither, vec2 jitterUV, out vec3 hitScreen) {
    int steps = max(PERF_SCALED_COUNT(min(SSR_STEPS, 10), 4), 4);
    const float baseStep = 0.60;
    return raymarchSSRCustom(depthTex, viewPos, reflDirView, proj, projInv, dither, jitterUV, steps, 2, baseStep, ssrStepGrowth(baseStep, 14.0, steps), hitScreen);
}

#endif
