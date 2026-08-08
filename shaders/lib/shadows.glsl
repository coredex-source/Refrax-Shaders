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


#ifdef CONTACT_SHADOWS_ACTIVE
float contactShadow(sampler2D depthTex, ivec2 full, vec3 viewPos, vec3 viewNormal, vec3 lightDirView, float NoL, float dither, mat4 proj, mat4 projInv) {
    float dist = length(viewPos);
    float fade = 1.0 - smoothstep(CONTACT_SHADOW_DISTANCE * 0.75, CONTACT_SHADOW_DISTANCE, dist);
    if (fade <= 0.0) return 1.0;

    vec3 origin = viewPos + viewNormal * (0.012 + dist * 0.006) * (2.0 - saturate(NoL));
    vec3 rayStep = lightDirView * (CONTACT_SHADOW_LENGTH / float(CONTACT_SHADOW_STEPS));

    vec4 clip = proj * vec4(origin + rayStep * (1.0 + dither), 1.0);
    vec4 clipStep = proj * vec4(rayStep, 0.0);
    vec4 clipEnd = clip + clipStep * float(CONTACT_SHADOW_STEPS - 1);
    if (clip.w <= 1e-4 || clipEnd.w <= 1e-4) return 1.0;

#if defined CONTACT_SHADOW_HIZ_ACTIVE && defined HIZ_READ
    if (hizSegmentClear(full, clip.xyz / clip.w * 0.5 + 0.5, clipEnd.xyz / clipEnd.w * 0.5 + 0.5)) return 1.0;
#endif

    float pz = origin.z + rayStep.z * (1.0 + dither);
    float occ = 0.0;
    for (int i = 0; i < CONTACT_SHADOW_STEPS; i++) {
        vec3 sp = clip.xyz / clip.w * 0.5 + 0.5;
        clip += clipStep;
        float rayZ = pz;
        pz += rayStep.z;
        if (clamp(sp.xy, 0.0, 1.0) != sp.xy) break;
        float d = texture(depthTex, sp.xy).r;
        if (d >= 1.0 || d < HAND_DEPTH_LIMIT) continue;
        float occluderZ = screenToView(vec3(sp.xy, d), projInv).z;
        float gap = occluderZ - rayZ;
        if (gap > 0.008 && gap < CONTACT_SHADOW_THICKNESS + dist * 0.01) { occ = 1.0; break; }
    }
    return 1.0 - occ * CONTACT_SHADOW_STRENGTH * fade;
}
#endif


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

#ifdef PCSS
    {
        float searchR = radius * 2.5;
        float blockerSum = 0.0;
        float blockerHits = 0.0;
        for (int i = 0; i < PCSS_BLOCKER_SAMPLES; i++) {
            float br = sqrt((float(i) + 0.5) / float(PCSS_BLOCKER_SAMPLES));
            float bt = float(i) * 2.39996 + ang;
            vec2 boff = rot * (vec2(cos(bt), sin(bt)) * br) * searchR;
            vec3 bc = distortShadowClip(vec3(clip.xy + boff, clip.z) / clip.w);
            vec3 bsp = bc * 0.5 + 0.5;
            if (clamp(bsp.xy, 0.0, 1.0) != bsp.xy) continue;
            float bd = texture(stex1, bsp.xy).r;
            if (bd < bsp.z - 0.00035) { blockerSum += bd; blockerHits += 1.0; }
        }
        if (blockerHits > 0.5) {
            vec3 centre = distortShadowClip(clip.xyz / clip.w) * 0.5 + 0.5;
            float dz = max(centre.z - blockerSum / blockerHits, 0.0);
            float soften = saturate(dz * PCSS_SOFTEN);
            radius *= mix(PCSS_MIN_SCALE, 1.0, soften);
        }
    }
#endif

#if defined COLORED_SHADOWS || defined CAUSTICS_ACTIVE
    vec3 spC = distortShadowClip(clip.xyz / clip.w) * 0.5 + 0.5;
    vec3 tint = clamp(spC.xy, 0.0, 1.0) == spC.xy
              ? texture(scol0, spC.xy).rgb / SHADOW_COLOR_ENCODE
              : vec3(1.0);
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
    #if defined COLORED_SHADOWS || defined CAUSTICS_ACTIVE
        if (s1 > 0.0) {
            float s0 = step(z, texture(stex0, sp.xy).r);
            sum += mix(tint, vec3(1.0), s0);
        }
    #else
        sum += vec3(s1);
    #endif
    }
    return mix(sum / float(SHADOW_SAMPLES), vec3(1.0), fade);
#endif
}

#endif
