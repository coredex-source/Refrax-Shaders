/* Refrax — lib/endportal.glsl */
#ifndef REFRAX_ENDPORTAL
#define REFRAX_ENDPORTAL

#include "/lib/common.glsl"
#include "/lib/noise.glsl"

vec3 endPortalColor(vec3 scenePos, vec3 camPos, vec3 N, float time) {
    
    vec3 ref = abs(N.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
    vec3 T = normalize(cross(ref, N));
    vec3 B = cross(N, T);

    vec3 worldPos = scenePos + camPos;
    vec2 base = vec2(dot(worldPos, T), dot(worldPos, B));

    vec3 dir = normalize(scenePos);                 
    float vn = max(abs(dot(dir, N)), 0.2);
    vec2 par = vec2(dot(dir, T), dot(dir, B)) / vn; 

    vec3 color = vec3(0.010, 0.006, 0.028);         

    
    float neb = fbm3(vec3(base * 0.45 + par * 4.0, 0.0), 3);
    color += smoothstep(0.45, 0.85, neb) * vec3(0.030, 0.012, 0.060);

    
    const vec3 palette[8] = vec3[8](
        vec3(0.30, 0.75, 0.65), vec3(0.35, 0.60, 0.90),
        vec3(0.25, 0.80, 0.85), vec3(0.30, 0.45, 1.00),
        vec3(0.55, 0.50, 0.90), vec3(0.45, 0.30, 0.95),
        vec3(0.70, 0.35, 0.90), vec3(0.85, 0.30, 0.75));

    
    
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float depth = 0.6 + fi * 0.7;
        float ang = fi * 0.7;
        vec2 ca = vec2(cos(ang), sin(ang));
        vec2 q = mat2(ca.x, ca.y, -ca.y, ca.x) * (base + par * depth);
        q = q * (2.6 + fi * 1.5) + fi * 17.31;
        vec2 cell = floor(q);
        float h = hash12(cell);
        if (h > 0.72) {                             
            vec2 off = vec2(hash12(cell + 31.7), hash12(cell + 57.3)) - 0.5;
            vec2 d2 = fract(q) - 0.5 - off * 0.6;
            float star = exp(-dot(d2, d2) * 60.0);
            float tw = 0.95 + 0.05 * sin(time * 0.25 + h * 50.0);
            vec3 tint = palette[int(h * 1024.0) & 7];
            color += star * tw * tint * (0.40 - 0.05 * fi);
        }
    }
    return saturate(color);
}

#endif
