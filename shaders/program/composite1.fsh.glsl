/* Refrax — program/composite1.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#if defined TAAU || defined FSR
#include "/lib/taau.glsl"
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;
uniform vec3 cameraPosition, previousCameraPosition;
uniform float viewWidth, viewHeight;
uniform int frameCounter;

in vec2 uv;

/* RENDERTARGETS: 0,5 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outHistory;

#ifdef TEMPORAL_AA
float max3(vec3 v) { return max(v.x, max(v.y, v.z)); }
vec3 taaTonemap(vec3 c)   { return c / (1.0 + max3(c)); }
vec3 taaUntonemap(vec3 c) { return c / max(1.0 - max3(c), 1e-4); }

vec3 clipToAABB(vec3 h, vec3 mn, vec3 mx) {
    vec3 c = 0.5 * (mx + mn);
    vec3 e = 0.5 * (mx - mn) + 1e-5;
    vec3 v = h - c;
    vec3 a = abs(v / e);
    float m = max(a.x, max(a.y, a.z));
    return m > 1.0 ? c + v / m : h;
}
#endif

#ifdef TAAU
void main() {
    vec2 viewSize = vec2(viewWidth, viewHeight);
    vec2 px = 1.0 / viewSize;
    vec2 inSize = floor(viewSize * UPSCALE_SCALE);
    vec2 regionMax = inSize - 0.5;

    float reflectable = texture(colortex2, uv).a > 2.5 ? 0.0 : 1.0;

    vec2 posPx = uv * inSize + taauOffset(frameCounter);
    vec2 posUV = clamp(posPx, vec2(0.5), regionMax) * px;
    vec4 c0 = texture(colortex0, posUV);

    float confidence;
    vec3 current = catmullRomRegion(colortex0, posPx, px, regionMax, confidence).rgb;
    if (any(isnan(current)) || min(current.r, min(current.g, current.b)) < 0.0)
        current = c0.rgb;
    if (any(isnan(current))) current = vec3(0.0);
    current = max(current, vec3(0.0));

    ivec2 t0 = ivec2(gl_FragCoord.xy);
    ivec2 tmax = ivec2(viewSize) - 1;
    float centerDepth = texelFetch(depthtex0, t0, 0).r;
    vec3 closest = vec3(gl_FragCoord.xy, centerDepth);
    for (int i = 0; i < 4; i++) {
        ivec2 o = ivec2(((i & 1) == 0) ? -2 : 2, (i < 2) ? -2 : 2);
        ivec2 t = clamp(t0 + o, ivec2(0), tmax);
        float d = texelFetch(depthtex0, t, 0).r;
        if (d < closest.z) closest = vec3(vec2(t) + 0.5, d);
    }
    if (closest.z < 0.56 && centerDepth >= 0.56) closest = vec3(gl_FragCoord.xy, centerDepth);
    vec2 closestUV = closest.xy * px;

    vec3 prevUV;
    float distFactor = 0.0;
    if (closest.z < 0.56) {
        prevUV = vec3(uv, closest.z);
    } else {
        vec3 viewPos = screenToView(vec3(closestUV, closest.z), gbufferProjectionInverse);
        vec3 scenePos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        vec3 reproj = closest.z >= 1.0
            ? reprojectScene(scenePos, gbufferPreviousModelView, gbufferPreviousProjection, previousCameraPosition, previousCameraPosition)
            : reprojectScene(scenePos, gbufferPreviousModelView, gbufferPreviousProjection, cameraPosition, previousCameraPosition);
        prevUV = vec3(uv - (closestUV - reproj.xy), reproj.z);
        distFactor = 1.0 - exp2(-0.025 * length(viewPos));
    }

    if (clamp(prevUV.xy, 0.0, 1.0) != prevUV.xy) {
        outColor = vec4(current, 1.0);
        outHistory = vec4(current, reflectable > 0.5 ? 1.0 : -1.0);
        return;
    }

    float histConfidence;
    vec3 hist = catmullRomRegion(colortex5, prevUV.xy * viewSize, px, viewSize - 0.5, histConfidence).rgb;
    if (any(isnan(hist))) hist = current;
    hist = max(hist, vec3(0.0));

    float histA = texelFetch(colortex5, ivec2(prevUV.xy * viewSize), 0).a;
    if (isnan(histA)) histA = 1.0;
    float age = clamp(abs(histA), 0.0, TAAU_MAX_AGE) + 1.0;

    ivec2 itex = ivec2(clamp(posPx, vec2(0.5), regionMax));
    ivec2 maxT = ivec2(inSize) - 1;
    #define TAAU_FETCH(dx, dy) rgbToYcocg(taaTonemap(max(texelFetch(colortex0, clamp(itex + ivec2(dx, dy), ivec2(0), maxT), 0).rgb, vec3(0.0))))
    vec3 nA = TAAU_FETCH(-1,  1), nB = TAAU_FETCH(0,  1), nC = TAAU_FETCH(1,  1);
    vec3 nD = TAAU_FETCH(-1,  0), nE = TAAU_FETCH(0,  0), nF = TAAU_FETCH(1,  0);
    vec3 nG = TAAU_FETCH(-1, -1), nH = TAAU_FETCH(0, -1), nI = TAAU_FETCH(1, -1);
    #undef TAAU_FETCH

    vec3 mn = min(nB, min(min(nD, nE), min(nF, nH)));
    mn = 0.5 * (mn + min(mn, min(min(nA, nC), min(nG, nI))));
    vec3 mx = max(nB, max(max(nD, nE), max(nF, nH)));
    mx = 0.5 * (mx + max(mx, max(max(nA, nC), max(nG, nI))));

    vec3 m1 = nA + nB + nC + nD + nE + nF + nG + nH + nI;
    vec3 m2 = nA * nA + nB * nB + nC * nC + nD * nD + nE * nE
            + nF * nF + nG * nG + nH * nH + nI * nI;
    vec3 mu = m1 / 9.0;
    vec3 sigma = sqrt(max(m2 / 9.0 - mu * mu, 0.0));
    float gamma = mix(0.75, 1.25, saturate((distFactor - 0.25) / 0.75));
    mn = max(mn, mu - gamma * sigma);
    mx = min(mx, mu + gamma * sigma);

    vec3 cw = rgbToYcocg(taaTonemap(current));
    vec3 hw = rgbToYcocg(taaTonemap(hist));

    bool clipped;
    hw = taauClipAabb(hw, mn, mx, clipped);
    float flicker = clipped ? 0.0 : taauFlickerReduction(hw, mn, mx);

    float alpha = max(1.0 / age, 1.0 - TAA_BLEND);
    alpha *= pow(confidence, TAAU_CONFIDENCE_REJECTION);
    alpha *= 1.0 - TAAU_FLICKER_REDUCTION * flicker;
    if (c0.a < 0.5) alpha = max(alpha, 0.85);

    vec2 pixOff = 1.0 - abs(2.0 * fract(viewSize * prevUV.xy) - 1.0);
    float offRej = sqrt(pixOff.x * pixOff.y) * TAAU_OFFCENTER_REJECTION + (1.0 - TAAU_OFFCENTER_REJECTION);
    alpha = 1.0 - (1.0 - alpha) * offRej;

    vec3 resolvedW = ycocgToRgb(mix(hw, cw, saturate(alpha)));
    vec3 resolved = min(taaUntonemap(max(resolvedW, vec3(0.0))), vec3(60000.0));
    vec3 outW = max(resolvedW + (resolvedW - ycocgToRgb(mu)) * TAAU_OUTPUT_SHARPEN, vec3(0.0));

    float ageOut = max(min(age * offRej, TAAU_MAX_AGE), 1.0);
    outColor = vec4(min(taaUntonemap(outW), vec3(60000.0)), 1.0);
    outHistory = vec4(resolved, reflectable > 0.5 ? ageOut : -ageOut);
}

#else

void main() {
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    vec2 ruv = fsrRegionUV(uv, px);
    vec4 c0 = texture(colortex0, ruv);
    vec3 current = c0.rgb;
    if (any(isnan(current))) current = vec3(0.0);
    current = max(current, vec3(0.0));
    float reflectable = texture(colortex2, uv).a > 2.5 ? 0.0 : 1.0;
#ifndef TEMPORAL_AA
    outColor = vec4(current, 1.0);
    outHistory = vec4(current, reflectable);
#else
    float depth = texture(depthtex0, uv).r;
    vec3 prevUV;
    if (depth < 0.56) {
        prevUV = vec3(uv, depth);
    } else if (depth >= 1.0) {
        vec3 viewPos = screenToView(vec3(uv, depth), gbufferProjectionInverse);
        vec3 scenePos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        prevUV = reprojectScene(scenePos, gbufferPreviousModelView, gbufferPreviousProjection, previousCameraPosition, previousCameraPosition);
    } else {
        vec3 viewPos = screenToView(vec3(uv, depth), gbufferProjectionInverse);
        vec3 scenePos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        prevUV = reprojectScene(scenePos, gbufferPreviousModelView, gbufferPreviousProjection, cameraPosition, previousCameraPosition);
    }

    if (clamp(prevUV.xy, 0.0, 1.0) != prevUV.xy) {
        outColor = vec4(current, 1.0);
        outHistory = vec4(current, reflectable);
        return;
    }

    vec3 cw = taaTonemap(current);
    vec3 m1 = cw, m2 = cw * cw;
    vec2 rMax = vec2(FSR_SCALE) - 0.5 * px;
    for (int x = -1; x <= 1; x++)
    for (int y = -1; y <= 1; y++) {
        if (x == 0 && y == 0) continue;
        vec3 s = taaTonemap(texture(colortex0, clamp(ruv + vec2(x, y) * px, vec2(0.0), rMax)).rgb);
        m1 += s; m2 += s * s;
    }
    vec3 mu = m1 / 9.0;
    vec3 sigma = sqrt(max(m2 / 9.0 - mu * mu, 0.0));
#ifdef FSR
    float histConfidence;
    vec2 histPos = fsrRegionUV(prevUV.xy, px) * vec2(viewWidth, viewHeight);
    vec2 histMax = floor(vec2(viewWidth, viewHeight) * FSR_SCALE) - 0.5;
    vec3 hist = catmullRomRegion(colortex5, histPos, px, histMax, histConfidence).rgb;
#else
    vec3 hist = texture(colortex5, fsrRegionUV(prevUV.xy, px)).rgb;
#endif
    if (any(isnan(hist))) hist = current;
    vec3 hw = taaTonemap(max(hist, vec3(0.0)));
    float motion = length((prevUV.xy - uv) / px);
#ifdef FSR
    float clipGamma = mix(2.5, 1.0, saturate(motion * 0.5));
    float blend = TAA_BLEND * saturate(1.0 - motion * 0.03 / FSR_SCALE);
#else
    const float clipGamma = TAA_CLIP_GAMMA;
    float blend = TAA_BLEND * saturate(1.0 - motion * 0.03);
#endif
    hw = clipToAABB(hw, mu - clipGamma * sigma, mu + clipGamma * sigma);

    if (c0.a < 0.5) blend = min(blend, 0.15);
    vec3 resolvedW = mix(cw, hw, blend);
#ifdef FSR
    vec3 outW = max(resolvedW + (resolvedW - mu) * 0.35, 0.0);
#else
    vec3 outW = resolvedW;
#endif
    vec3 resolved = min(taaUntonemap(resolvedW), vec3(60000.0));
    outColor = vec4(min(taaUntonemap(outW), vec3(60000.0)), 1.0);
    outHistory = vec4(resolved, reflectable);
#endif
}
#endif
