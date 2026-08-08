/* Refrax — lib/ssr.glsl */
#ifndef REFRAX_SSR
#define REFRAX_SSR

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#if SSR_TRACER == 2
  #define HIZ_READ
  #include "/lib/hiz.glsl"
#endif

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

#if SSR_TRACER == 2
float ssrCellExitT(vec2 o, vec2 dxy, vec2 cell, vec2 cellCount, vec2 crossStep, vec2 crossOff) {
    vec2 planes = (cell + max(crossStep, vec2(0.0))) / cellCount + crossOff;
    float tx = abs(dxy.x) < 1e-9 ? 1e9 : (planes.x - o.x) / dxy.x;
    float ty = abs(dxy.y) < 1e-9 ? 1e9 : (planes.y - o.y) / dxy.y;
    return min(tx, ty);
}

float raymarchSSRHiZ(sampler2D depthTex, ivec2 full, vec3 viewPos, vec3 reflDirView,
                     mat4 proj, mat4 projInv, float dither, vec2 jitterUV,
                     int maxIter, int refineSteps, float maxDist, out vec3 hitScreen) {
    hitScreen = vec3(0.0);

    float tFar = maxDist;
    if (reflDirView.z > 1e-6) {
        float tn = (-0.06 - viewPos.z) / reflDirView.z;
        if (tn <= 0.0) return 0.0;
        tFar = min(tFar, tn);
    }
    if (tFar <= 0.05) return 0.0;

    vec3 s0 = viewToScreen(viewPos, proj);
    vec3 dS = viewToScreen(viewPos + reflDirView * tFar, proj) - s0;
    if (abs(dS.x) < 1e-8 && abs(dS.y) < 1e-8) return 0.0;

    vec2 crossStep = vec2(dS.x >= 0.0 ? 1.0 : -1.0, dS.y >= 0.0 ? 1.0 : -1.0);
    vec2 crossOff = crossStep * 1e-5;

    float maxDelta = max(max(abs(dS.x), abs(dS.y)), 1e-6);
    float tTexel = 0.25 / (float(max(full.x, full.y)) * maxDelta);
    float pxStep = 1.0 / max(length(dS.xy * vec2(full)), 1.0);

    float t = tTexel * (1.0 + 2.0 * dither);
    vec3 p = s0 + dS * t;
    if (clamp(p.xy, 0.0, 1.0) != p.xy || p.z <= 0.0 || p.z >= 1.0) return 0.0;

    int level = 1;
    float tPrev = t;
    bool found = false;

    for (int i = 0; i < maxIter; i++) {
        vec2 cellCount = hizCellCount(full, level);
        vec2 cell = floor(p.xy * cellCount);
        float minZ = hizFetch(full, level, ivec2(cell)).x;

        float tz = (dS.z > 1e-9) ? (max(p.z, minZ) - s0.z) / dS.z : t;
        tz = max(tz, t);
        vec3 q = s0 + dS * tz;
        vec2 newCell = floor(q.xy * cellCount);

        if (any(notEqual(newCell, cell))) {
            tPrev = t;
            t = ssrCellExitT(s0.xy, dS.xy, cell, cellCount, crossStep, crossOff) + tTexel;
            p = s0 + dS * t;
            level = min(level + 1, HIZ_LEVELS);
        } else if (level > 1) {
            tPrev = t;
            t = tz;
            p = q;
            level--;
        } else {
            float tExit = ssrCellExitT(s0.xy, dS.xy, cell, cellCount, crossStep, crossOff);
            float ts = max(tz, t);
            for (int k = 0; k < 4; k++) {
                if (ts > tExit) break;
                vec3 r = s0 + dS * ts;
                if (clamp(r.xy, 0.0, 1.0) != r.xy || r.z >= 1.0 || r.z <= 0.0) break;
                float dq = texture(depthTex, r.xy + jitterUV).r;
                if (dq < 1.0 && r.z >= dq) {
                    tPrev = max(ts - pxStep, 0.0);
                    t = ts;
                    p = r;
                    found = true;
                    break;
                }
                ts += pxStep;
            }
            if (found) break;
            tPrev = t;
            t = tExit + tTexel;
            p = s0 + dS * t;
            level = 2;
        }

        if (t >= 1.0 || clamp(p.xy, 0.0, 1.0) != p.xy || p.z <= 0.0 || p.z >= 1.0) return 0.0;
    }
    if (!found) return 0.0;

    float dFull = texture(depthTex, p.xy + jitterUV).r;
    if (dFull >= 1.0) return 0.0;
    vec3 rayView = screenToView(p, projInv);
    vec3 sceneView = screenToView(vec3(p.xy, dFull), projInv);
    vec3 nextView = screenToView(s0 + dS * min(t + pxStep, 1.0), projInv);
    float span = abs(nextView.z - rayView.z);
    float diff = sceneView.z - rayView.z;
    float thickness = min(max(span * 2.2, abs(rayView.z) * 0.01), abs(rayView.z) * 0.50);
    if (diff < -span * 0.5 || diff > thickness) return 0.0;

    float lo = tPrev, hi = t;
    for (int j = 0; j < refineSteps; j++) {
        float mid = (lo + hi) * 0.5;
        vec3 mp = s0 + dS * mid;
        float md = texture(depthTex, mp.xy + jitterUV).r;
        vec3 mv = screenToView(vec3(mp.xy, md), projInv);
        if (mv.z - screenToView(mp, projInv).z > 0.0) hi = mid; else lo = mid;
    }
    hitScreen = s0 + dS * ((lo + hi) * 0.5);

    vec2 border = min(hitScreen.xy, 1.0 - hitScreen.xy);
    float edge = saturate(min(border.x, border.y) * 16.0);
    float certainty = saturate(1.0 - (hi - lo) * length(dS.xy) * float(max(full.x, full.y)) * 0.25);
    return edge * mix(0.55, 1.0, certainty);
}
#endif

