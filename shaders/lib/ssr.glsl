/* Refrax — lib/ssr.glsl */
#ifndef REFRAX_SSR
#define REFRAX_SSR

#include "/lib/settings.glsl"
#include "/lib/common.glsl"


float raymarchSSRCustom(sampler2D depthTex, vec3 viewPos, vec3 reflDirView, mat4 proj, mat4 projInv, float dither, int steps, int refineSteps, float baseStep, out vec3 hitScreen) {
    hitScreen = vec3(0.0);
    float stepLen = baseStep;
    vec3 p = viewPos + reflDirView * stepLen * (0.5 + dither);
    for (int i = 0; i < steps; i++) {
        vec3 sp = viewToScreen(p, proj);
        if (clamp(sp.xy, 0.0, 1.0) != sp.xy || sp.z >= 1.0) return 0.0;
        float d = texture(depthTex, sp.xy).r;
        vec3 sceneView = screenToView(vec3(sp.xy, d), projInv);
        float diff = sceneView.z - p.z; 
        if (diff > 0.0 && diff < stepLen * 3.0 && d < 1.0) {
            
            vec3 lo = p - reflDirView * stepLen, hi = p;
            for (int j = 0; j < refineSteps; j++) {
                vec3 mid = (lo + hi) * 0.5;
                vec3 msp = viewToScreen(mid, proj);
                float md = texture(depthTex, msp.xy).r;
                vec3 mv = screenToView(vec3(msp.xy, md), projInv);
                if (mv.z - mid.z > 0.0) hi = mid; else lo = mid;
            }
            hitScreen = viewToScreen((lo + hi) * 0.5, proj);
            vec2 border = min(hitScreen.xy, 1.0 - hitScreen.xy);
            return saturate(min(border.x, border.y) * 12.0); 
        }
        p += reflDirView * stepLen;
        stepLen *= 1.18; 
    }
    return 0.0;
}

float raymarchSSR(sampler2D depthTex, vec3 viewPos, vec3 reflDirView, mat4 proj, mat4 projInv, float dither, out vec3 hitScreen) {
    int steps = PERF_SCALED_COUNT(SSR_STEPS, 6);
    return raymarchSSRCustom(depthTex, viewPos, reflDirView, proj, projInv, dither, steps, 4, 0.35, hitScreen);
}

float raymarchSSRFast(sampler2D depthTex, vec3 viewPos, vec3 reflDirView,
                      mat4 proj, mat4 projInv, float dither, out vec3 hitScreen) {
    int steps = PERF_SCALED_COUNT(min(SSR_STEPS, 10), 4);
    return raymarchSSRCustom(depthTex, viewPos, reflDirView, proj, projInv, dither, max(steps, 4), 2, 0.55, hitScreen);
}

#endif
