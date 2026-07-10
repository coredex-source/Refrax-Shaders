/* Refrax — lib/endportal.glsl */
#ifndef REFRAX_ENDPORTAL
#define REFRAX_ENDPORTAL

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/noise.glsl"

#if END_PORTAL_STYLE == 0
#define EP_BASE vec3(0.004, 0.010, 0.009)
#define EP_NEB vec3(0.008, 0.026, 0.020)
#define EP_DENSITY 0.72
#define EP_GAIN 0.80
const vec3 EP_PALETTE[8] = vec3[8](
    vec3(0.30, 0.80, 0.55), vec3(0.25, 0.70, 0.50),
    vec3(0.40, 0.90, 0.65), vec3(0.20, 0.60, 0.45),
    vec3(0.35, 0.85, 0.70), vec3(0.28, 0.75, 0.48),
    vec3(0.45, 0.95, 0.75), vec3(0.22, 0.65, 0.55));
#elif END_PORTAL_STYLE == 2
#define EP_BASE vec3(0.004, 0.006, 0.016)
#define EP_NEB vec3(0.009, 0.015, 0.040)
#define EP_DENSITY 0.72
#define EP_GAIN 0.90
const vec3 EP_PALETTE[8] = vec3[8](
    vec3(0.55, 0.70, 1.00), vec3(0.75, 0.85, 1.00),
    vec3(0.40, 0.55, 0.95), vec3(0.90, 0.95, 1.00),
    vec3(0.50, 0.65, 1.00), vec3(0.65, 0.80, 1.00),
    vec3(0.35, 0.50, 0.90), vec3(0.80, 0.90, 1.00));
#elif END_PORTAL_STYLE == 3
#define EP_BASE vec3(0.012, 0.005, 0.022)
#define EP_NEB vec3(0.036, 0.010, 0.055)
#define EP_DENSITY 0.72
#define EP_GAIN 1.00
const vec3 EP_PALETTE[8] = vec3[8](
    vec3(0.60, 0.35, 0.95), vec3(0.75, 0.40, 0.90),
    vec3(0.50, 0.30, 0.90), vec3(0.85, 0.45, 0.85),
    vec3(0.65, 0.30, 1.00), vec3(0.90, 0.50, 0.95),
    vec3(0.55, 0.25, 0.85), vec3(0.80, 0.35, 0.80));
#elif END_PORTAL_STYLE == 4
#define EP_BASE vec3(0.003, 0.003, 0.006)
#define EP_NEB vec3(0.007, 0.008, 0.014)
#define EP_DENSITY 0.86
#define EP_GAIN 0.55
const vec3 EP_PALETTE[8] = vec3[8](
    vec3(0.55, 0.60, 0.70), vec3(0.65, 0.70, 0.80),
    vec3(0.45, 0.50, 0.65), vec3(0.70, 0.75, 0.85),
    vec3(0.50, 0.55, 0.70), vec3(0.60, 0.65, 0.78),
    vec3(0.40, 0.45, 0.60), vec3(0.68, 0.72, 0.82));
#else
#define EP_BASE vec3(0.010, 0.006, 0.028)
#define EP_NEB vec3(0.030, 0.012, 0.060)
#define EP_DENSITY 0.72
#define EP_GAIN 1.00
const vec3 EP_PALETTE[8] = vec3[8](
    vec3(0.30, 0.75, 0.65), vec3(0.35, 0.60, 0.90),
    vec3(0.25, 0.80, 0.85), vec3(0.30, 0.45, 1.00),
    vec3(0.55, 0.50, 0.90), vec3(0.45, 0.30, 0.95),
    vec3(0.70, 0.35, 0.90), vec3(0.85, 0.30, 0.75));
#endif

vec3 endPortalColor(vec3 scenePos, vec3 camPos, vec3 N, float time) {
    
    vec3 ref = abs(N.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
    vec3 T = normalize(cross(ref, N));
    vec3 B = cross(N, T);

    vec3 worldPos = scenePos + camPos;
    vec2 base = vec2(dot(worldPos, T), dot(worldPos, B));

    vec3 dir = normalize(scenePos);                 
    float vn = max(abs(dot(dir, N)), 0.2);
    vec2 par = vec2(dot(dir, T), dot(dir, B)) / vn; 

    vec3 color = EP_BASE;


    float neb = fbm3(vec3(base * 0.45 + par * 4.0, 0.0), 3);
    color += smoothstep(0.45, 0.85, neb) * EP_NEB;



    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float depth = 0.6 + fi * 0.7;
        float ang = fi * 0.7;
        vec2 ca = vec2(cos(ang), sin(ang));
        vec2 q = mat2(ca.x, ca.y, -ca.y, ca.x) * (base + par * depth);
        q = q * (2.6 + fi * 1.5) + fi * 17.31;
        vec2 cell = floor(q);
        float h = hash12(cell);
        if (h > EP_DENSITY) {
            vec2 off = vec2(hash12(cell + 31.7), hash12(cell + 57.3)) - 0.5;
            vec2 d2 = fract(q) - 0.5 - off * 0.6;
            float star = exp(-dot(d2, d2) * 60.0);
            float tw = 0.95 + 0.05 * sin(time * 0.25 + h * 50.0);
            vec3 tint = EP_PALETTE[int(h * 1024.0) & 7];
            color += star * tw * tint * (0.40 - 0.05 * fi) * EP_GAIN;
        }
    }
    return saturate(color);
}

#endif
