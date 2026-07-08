/* Refrax — lib/shadows.glsl */
#ifndef REFRAX_SHADOWS
#define REFRAX_SHADOWS

#include "/lib/settings.glsl"
#include "/lib/common.glsl"


vec3 distortShadowClip(vec3 clip) {
    float f = length(clip.xy) * 0.9 + 0.1;
    clip.xy /= f;
    clip.z *= 0.5;
    return clip;
}


vec3 getShadow(vec3 scenePos, vec3 worldNormal, float NoL, float dither, mat4 shadowMV, mat4 shadowProj, sampler2D stex0, sampler2D stex1, sampler2D scol0) {
#ifndef SHADOWS
    return vec3(1.0);
#else
    float dist = length(scenePos);
    if (dist > shadowDistance) return vec3(1.0);
    float fade = smoothstep(shadowDistance * 0.85, shadowDistance, dist);

    
    vec3 biased = scenePos + worldNormal * (0.03 + dist * 0.012) * (2.0 - saturate(NoL));
    vec4 clip = shadowProj * (shadowMV * vec4(biased, 1.0));

    float ang = dither * 2.0 * PI;
    mat2 rot = mat2(cos(ang), -sin(ang), sin(ang), cos(ang));
    float radius = SHADOW_SOFTNESS * 3.0 / float(shadowMapResolution) * clip.w;

#ifdef COLORED_SHADOWS
    vec3 spC = distortShadowClip(clip.xyz / clip.w) * 0.5 + 0.5;
    vec3 tint = clamp(spC.xy, 0.0, 1.0) == spC.xy ? texture(scol0, spC.xy).rgb : vec3(1.0);
#endif

    vec3 sum = vec3(0.0);
    for (int i = 0; i < SHADOW_SAMPLES; i++) {

        float r = sqrt((float(i) + 0.5) / float(SHADOW_SAMPLES));
        float t = float(i) * 2.39996;
        vec2 off = rot * (vec2(cos(t), sin(t)) * r) * radius;
        vec3 c = distortShadowClip(vec3(clip.xy + off, clip.z) / clip.w);
        vec3 sp = c * 0.5 + 0.5;
        if (clamp(sp.xy, 0.0, 1.0) != sp.xy) { sum += vec3(1.0); continue; }
        float z = sp.z - 0.00035;
        float s1 = step(z, texture(stex1, sp.xy).r);
    #ifdef COLORED_SHADOWS
        float s0 = step(z, texture(stex0, sp.xy).r);
        sum += s1 * mix(tint, vec3(1.0), s0);
    #else
        sum += vec3(s1);
    #endif
    }
    return mix(sum / float(SHADOW_SAMPLES), vec3(1.0), fade);
#endif
}

#endif
