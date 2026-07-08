/* Refrax — lib/noise.glsl */
#ifndef REFRAX_NOISE
#define REFRAX_NOISE

uint pcgHash(uint v) {
    v = v * 747796405u + 2891336453u;
    uint w = ((v >> ((v >> 28u) + 4u)) ^ v) * 277803737u;
    return (w >> 22u) ^ w;
}
float hashU(uint v) { return float(pcgHash(v)) * (1.0 / 4294967295.0); }
float hash13(vec3 p) {
    uvec3 q = uvec3(ivec3(floor(p)) + 32768);
    return hashU(q.x * 1597334673u ^ q.y * 3812015801u ^ q.z * 2798796415u);
}
float hash12(vec2 p) { return hash13(vec3(p, 17.0)); }

float vnoise3(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float n000 = hash13(i), n100 = hash13(i + vec3(1,0,0));
    float n010 = hash13(i + vec3(0,1,0)), n110 = hash13(i + vec3(1,1,0));
    float n001 = hash13(i + vec3(0,0,1)), n101 = hash13(i + vec3(1,0,1));
    float n011 = hash13(i + vec3(0,1,1)), n111 = hash13(i + vec3(1,1,1));
    return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
               mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float fbm3(vec3 p, int octaves) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < octaves; i++) {
        v += a * vnoise3(p);
        p = p * 2.13 + vec3(11.7, 5.3, 7.1);
        a *= 0.5;
    }
    return v;
}

#endif
