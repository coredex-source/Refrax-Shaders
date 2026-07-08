/* Refrax — lib/post.glsl */
#ifndef REFRAX_POST
#define REFRAX_POST

#include "/lib/settings.glsl"
#include "/lib/common.glsl"


vec3 agxContrast(vec3 x) {
    vec3 x2 = x * x, x4 = x2 * x2;
    return 15.5 * x4 * x2 - 40.14 * x4 * x + 31.96 * x4
         - 6.868 * x2 * x + 0.4298 * x2 + 0.1191 * x - 0.00232;
}
vec3 tonemapAgX(vec3 c) {
    const mat3 agxMat = mat3(
        0.842479062253094, 0.0423282422610123, 0.0423756549057051,
        0.0784335999999992, 0.878468636469772, 0.0784336,
        0.0792237451477643, 0.0791661274605434, 0.879142973793104);
    const mat3 agxMatInv = mat3(
        1.19687900512017, -0.0528968517574562, -0.0529716355144438,
        -0.0980208811401368, 1.15190312990417, -0.0980434501171241,
        -0.0990297440797205, -0.0989611768448433, 1.15107367264116);
    const float minEv = -12.47393, maxEv = 4.026069;
    c = agxMat * c;
    c = clamp(log2(max(c, 1e-10)), minEv, maxEv);
    c = (c - minEv) / (maxEv - minEv);
    c = agxContrast(c);
    c = agxMatInv * c;
    return saturate(c); 
}

vec3 tonemapACES(vec3 x) {
    x *= 0.6;
    return saturate((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14));
}

vec3 tonemapReinhardJodie(vec3 c) {
    float l = luminance(c);
    vec3 tc = c / (c + 1.0);
    return saturate(mix(c / (l + 1.0), tc, tc));
}

vec3 u2Partial(vec3 x) {
    const float A=0.15,B=0.50,C=0.10,D=0.20,E=0.02,F=0.30;
    return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}
vec3 tonemapUncharted2(vec3 c) {
    return saturate(u2Partial(c * 2.0) / u2Partial(vec3(11.2)));
}

vec3 applyTonemap(vec3 c) {
#if TONEMAP_OPERATOR == 0
    c = tonemapAgX(c);
#elif TONEMAP_OPERATOR == 1
    c = tonemapACES(c);
    c = linearToSrgb(c);
#elif TONEMAP_OPERATOR == 2
    c = tonemapReinhardJodie(c);
    c = linearToSrgb(c);
#else
    c = tonemapUncharted2(c);
    c = linearToSrgb(c);
#endif
    return c;
}


vec3 colorGrade(vec3 c) {
    
    vec3 warm = vec3(1.06, 1.0, 0.92), cool = vec3(0.92, 0.99, 1.06);
    c *= mix(vec3(1.0), WHITE_BALANCE > 0.0 ? warm : cool, abs(WHITE_BALANCE));
    
    float l = luminance(c);
    float sat = length(c - l);
    c = mix(vec3(l), c, mix(1.0, VIBRANCE, saturate(1.0 - sat * 2.0)));
    
    c = mix(vec3(luminance(c)), c, SATURATION);
    
    c = (c - 0.5) * CONTRAST + 0.5;
    return saturate(c);
}


vec3 fxaaLite(sampler2D tex, vec2 uv, vec2 px, vec3 center) {
    float lC = luminance(center);
    vec3 n = texture(tex, uv + vec2(0.0, -px.y)).rgb;
    vec3 s = texture(tex, uv + vec2(0.0,  px.y)).rgb;
    vec3 e = texture(tex, uv + vec2( px.x, 0.0)).rgb;
    vec3 w = texture(tex, uv + vec2(-px.x, 0.0)).rgb;
    float lN = luminance(n), lS = luminance(s), lE = luminance(e), lW = luminance(w);
    float lMin = min(lC, min(min(lN, lS), min(lE, lW)));
    float lMax = max(lC, max(max(lN, lS), max(lE, lW)));
    float range = lMax - lMin;
    if (range < max(0.05, lMax * 0.12)) return center;
    vec2 dir = normalize(vec2(-((lN + lS) - 2.0 * lC), ((lE + lW) - 2.0 * lC)) + 1e-6);
    vec3 blur = (texture(tex, uv + dir * px * 0.75).rgb +
                 texture(tex, uv - dir * px * 0.75).rgb) * 0.5;
    return mix(center, blur, saturate(range * 3.0));
}


vec3 sharpen(vec3 center, vec3 n, vec3 s, vec3 e, vec3 w, float amount) {
    vec3 blur = (n + s + e + w) * 0.25;
    return center + (center - blur) * amount;
}

#endif
