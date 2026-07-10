/* Refrax — lib/blockid.glsl */
#ifndef REFRAX_BLOCKID
#define REFRAX_BLOCKID

#include "/lib/settings.glsl"
#include "/lib/noise.glsl"



vec3 blockLightColor(int id) {
    vec3 c = vec3(0.0);
    float s = 0.0;
    if      (id == 10001) { c = vec3(1.00, 0.55, 0.25); s = 12.0; } 
    else if (id == 10002) { c = vec3(1.00, 0.62, 0.30); s = 12.0; } 
    else if (id == 10003) { c = vec3(0.25, 0.65, 1.00); s = 10.0; } 
    else if (id == 10004) { c = vec3(1.00, 0.70, 0.35); s = 15.0; } 
    else if (id == 10005) { c = vec3(0.65, 0.90, 1.00); s = 14.0; } 
    else if (id == 10006) { c = vec3(1.00, 0.75, 0.50); s = 15.0; } 
    else if (id == 10007) { c = vec3(1.00, 0.45, 0.15); s = 13.0; } 
    else if (id == 10008) { c = vec3(1.00, 0.35, 0.08); s = 15.0; } 
    else if (id == 10009) { c = vec3(0.90, 0.80, 1.00); s = 14.0; } 
    else if (id == 10010) { c = vec3(0.70, 0.90, 1.00); s = 15.0; } 
    else if (id == 10011) { c = vec3(1.00, 0.85, 0.40); s = 15.0; } 
    else if (id == 10012) { c = vec3(0.50, 1.00, 0.50); s = 15.0; } 
    else if (id == 10013) { c = vec3(0.95, 0.70, 1.00); s = 15.0; } 
    else if (id == 10014) { c = vec3(0.70, 0.45, 1.00); s =  6.0; } 
    else if (id == 10015) { c = vec3(0.20, 0.70, 0.90); s =  4.0; } 
    else if (id == 10016) { c = vec3(0.55, 0.25, 1.00); s =  8.0; } 
    else if (id == 10017) { c = vec3(0.90, 0.75, 0.45); s =  6.0; } 
    else if (id == 10018) { c = vec3(0.55, 0.20, 1.00); s = 13.0; }
    else if (id == 10020) { c = vec3(1.00, 0.15, 0.05); s =  7.0; } 
    else if (id == 10021) { c = vec3(0.60, 0.40, 1.00); s =  5.0; } 
    else if (id == 10022) { c = vec3(1.00, 0.72, 0.45); s =  6.0; } 
    else if (id == 10023) { c = vec3(1.00, 0.62, 0.30); s = 15.0; } 
    else if (id == 10024) { c = vec3(0.38, 0.95, 0.78); s = 10.0; } 
    return c * (s / 15.0);
}

bool isEmitter(int id)   { return id >= 10001 && id <= 10029; }

float emitterEmission(int id, float z) {
    float z3 = z * z * z;
    if (id == 10004 || id == 10005 || id == 10006 || id == 10008
     || (id >= 10010 && id <= 10013) || id == 10023)
        return 0.10 + 0.90 * z3;
    if (id == 10007) return smoothstep(0.45, 0.85, z);
    if (id <= 10003 || id == 10009 || id == 10020 || id == 10024)
        return z3 * smoothstep(0.35, 0.75, z);
    return 0.4 * z3 * z;
}

float heldLightValue(int id, int lv) {
    if (lv > 0) return float(lv);
    return id == 10008 ? 15.0 : 0.0;
}
vec3 heldLightColor(int id) {
    vec3 c = (id >= 10001 && id <= 10029) ? blockLightColor(id) : vec3(0.0);
    return dot(c, c) > 0.0 ? c : FALLBACK_BLOCKLIGHT;
}

bool isNoOcclude(int id) { return id >= 10050; }
bool isFoliage(int id)   { return id >= 10050 && id <= 10059; }
bool isWavingShort(int id) { return id == 10050; }
bool isWavingLeaf(int id)  { return id == 10051; }
bool isWavingTall(int id)  { return id == 10052; }


vec3 wavingOffset(int id, vec3 worldPos, vec3 midBlock, float time, float rain) {
#ifndef WAVING_PLANTS
    return vec3(0.0);
#else
    float strength = (0.5 + rain) * WAVE_AMOUNT;
    float t = time * 1.2 * WAVE_SPEED;
    float phase = dot(worldPos.xz, vec2(0.42, 0.31));
    float gust = vnoise3(vec3(worldPos.xz * 0.06, t * 0.25)) - 0.5;
    vec2 sway = vec2(sin(phase + t) + gust * 2.0, cos(phase * 1.3 + t * 0.8) + gust);
    if (isWavingShort(id) || isWavingTall(id)) {
        float w = saturate(0.5 - midBlock.y / 40.0); 
        if (isWavingTall(id)) w = saturate(w * 1.4);
        return vec3(sway.x, 0.0, sway.y) * 0.035 * w * strength;
    }
    if (isWavingLeaf(id)) {
        vec3 wob = vec3(sway.x, sin(phase * 0.7 + t * 0.6) * 0.5, sway.y);
        return wob * 0.018 * strength;
    }
    return vec3(0.0);
#endif
}

#endif
