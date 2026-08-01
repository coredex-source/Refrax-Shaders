/* Refrax — lib/blockid.glsl */
#ifndef REFRAX_BLOCKID
#define REFRAX_BLOCKID

#include "/lib/settings.glsl"
#include "/lib/noise.glsl"



void emitterProfile(int id, out vec3 c, out float s) {
    c = vec3(0.0);
    s = 0.0;
    if (id == 10001) { c = vec3(1.00, 0.55, 0.25); s = 12.0; }
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
    else if (id == 10014) { c = vec3(0.70, 0.45, 1.00); s = 6.0; }
    else if (id == 10015) { c = vec3(0.20, 0.70, 0.90); s = 4.0; }
    else if (id == 10016) { c = vec3(0.55, 0.25, 1.00); s = 8.0; }
    else if (id == 10017) { c = vec3(0.90, 0.75, 0.45); s = 6.0; }
    else if (id == 10018) { c = vec3(0.55, 0.20, 1.00); s = 13.0; }
    else if (id == 10020) { c = vec3(1.00, 0.15, 0.05); s = 7.0; }
    else if (id == 10021) { c = vec3(0.60, 0.40, 1.00); s = 5.0; }
    else if (id == 10022) { c = vec3(1.00, 0.72, 0.45); s = 6.0; }
    else if (id == 10023) { c = vec3(1.00, 0.62, 0.30); s = 15.0; }
    else if (id == 10024) { c = vec3(0.38, 0.95, 0.78); s = 10.0; }
    else if (id == 10025) { c = vec3(0.35, 0.85, 0.95); s = 15.0; }
    else if (id == 10026) { c = vec3(0.45, 0.85, 0.45); s = 6.0; }
    else if (id == 10027) { c = vec3(1.00, 0.96, 0.90); s = 15.0; }
}

vec3 blockLightColor(int id) {
    vec3 c; float s;
    emitterProfile(id, c, s);
    return c * (s / 15.0);
}

bool isEmitter(int id) { return id >= 10001 && id <= 10029; }

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

float entityEmissionStrength(int id) {
    if (id < 10101 || id > 10118) return 0.0;
    if (id == 10101) return 1.00;
    if (id == 10102) return 0.85;
    if (id == 10103) return 0.80;
    if (id == 10104) return 0.60;
    if (id == 10105) return 0.55;
    if (id == 10106) return 1.00;
    if (id == 10107) return 0.70;
    if (id == 10108) return 0.55;
    if (id == 10109) return 0.65;
    if (id == 10110) return 0.50;
    if (id == 10111) return 0.45;
    if (id == 10112) return 0.90;
    if (id == 10113) return 0.75;
    if (id == 10114) return 0.85;
    if (id == 10115) return 0.80;
    if (id == 10116) return 1.00;
    if (id == 10117) return 0.60;
    return 0.70;
}

float heldLightIntrinsic(int id) {
    if (id == 10008) return 15.0;
    vec3 c; float s;
    emitterProfile(id, c, s);
    return s;
}

float heldLightValue(int id, int lv) {
    return max(float(max(lv, 0)), heldLightIntrinsic(id));
}
vec3 heldLightColor(int id) {
    vec3 c = (id >= 10001 && id <= 10029) ? blockLightColor(id) : vec3(0.0);
    return dot(c, c) > 0.0 ? c : FALLBACK_BLOCKLIGHT;
}

vec3 heldLightAt(vec3 pos, int id1, int lv1, int id2, int lv2) {
#ifndef HAND_LIGHT
    return vec3(0.0);
#else
    float l1 = heldLightValue(id1, lv1);
    float l2 = heldLightValue(id2, lv2);
    float level = max(l1, l2);
    if (level <= 0.0) return vec3(0.0);

    bool e1 = id1 >= 10001 && id1 <= 10029;
    bool e2 = id2 >= 10001 && id2 <= 10029;
    vec3 col;
    if (e1 && e2) col = l1 >= l2 ? heldLightColor(id1) : heldLightColor(id2);
    else if (e1) col = heldLightColor(id1);
    else if (e2) col = heldLightColor(id2);
    else col = FALLBACK_BLOCKLIGHT;

    float falloff = pow(saturate(1.0 - length(pos) / level), 2.0);
    return col * (falloff * level * (0.12 * HAND_LIGHT_STRENGTH));
#endif
}

