/* Refrax — lib/biome.glsl */

#ifndef REFRAX_BIOME
#define REFRAX_BIOME

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

#ifdef BIOME_ATMOSPHERE
  #if !defined WORLD_NETHER && !defined WORLD_END
    #define BIOME_ATMOS_ACTIVE
  #endif
#endif

const float BIOME_TEMP_NEUTRAL = 0.80;
const float BIOME_HUMID_NEUTRAL = 0.40;

struct BiomeAtmos {
    float haze;
    float density;
    vec3 tint;
};

BiomeAtmos biomeNeutral() {
    BiomeAtmos b;
    b.haze = 1.0;
    b.density = 1.0;
    b.tint = vec3(1.0);
    return b;
}

void biomeBlend(inout BiomeAtmos b, float w, float haze, float density, vec3 tint) {
    if (w <= 0.001) return;
    b.haze = mix(b.haze, haze, w);
    b.density = mix(b.density, density, w);
    b.tint = mix(b.tint, tint, w);
}

BiomeAtmos biomeAtmos(float tempOffset, float humidOffset, float swamp, float alpine) {
#ifndef BIOME_ATMOS_ACTIVE
    return biomeNeutral();
#else
    float t = tempOffset + BIOME_TEMP_NEUTRAL;
    float h = humidOffset + BIOME_HUMID_NEUTRAL;
    float arid = smoothstep(1.00, 1.80, t) * smoothstep(0.40, 0.10, h);
    float lush = smoothstep(0.72, 0.90, h) * smoothstep(0.55, 0.90, t);
    float frigid = smoothstep(0.45, -0.10, t);
    float fungal = smoothstep(0.94, 0.995, h);

    BiomeAtmos b = biomeNeutral();
    biomeBlend(b, arid, 2.20, 0.72, vec3(1.12, 1.00, 0.80));
    biomeBlend(b, lush, 1.35, 1.55, vec3(0.94, 1.06, 0.92));
    biomeBlend(b, saturate(alpine), 0.70, 0.80, vec3(1.05, 0.98, 1.03));
    biomeBlend(b, frigid, 0.55, 0.92, vec3(0.90, 0.98, 1.18));
    biomeBlend(b, saturate(swamp), 1.50, 1.90, vec3(0.86, 1.00, 0.78));
    biomeBlend(b, fungal, 1.25, 1.35, vec3(1.08, 0.90, 1.12));

    b.haze = mix(1.0, b.haze, BIOME_ATMOS_STRENGTH);
    b.density = mix(1.0, b.density, BIOME_ATMOS_STRENGTH);
    b.tint = mix(vec3(1.0), b.tint, BIOME_ATMOS_STRENGTH);
    return b;
#endif
}

#endif
