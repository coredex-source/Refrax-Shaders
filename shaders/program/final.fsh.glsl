/* Refrax — program/final.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/post.glsl"
#include "/lib/lens.glsl"
#if SHARPEN_MODE == 1
#include "/lib/cas.glsl"
#elif SHARPEN_MODE == 2
#include "/lib/fsr1.glsl"
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex2;
#ifdef VOXY
uniform sampler2D colortex9;
#endif
uniform float viewWidth, viewHeight;
#ifdef FILM_GRAIN
uniform int frameCounter;
#endif
#ifdef ATAA
uniform sampler2D depthtex0;
uniform float near, far;
#endif

in vec2 uv;

layout(location = 0) out vec4 outColor;

vec3 gradedAt(vec2 coord) { return texture(colortex0, coord).rgb; }

#ifdef MORPH_AA
float aaLuma(vec2 c) { return luminance(gradedAt(c)); }

float aaEdgeLength(vec2 uv, vec2 along, vec2 crossN, float refDelta) {
    float dist = 0.0;
    for (int i = 1; i <= SMAA_SEARCH_STEPS; i++) {
        vec2 c = uv + along * float(i);
        float d = abs(aaLuma(c) - aaLuma(c + crossN));
        if (d < refDelta * 0.5) break;
        dist += 1.0;
    }
    return dist;
}

vec3 morphAA(vec2 uv, vec3 color, vec2 px) {
    float lC = luminance(color);
    float lL = aaLuma(uv + vec2(-px.x, 0.0));
    float lR = aaLuma(uv + vec2( px.x, 0.0));
    float lU = aaLuma(uv + vec2(0.0, -px.y));
    float lD = aaLuma(uv + vec2(0.0, px.y));

    float dH = abs(lR - lL);
    float dV = abs(lD - lU);
    if (max(dH, dV) < SMAA_EDGE_THRESHOLD) return color;

    bool horiz = dV >= dH;
    vec2 along = horiz ? vec2(px.x, 0.0) : vec2(0.0, px.y);
    vec2 crossN;
    float refDelta;
    if (horiz) {
        refDelta = dV;
        crossN = vec2(0.0, px.y) * (abs(lD - lC) >= abs(lU - lC) ? 1.0 : -1.0);
    } else {
        refDelta = dH;
        crossN = vec2(px.x, 0.0) * (abs(lR - lC) >= abs(lL - lC) ? 1.0 : -1.0);
    }

    float total = aaEdgeLength(uv, -along, crossN, refDelta)
                + aaEdgeLength(uv, along, crossN, refDelta);
    float coverage = mix(0.2, 0.5, saturate(total / float(SMAA_SEARCH_STEPS)));

    return mix(color, gradedAt(uv + crossN), saturate(coverage * SMAA_STRENGTH));
}
#endif

#ifdef ATAA
float ataaDepthEdge(vec2 uv, vec2 px) {
    float dC = linearizeDepth(texture(depthtex0, uv).r, near, far);
    float dL = linearizeDepth(texture(depthtex0, uv + vec2(-px.x, 0.0)).r, near, far);
    float dR = linearizeDepth(texture(depthtex0, uv + vec2( px.x, 0.0)).r, near, far);
    float dU = linearizeDepth(texture(depthtex0, uv + vec2(0.0, -px.y)).r, near, far);
    float dD = linearizeDepth(texture(depthtex0, uv + vec2(0.0, px.y)).r, near, far);
    float dMax = max(max(abs(dC - dL), abs(dC - dR)), max(abs(dC - dU), abs(dC - dD)));
    return dMax / max(dC, 1e-3);
}
#endif

void main() {
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    vec3 color = gradedAt(uv);
    bool waterPixel = unpackSurfaceWater(texture(colortex2, uv));
#ifdef VOXY
    waterPixel = waterPixel || unpackSurfaceWater(texture(colortex9, uv));
#endif

#if defined FXAA || defined TEMPORAL_AA || SHARPEN_MODE > 0
    vec3 cN = gradedAt(uv + vec2(0.0, -px.y));
    vec3 cS = gradedAt(uv + vec2(0.0, px.y));
    vec3 cE = gradedAt(uv + vec2( px.x, 0.0));
    vec3 cW = gradedAt(uv + vec2(-px.x, 0.0));
#endif

#if defined FXAA && !(defined UPSCALING && defined TEMPORAL_AA)
    {
        float lC = luminance(color);
        float lN = luminance(cN), lS = luminance(cS), lE = luminance(cE), lW = luminance(cW);
        float lMin = min(lC, min(min(lN, lS), min(lE, lW)));
        float lMax = max(lC, max(max(lN, lS), max(lE, lW)));
        float range = lMax - lMin;
        if (!waterPixel && range > max(0.05, lMax * 0.12)) {
            vec2 dir = normalize(vec2(-((lN + lS) - 2.0 * lC), ((lE + lW) - 2.0 * lC)) + 1e-6);
            vec3 blur = (gradedAt(uv + dir * px * 0.75) + gradedAt(uv - dir * px * 0.75)) * 0.5;
            color = mix(color, blur, saturate(range * 3.0));
        }
    }
#endif

#if defined TEMPORAL_AA && SHARPEN_MODE == 0
    color = saturate(sharpen(color, cN, cS, cE, cW, 0.35));
#endif

#ifdef MORPH_AA
  #ifdef ATAA
    if (ataaDepthEdge(uv, px) > ATAA_DEPTH_EDGE)
        color = morphAA(uv, color, px);
  #else
    color = morphAA(uv, color, px);
  #endif
#endif

#if SHARPEN_MODE == 1
    if (SHARPEN_STRENGTH > 0.0) {
        vec3 cNW = gradedAt(uv + vec2(-px.x, -px.y));
        vec3 cNE = gradedAt(uv + vec2( px.x, -px.y));
        vec3 cSW = gradedAt(uv + vec2(-px.x, px.y));
        vec3 cSE = gradedAt(uv + vec2( px.x, px.y));
        color = casSharpen(cNW, cN, cNE, cW, color, cE, cSW, cS, cSE, SHARPEN_STRENGTH);
    }
#elif SHARPEN_MODE == 2
    if (SHARPEN_STRENGTH > 0.0)
        color = rcasSharpen(cN, cW, color, cE, cS, exp2(-2.0 * (1.0 - SHARPEN_STRENGTH)));
#endif

#ifdef CHROMATIC_ABERRATION
    {
        vec2 d = uv - 0.5;
        vec2 off = d * (dot(d, d) * CHROMATIC_STRENGTH * 0.0040);
        vec3 base = gradedAt(uv);
        color.r += gradedAt(clamp(uv + off, vec2(0.0), vec2(1.0))).r - base.r;
        color.b += gradedAt(clamp(uv - off, vec2(0.0), vec2(1.0))).b - base.b;
    }
#endif

#ifdef VIGNETTE
    {
        vec2 d = uv - 0.5;
        color *= saturate(1.0 - dot(d, d) * VIGNETTE_STRENGTH * 1.7);
    }
#endif

#ifdef FILM_GRAIN
    {
        float shadowBias = mix(1.0, 0.32, smoothstep(0.05, 0.65, luminance(color)));
        color += filmGrain(gl_FragCoord.xy, frameCounter) * (FILM_GRAIN_STRENGTH * 0.055 * shadowBias);
    }
#endif

    color += (ign(gl_FragCoord.xy) - 0.5) / 255.0;
    outColor = vec4(saturate(color), 1.0);
}