bool isTintedGlass(int id) { return id >= 10070 && id <= 10085; }

vec3 glassTint(int id) {
    if (id == 10070) return vec3(0.95, 0.95, 0.95);
    if (id == 10071) return vec3(1.00, 0.55, 0.18);
    if (id == 10072) return vec3(0.90, 0.32, 0.85);
    if (id == 10073) return vec3(0.42, 0.72, 1.00);
    if (id == 10074) return vec3(1.00, 0.92, 0.25);
    if (id == 10075) return vec3(0.55, 0.95, 0.30);
    if (id == 10076) return vec3(1.00, 0.62, 0.75);
    if (id == 10077) return vec3(0.35, 0.35, 0.35);
    if (id == 10078) return vec3(0.70, 0.70, 0.70);
    if (id == 10079) return vec3(0.25, 0.75, 0.80);
    if (id == 10080) return vec3(0.60, 0.28, 0.90);
    if (id == 10081) return vec3(0.25, 0.35, 0.95);
    if (id == 10082) return vec3(0.55, 0.36, 0.22);
    if (id == 10083) return vec3(0.36, 0.75, 0.28);
    if (id == 10084) return vec3(0.95, 0.22, 0.20);
    return vec3(0.16, 0.16, 0.16);
}

bool isNoOcclude(int id) { return id >= 10050; }
bool isFoliage(int id) { return id >= 10050 && id <= 10059; }
bool isWavingShort(int id) { return id == 10050; }
bool isWavingLeaf(int id) { return id == 10051; }
bool isWavingTallLower(int id) { return id == 10052; }
bool isWavingTallUpper(int id) { return id == 10053; }
bool isWavingColumn(int id) { return id == 10054; }


vec3 wavingOffset(int id, vec3 worldPos, vec3 midBlock, float time, float rain) {
#ifndef WAVING_PLANTS
    return vec3(0.0);
#else
    float storm = smoothstep(0.08, 0.90, saturate(rain));
    float strength = mix(0.62, 2.565, storm) * WAVE_AMOUNT;
    float tCalm = time * (0.90 * WAVE_SPEED);
    float tStorm = time * (1.35 * WAVE_SPEED);
    float phase = dot(worldPos.xz, vec2(0.34, 0.23));

    vec2 windDir = CLOUD_WIND;
    windDir /= max(length(windDir), 1e-4);
    vec2 crossWind = vec2(-windDir.y, windDir.x);

    float gustNoise = vnoise3(vec3(worldPos.xz * 0.035, tStorm * 0.16)) - 0.5;
    float gustWave = sin(phase * 0.55 + tStorm * 0.72 + gustNoise * 1.8);
    vec2 calmSway = vec2(sin(phase + tCalm), cos(phase * 1.27 + tCalm * 0.78));
    vec2 stormSway = windDir * (gustWave * 1.25 + gustNoise * 1.6) + crossWind * sin(phase * 0.83 - tStorm * 0.46) * 0.28;
    vec2 sway = mix(calmSway, stormSway, storm);
    if (isWavingShort(id)) {
        float w = saturate(0.5 - midBlock.y / 40.0);
        return vec3(sway.x, 0.0, sway.y) * 0.035 * w * strength;
    }
    if (isWavingTallLower(id) || isWavingTallUpper(id)) {
        float hb = saturate(0.5 - midBlock.y / 64.0);
        float h = isWavingTallUpper(id) ? 0.5 + hb * 0.5 : hb * 0.5;
        float w = saturate(h * h * 1.4);
        return vec3(sway.x, 0.0, sway.y) * 0.035 * w * strength;
    }
    if (isWavingColumn(id)) {
        return vec3(sway.x, 0.0, sway.y) * 0.035 * 0.75 * strength;
    }
    if (isWavingLeaf(id)) {
        float vertical = mix(sin(phase * 0.7 + tCalm * 0.55), sin(phase * 0.7 + tStorm * 0.55), storm)
                       * mix(0.50, 0.20, storm);
        vec3 wob = vec3(sway.x, vertical, sway.y);
        return wob * 0.018 * strength;
    }
    return vec3(0.0);
#endif
}

#endif