float ssrStepGrowth(float baseStep, float maxStepLen, int steps) {
    return pow(maxStepLen / baseStep, 1.0 / float(max(steps - 1, 1)));
}

float ssrTotalReach(float baseStep, float maxStepLen, int steps) {
    float r = ssrStepGrowth(baseStep, maxStepLen, steps);
    return abs(r - 1.0) < 1e-4 ? baseStep * float(steps)
                               : baseStep * (pow(r, float(steps)) - 1.0) / (r - 1.0);
}

float ssrRayQuality(float roughness) {
#ifdef SSR_ADAPTIVE_ACTIVE
    return mix(1.0, SSR_ADAPTIVE_FLOOR, saturate(roughness / max(SSR_ROUGH_LIMIT, 1e-3)));
#else
    return 1.0;
#endif
}

int ssrScaledSteps(int steps, float quality, int floorSteps) {
    return max(int(float(steps) * clamp(quality, 0.10, 1.0) + 0.5), floorSteps);
}

bool ssrTraceThisFrame(vec2 px, int frame, float roughness) {
#if defined SSR_ADAPTIVE_ACTIVE && SSR_REUSE_FRAMES > 1
    if (roughness < SSR_REUSE_ROUGHNESS) return true;
    return ((int(px.x) + int(px.y) + frame) % SSR_REUSE_FRAMES) == 0;
#else
    return true;
#endif
}

float raymarchSSR(sampler2D depthTex, ivec2 full, vec3 viewPos, vec3 reflDirView, mat4 proj, mat4 projInv, float dither, vec2 jitterUV, float quality, out vec3 hitScreen) {
    int steps = ssrScaledSteps(PERF_SCALED_COUNT(SSR_STEPS, 6), quality, 6);
#if SSR_TRACER == 2
    return raymarchSSRHiZ(depthTex, full, viewPos, reflDirView, proj, projInv, dither, jitterUV, max(steps + 12, 32), 4, ssrTotalReach(0.40, 40.0, steps), hitScreen);
#else
    const float baseStep = 0.40;
    return raymarchSSRCustom(depthTex, viewPos, reflDirView, proj, projInv, dither, jitterUV, steps, 4, baseStep, ssrStepGrowth(baseStep, 40.0, steps), hitScreen);
#endif
}

float raymarchSSRFast(sampler2D depthTex, ivec2 full, vec3 viewPos, vec3 reflDirView,
                      mat4 proj, mat4 projInv, float dither, vec2 jitterUV, float quality, out vec3 hitScreen) {
    int steps = ssrScaledSteps(max(PERF_SCALED_COUNT(min(SSR_STEPS, 10), 4), 4), quality, 4);
#if SSR_TRACER == 2
    return raymarchSSRHiZ(depthTex, full, viewPos, reflDirView, proj, projInv, dither, jitterUV, max(steps + 8, 20), 2, ssrTotalReach(0.60, 14.0, steps), hitScreen);
#else
    const float baseStep = 0.60;
    return raymarchSSRCustom(depthTex, viewPos, reflDirView, proj, projInv, dither, jitterUV, steps, 2, baseStep, ssrStepGrowth(baseStep, 14.0, steps), hitScreen);
#endif
}

#endif
