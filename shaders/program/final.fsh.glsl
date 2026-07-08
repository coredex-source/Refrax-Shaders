/* Refrax — program/final.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/post.glsl"

const bool colortex0MipmapEnabled = true;

uniform sampler2D colortex0;
uniform float viewWidth, viewHeight;
uniform ivec2 eyeBrightnessSmooth;
uniform int frameCounter;

in vec2 uv;

layout(location = 0) out vec4 outColor;

vec3 bloomSample(vec2 coord) {
    vec3 bloom = vec3(0.0);
    float wsum = 0.0;
    for (int i = 2; i <= 6; i++) {
        float w = 1.0 / float(i);
        bloom += textureLod(colortex0, coord, float(i)).rgb * w;
        wsum += w;
    }
    return bloom / wsum;
}

vec3 processPixel(vec2 coord, vec3 bloom, float exposure) {
    vec3 hdr = texture(colortex0, coord).rgb;
#ifdef BLOOM
    hdr = mix(hdr, bloom, saturate(BLOOM_STRENGTH * 0.12));
    hdr += bloom * bloom * BLOOM_STRENGTH * 0.05;
#endif
    hdr *= exposure;
    vec3 ldr = applyTonemap(hdr);
    return colorGrade(ldr);
}

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

#ifdef FXAA
#ifndef TAA
    {
        vec3 n = processPixel(uv + vec2(0.0, -px.y), bloom, exposure);
        vec3 s = processPixel(uv + vec2(0.0,  px.y), bloom, exposure);
        vec3 e = processPixel(uv + vec2( px.x, 0.0), bloom, exposure);
        vec3 w = processPixel(uv + vec2(-px.x, 0.0), bloom, exposure);
        float lC = luminance(color);
        float lN = luminance(n), lS = luminance(s), lE = luminance(e), lW = luminance(w);
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
#endif

#ifdef TAA
    vec3 n = processPixel(uv + vec2(0.0, -px.y), bloom, exposure);
    vec3 s = processPixel(uv + vec2(0.0,  px.y), bloom, exposure);
    vec3 e = processPixel(uv + vec2( px.x, 0.0), bloom, exposure);
    vec3 w = processPixel(uv + vec2(-px.x, 0.0), bloom, exposure);
    color = saturate(sharpen(color, n, s, e, w, 0.35));
#endif

    color += (ign(gl_FragCoord.xy) - 0.5) / 255.0;
    outColor = vec4(color, 1.0);
}
