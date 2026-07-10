/* Refrax — program/final.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/post.glsl"
#include "/lib/bloom.glsl"
#if SHARPEN_MODE == 1
#include "/lib/cas.glsl"
#elif SHARPEN_MODE == 2
#include "/lib/fsr1.glsl"
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform float viewWidth, viewHeight;
uniform ivec2 eyeBrightnessSmooth;
uniform int frameCounter;
#ifdef ATAA
uniform sampler2D depthtex0;
uniform float near, far;
#endif

in vec2 uv;

layout(location = 0) out vec4 outColor;

vec3 bloomSample(vec2 coord) {
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    vec3 bloom = vec3(0.0);
    for (int i = 0; i < BLOOM_LEVELS; i++) {
        float s = bloomLevelScale(i);
        vec2 pad = 0.75 * px / s;
        vec2 uvT = vec2(0.0, bloomLevelY(i)) + clamp(coord, pad, 1.0 - pad) * s;
        bloom += texture(colortex4, uvT).rgb;
    }
    return bloom / float(BLOOM_LEVELS);
}

vec3 processPixel(vec2 coord, vec3 bloom, float exposure) {
    vec3 hdr = texture(colortex0, coord).rgb;
#ifdef BLOOM
    hdr = mix(hdr, bloom, saturate(BLOOM_STRENGTH * 0.12));
#endif
    hdr *= exposure;
    vec3 ldr = applyTonemap(hdr);
    return colorGrade(ldr);
}

#ifdef MORPH_AA
float aaLuma(vec2 c, vec3 bloom, float exposure) {
    return luminance(processPixel(c, bloom, exposure));
}

float aaEdgeLength(vec2 uv, vec2 along, vec2 crossN, float refDelta, vec3 bloom, float exposure) {
    float dist = 0.0;
    for (int i = 1; i <= SMAA_SEARCH_STEPS; i++) {
        vec2 c = uv + along * float(i);
        float d = abs(aaLuma(c, bloom, exposure) - aaLuma(c + crossN, bloom, exposure));
        if (d < refDelta * 0.5) break;
        dist += 1.0;
    }
    return dist;
}

vec3 morphAA(vec2 uv, vec3 color, vec2 px, vec3 bloom, float exposure) {
    float lC = luminance(color);
    float lL = aaLuma(uv + vec2(-px.x, 0.0), bloom, exposure);
    float lR = aaLuma(uv + vec2( px.x, 0.0), bloom, exposure);
    float lU = aaLuma(uv + vec2(0.0, -px.y), bloom, exposure);
    float lD = aaLuma(uv + vec2(0.0,  px.y), bloom, exposure);

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

    float total = aaEdgeLength(uv, -along, crossN, refDelta, bloom, exposure)
                + aaEdgeLength(uv,  along, crossN, refDelta, bloom, exposure);
    float coverage = mix(0.2, 0.5, saturate(total / float(SMAA_SEARCH_STEPS)));

    vec3 neighbor = processPixel(uv + crossN, bloom, exposure);
    return mix(color, neighbor, saturate(coverage * SMAA_STRENGTH));
}
#endif

#ifdef ATAA
float ataaDepthEdge(vec2 uv, vec2 px) {
    float dC = linearizeDepth(texture(depthtex0, uv).r, near, far);
    float dL = linearizeDepth(texture(depthtex0, uv + vec2(-px.x, 0.0)).r, near, far);
    float dR = linearizeDepth(texture(depthtex0, uv + vec2( px.x, 0.0)).r, near, far);
    float dU = linearizeDepth(texture(depthtex0, uv + vec2(0.0, -px.y)).r, near, far);
    float dD = linearizeDepth(texture(depthtex0, uv + vec2(0.0,  px.y)).r, near, far);
    float dMax = max(max(abs(dC - dL), abs(dC - dR)), max(abs(dC - dU), abs(dC - dD)));
    return dMax / max(dC, 1e-3);
}
#endif

void main() {
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
#ifdef BLOOM
    vec3 bloom = bloomSample(uv);
#else
    vec3 bloom = vec3(0.0);
#endif
#if defined WORLD_NETHER || defined WORLD_END
    float exposure = EXPOSURE * DIMENSION_EXPOSURE;
#else
    float eyeSky = float(eyeBrightnessSmooth.y) / 240.0;
    float exposure = EXPOSURE * mix(1.30, 0.82, eyeSky);
#endif

    vec3 color = processPixel(uv, bloom, exposure);

#if defined FXAA || defined TEMPORAL_AA || SHARPEN_MODE > 0
    vec3 cN = processPixel(uv + vec2(0.0, -px.y), bloom, exposure);
    vec3 cS = processPixel(uv + vec2(0.0,  px.y), bloom, exposure);
    vec3 cE = processPixel(uv + vec2( px.x, 0.0), bloom, exposure);
    vec3 cW = processPixel(uv + vec2(-px.x, 0.0), bloom, exposure);
#endif

#if defined FXAA && !(defined UPSCALING && defined TEMPORAL_AA)
    {
        float lC = luminance(color);
        float lN = luminance(cN), lS = luminance(cS), lE = luminance(cE), lW = luminance(cW);
        float lMin = min(lC, min(min(lN, lS), min(lE, lW)));
        float lMax = max(lC, max(max(lN, lS), max(lE, lW)));
        float range = lMax - lMin;
        if (range > max(0.05, lMax * 0.12)) {
            vec2 dir = normalize(vec2(-((lN + lS) - 2.0 * lC), ((lE + lW) - 2.0 * lC)) + 1e-6);
            vec3 blur = (processPixel(uv + dir * px * 0.75, bloom, exposure) + processPixel(uv - dir * px * 0.75, bloom, exposure)) * 0.5;
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
        color = morphAA(uv, color, px, bloom, exposure);
  #else
    color = morphAA(uv, color, px, bloom, exposure);
  #endif
#endif

#if SHARPEN_MODE == 1
    if (SHARPEN_STRENGTH > 0.0) {
        vec3 cNW = processPixel(uv + vec2(-px.x, -px.y), bloom, exposure);
        vec3 cNE = processPixel(uv + vec2( px.x, -px.y), bloom, exposure);
        vec3 cSW = processPixel(uv + vec2(-px.x,  px.y), bloom, exposure);
        vec3 cSE = processPixel(uv + vec2( px.x,  px.y), bloom, exposure);
        color = casSharpen(cNW, cN, cNE, cW, color, cE, cSW, cS, cSE, SHARPEN_STRENGTH);
    }
#elif SHARPEN_MODE == 2
    if (SHARPEN_STRENGTH > 0.0)
        color = rcasSharpen(cN, cW, color, cE, cS, exp2(-2.0 * (1.0 - SHARPEN_STRENGTH)));
#endif

    color += (ign(gl_FragCoord.xy) - 0.5) / 255.0;
    outColor = vec4(color, 1.0);
}
