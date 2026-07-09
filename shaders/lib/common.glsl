/* Refrax — lib/common.glsl */
#ifndef REFRAX_COMMON
#define REFRAX_COMMON

const float PI = 3.14159265359;
#define saturate(x) clamp(x, 0.0, 1.0)

float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3  srgbToLinear(vec3 c) { return pow(c, vec3(2.2)); }
vec3  linearToSrgb(vec3 c) { return pow(max(c, 0.0), vec3(1.0 / 2.2)); }


float ign(vec2 px) {
    return fract(52.9829189 * fract(0.06711056 * px.x + 0.00583715 * px.y));
}
float ignAnim(vec2 px, int frame) {
    return ign(px + 5.588238 * float(frame % 64));
}

vec3 screenToView(vec3 screenPos, mat4 projInv) {
    vec4 ndc = vec4(screenPos * 2.0 - 1.0, 1.0);
    vec4 v = projInv * ndc;
    return v.xyz / v.w;
}
vec3 viewToScreen(vec3 viewPos, mat4 proj) {
    vec4 c = proj * vec4(viewPos, 1.0);
    return c.xyz / c.w * 0.5 + 0.5;
}
float linearizeDepth(float d, float near, float far) {
    return (2.0 * near * far) / (far + near - (d * 2.0 - 1.0) * (far - near));
}


vec3 reprojectScene(vec3 scenePos, mat4 prevMV, mat4 prevProj, vec3 camPos, vec3 prevCamPos) {
    vec3 prevScene = scenePos + camPos - prevCamPos;
    vec4 clip = prevProj * (prevMV * vec4(prevScene, 1.0));
    return clip.xyz / clip.w * 0.5 + 0.5;
}

#ifndef FSR_SCALE
#define FSR_SCALE 1.0
#endif
vec2 fsrRegionUV(vec2 sceneUV, vec2 texel) {
    return clamp(sceneUV * FSR_SCALE, vec2(0.0), vec2(FSR_SCALE) - 0.5 * texel);
}

vec2 taaOffset(int frame) {
    const vec2 halton[8] = vec2[8](
        vec2(0.5000, 0.3333), vec2(0.2500, 0.6667), vec2(0.7500, 0.1111), vec2(0.1250, 0.4444),
        vec2(0.6250, 0.7778), vec2(0.3750, 0.2222), vec2(0.8750, 0.5556), vec2(0.0625, 0.8889));
    return halton[frame % 8] - 0.5;
}
vec4 taaJitterPos(vec4 clipPos, vec2 viewSize, int frame) {
#ifdef TEMPORAL_AA
    clipPos.xy += taaOffset(frame) * 2.0 * clipPos.w / viewSize;
#endif
    return clipPos;
}

vec3 discLightSpecular(vec3 N, vec3 V, vec3 L, float sinRadius, float roughness, vec3 f0) {
    vec3 R = reflect(-V, N);
    vec3 toRay = R * dot(L, R) - L;
    vec3 Lr = normalize(L + toRay * saturate(sinRadius / max(length(toRay), 1e-5)));
    vec3 H = normalize(V + Lr);
    float NoH = saturate(dot(N, H)), NoV = max(dot(N, V), 1e-4), NoL = saturate(dot(N, Lr));
    float a  = max(roughness * roughness, 2e-3);
    float ap = min(a + 0.5 * sinRadius, 1.0);
    float norm = a / ap; norm *= norm;
    float ap2 = ap * ap;
    float d = (NoH * ap2 - NoH) * NoH + 1.0;
    float D = ap2 / (PI * d * d) * norm;
    vec3  F = f0 + (1.0 - f0) * pow(1.0 - saturate(dot(V, H)), 5.0);
    float G = 0.5 / mix(2.0 * NoL * NoV, NoL + NoV, ap);
    return min(D * G * NoL, 32.0) * F;
}
vec3 fresnelSchlick(float cosT, vec3 f0) {
    return f0 + (1.0 - f0) * pow(1.0 - saturate(cosT), 5.0);
}

vec3 waterDiscLightSpecular(vec3 N, vec3 V, vec3 L, float sinRadius, float roughness, vec3 f0) {
    vec3 base = discLightSpecular(N, V, L, sinRadius, roughness, f0);
    vec3 R = reflect(-V, N);
    vec3 H = normalize(V + L);

    float NoL = saturate(dot(N, L));
    float NoV = saturate(dot(N, V));
    float LoH = saturate(dot(L, H));
    float RoL = saturate(dot(R, L));
    float miss = max(1.0 - RoL, 0.0);

    float radius = max(sinRadius, 1e-3);
    float radius2 = radius * radius;
    float core = exp2(-miss / max(radius2 * 0.42, 6e-4));
    float halo = exp2(-miss / max(radius2 * 2.80, 3e-3));
    float visibility = smoothstep(0.01, 0.18, NoL) * smoothstep(0.01, 0.10, NoV);

    vec3 F = fresnelSchlick(LoH, f0);
    return base * 0.75 + (core * 2.40 + halo * 0.55) * F * NoL * visibility;
}

#endif
