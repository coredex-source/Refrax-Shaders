/* Refrax — lib/taau.glsl */
#ifndef REFRAX_TAAU
#define REFRAX_TAAU

vec3 rgbToYcocg(vec3 c) {
    return vec3( c.r * 0.25 + c.g * 0.5 + c.b * 0.25,
                 c.r * 0.5              - c.b * 0.5,
                -c.r * 0.25 + c.g * 0.5 - c.b * 0.25);
}
vec3 ycocgToRgb(vec3 c) {
    float n = c.x - c.z;
    return vec3(n + c.y, c.x + c.z, n - c.y);
}

vec4 catmullRomRegion(sampler2D tex, vec2 posPx, vec2 texel, vec2 regionMax, out float confidence) {
    vec2 center = floor(posPx - 0.5) + 0.5;
    vec2 f = posPx - center;

    vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
    vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
    vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
    vec2 w3 = f * f * (-0.5 + 0.5 * f);

    vec2 w12 = w1 + w2;
    vec2 off12 = w2 / w12;

    vec2 p0  = clamp(center - 1.0,   vec2(0.5), regionMax) * texel;
    vec2 p3  = clamp(center + 2.0,   vec2(0.5), regionMax) * texel;
    vec2 p12 = clamp(center + off12, vec2(0.5), regionMax) * texel;

    vec4 c = vec4(0.0);
    c += texture(tex, vec2(p0.x,  p0.y))  * (w0.x  * w0.y);
    c += texture(tex, vec2(p12.x, p0.y))  * (w12.x * w0.y);
    c += texture(tex, vec2(p3.x,  p0.y))  * (w3.x  * w0.y);
    c += texture(tex, vec2(p0.x,  p12.y)) * (w0.x  * w12.y);
    c += texture(tex, vec2(p12.x, p12.y)) * (w12.x * w12.y);
    c += texture(tex, vec2(p3.x,  p12.y)) * (w3.x  * w12.y);
    c += texture(tex, vec2(p0.x,  p3.y))  * (w0.x  * w3.y);
    c += texture(tex, vec2(p12.x, p3.y))  * (w12.x * w3.y);
    c += texture(tex, vec2(p3.x,  p3.y))  * (w3.x  * w3.y);

    confidence = max(max(w0.x, w1.x), max(w2.x, w3.x))
               * max(max(w0.y, w1.y), max(w2.y, w3.y));
    return c;
}

vec3 taauClipAabb(vec3 q, vec3 mn, vec3 mx, out bool clipped) {
    vec3 center = 0.5 * (mx + mn);
    vec3 extent = 0.5 * (mx - mn);
    vec3 v = q - center;
    vec3 a = abs(v / max(extent, vec3(1e-3)));
    float m = max(a.x, max(a.y, a.z));
    clipped = m > 1.0;
    return clipped ? center + v / m : q;
}

float taauFlickerReduction(vec3 hist, vec3 mn, vec3 mx) {
    float dist = length(min(hist - mn, mx - hist)) / max(0.5 * (mn.x + mx.x), 1e-3);
    return saturate(dist * 5.0);
}

#endif
