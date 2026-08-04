/* Refrax — lib/water.glsl */
#ifndef REFRAX_WATER
#define REFRAX_WATER

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

float waterDetailField(sampler2D noiseTex, vec2 p, float t) {
    const mat2 turn = mat2(0.8192, 0.5736, -0.5736, 0.8192);
    vec2 wind = vec2(0.91, 0.42);
    vec2 detailUV = (turn * p) * vec2(0.021, 0.018) + vec2(-wind.y, wind.x) * (t * 0.0085);
    float detail = texture(noiseTex, detailUV).r;
    return detail * detail * (3.0 - 2.0 * detail);
}

const vec2 WAVE_HEADING = vec2(0.9231, 0.3846);
const float WAVE_STACK_SHEAR = 1.45;
const float WAVE_SLOPE_EPSILON = 0.1;
const float WAVE_SLOPE_GAIN = 1.63;
const float WAVE_SLOPE_LIMIT = 0.62;
const float WAVE_CREST_ONSET = 0.26;

vec3 refractSafe(vec3 incident, vec3 N, float eta) {
    float NoI = dot(N, incident);
    float k = 1.0 - eta * eta * (1.0 - NoI * NoI);
    if (k < 0.0) return vec3(0.0);
    return eta * incident - (eta * NoI + sqrt(k)) * N;
}

vec2 waterSwellWarp(vec2 p) {
    vec2 q = p - WAVE_HEADING * (dot(p, WAVE_HEADING) * 0.45);
    q.x -= cos(q.y * 0.68) * 0.35;
    q.y += sin(q.x * 0.47) * 0.26;
    return q;
}

float waterSwellField(sampler2D waterTex, vec2 p, float t, float detailFade) {
    const mat2 twist = mat2(0.9004, 0.4350, -0.4350, 0.9004);
    vec2 q = waterSwellWarp(p);
    vec2 flowUV = WAVE_HEADING * t;

    float swell = texture(waterTex, q * 0.0185 - flowUV * 0.0165).r;
    float crossSwell = texture(waterTex, (twist * q) * 0.0235 + flowUV.yx * 0.0125).r;
    float chop = texture(waterTex, (twist * q) * 0.094 + flowUV * 0.0295).r;
    return (swell + crossSwell) * 0.200 + chop * (0.018 + 0.026 * detailFade);
}

vec2 waterSwellGradient(sampler2D waterTex, vec2 q, float t, float detailFade, out float peak) {
    vec2 stepX = vec2(WAVE_SLOPE_EPSILON, 0.0);
    vec2 stepZ = vec2(0.0, WAVE_SLOPE_EPSILON);
    float negX = waterSwellField(waterTex, q - stepX, t, detailFade);
    float posX = waterSwellField(waterTex, q + stepX, t, detailFade);
    float negZ = waterSwellField(waterTex, q - stepZ, t, detailFade);
    float posZ = waterSwellField(waterTex, q + stepZ, t, detailFade);

    peak = max(max(negX, posX), max(negZ, posZ));
    return vec2(posX - negX, posZ - negZ) / (2.0 * WAVE_SLOPE_EPSILON);
}

vec3 waterSlopeToNormal(vec2 slope) {
    vec2 tilt = clamp(slope, vec2(-WAVE_SLOPE_LIMIT), vec2(WAVE_SLOPE_LIMIT));
    return normalize(vec3(tilt.x, 1.0, tilt.y));
}

vec3 waterReflectNormal(vec3 N) {
    return normalize(mix(N, vec3(0.0, 1.0, 0.0), WATER_REFLECT_FLATTEN));
}

vec3 waterReflectionDirection(vec3 V, vec3 N) {
    return reflect(-normalize(V), waterReflectNormal(N));
}

vec3 waterSurfaceNormalFlow(sampler2D waterTex, vec3 worldPos, vec2 drift, float t, float viewDot, float sky, float rain, float flow, float footprint, out float roughness, out float crest) {
#ifndef WATER_WAVES
    roughness = WATER_ROUGHNESS;
    crest = 0.0;
    return vec3(0.0, 1.0, 0.0);
#else
    float wt = t * WAVE_SPEED;
    vec2 q = worldPos.xz - WAVE_HEADING * (worldPos.y * WAVE_STACK_SHEAR) - drift;
    float detailFade = 1.0 - smoothstep(0.35, 1.10, footprint);

    float peak;
    vec2 slope = waterSwellGradient(waterTex, q, wt, detailFade, peak);
    slope *= WAVE_SLOPE_GAIN * WATER_WAVE_INTENSITY * viewDot;

    roughness = WATER_ROUGHNESS + smoothstep(0.30, 1.40, footprint) * 0.010;
    crest = saturate((peak - WAVE_CREST_ONSET) * 5.0);
    return waterSlopeToNormal(slope);
#endif
}

vec3 waterNormalFlow(sampler2D waterTex, vec3 worldPos, vec2 drift, float t, float viewDot, float sky, float rain, float viewDistance, float flow) {
    float roughness;
    float crest;
    float footprint = clamp(viewDistance * 0.0025, 0.015, 2.0);
    return waterSurfaceNormalFlow(waterTex, worldPos, drift, t, viewDot, sky, rain, flow, footprint, roughness, crest);
}

vec3 waterNormal(sampler2D waterTex, vec3 worldPos, float t, float viewDot, float sky, float rain, float viewDistance) {
    return waterNormalFlow(waterTex, worldPos, vec2(0.0), t, viewDot, sky, rain, viewDistance, 0.0);
}

vec3 waterfallSurfaceNormal(sampler2D waterTex, vec3 worldPos, vec3 geomN, float t, float sky, float rain, float flow, float footprint, out float roughness, out float crest) {
#ifndef WATER_WAVES
    roughness = WATER_ROUGHNESS;
    crest = 0.0;
    return geomN;
#else
    vec3 tangent = cross(vec3(0.0, 1.0, 0.0), geomN);
    float tangentLength = length(tangent);
    if (tangentLength < 1e-3) {
        roughness = WATER_ROUGHNESS;
        crest = 0.0;
        return geomN;
    }
    tangent /= tangentLength;
    vec3 bitangent = cross(geomN, tangent);

    float wt = t * WAVE_SPEED;
    vec2 p = vec2(dot(worldPos, tangent), dot(worldPos, bitangent));
    p.y += wt * (1.6 * FLOW_SPEED);

    float detailFade = 1.0 - smoothstep(0.30, 0.90, footprint);

    float peak;
    vec2 slope = waterSwellGradient(waterTex, p, wt, detailFade, peak);
    slope *= WAVE_SLOPE_GAIN * WATER_WAVE_INTENSITY * mix(0.90, 1.0, sky) * (1.0 + rain * 0.18) * (1.0 + flow * 0.35);
    slope = clamp(slope, vec2(-WAVE_SLOPE_LIMIT), vec2(WAVE_SLOPE_LIMIT));

    roughness = WATER_ROUGHNESS + smoothstep(0.25, 1.20, footprint) * 0.012;
    crest = saturate((peak - WAVE_CREST_ONSET) * 5.0);
    return normalize(geomN + tangent * slope.x + bitangent * slope.y);
#endif
}

vec3 waterfallNormal(sampler2D waterTex, vec3 worldPos, vec3 geomN, float t, float sky, float rain, float viewDistance) {
    float roughness;
    float crest;
    float footprint = clamp(viewDistance * 0.0030, 0.020, 2.0);
    return waterfallSurfaceNormal(waterTex, worldPos, geomN, t, sky, rain, 1.0, footprint, roughness, crest);
}

float waterFoamMask(sampler2D noiseTex, vec2 p, float t, float depth, float crest, float slope, float rain, float flow) {
    const mat2 turn = mat2(0.7071, 0.7071, -0.7071, 0.7071);
    vec2 wind = normalize(vec2(0.91, 0.42));
    float foamA = texture(noiseTex, p * 0.115 + wind * (t * 0.014)).b;
    float foamB = texture(noiseTex, (turn * p) * 0.205 - vec2(-wind.y, wind.x) * (t * 0.021)).b;
    float pattern = mix(foamA, foamB, 0.42);
    float shore = 1.0 - smoothstep(0.0, FOAM_WIDTH, depth);
    float shoreBreak = smoothstep(0.38, 0.74, pattern + shore * 0.34);
    float foam = shore * shore * shoreBreak;
#ifdef WATER_WHITECAPS
    float whitecap = smoothstep(0.16, 0.38, slope) * smoothstep(0.58, 0.94, crest);
    whitecap *= smoothstep(0.38, 0.68, pattern + rain * 0.08) * (0.45 + rain * 0.55 + flow * 0.35);
    foam += whitecap * WHITECAP_STRENGTH;
#endif
    return saturate(foam * FOAM_STRENGTH);
}

float waterFresnel(float NoV) {
    float grazing = 1.0 - saturate(NoV);
    float grazing2 = grazing * grazing;
    return WATER_FRESNEL + (1.0 - WATER_FRESNEL) * grazing2 * grazing2;
}

float waterSunGlint(vec3 N, vec3 V, vec3 L) {
    vec3 reflected = reflect(-normalize(V), N);
    float discEdge = cos(WATER_GLINT_RADIUS);
    return smoothstep(discEdge, 1.0, dot(reflected, normalize(L)));
}

vec2 waterRefractOffset(vec3 viewPos, vec3 viewNormal, vec2 projScale) {
    float viewDist = length(viewPos);
    vec3 incident = viewPos / max(viewDist, 1e-4);
    vec3 facing = faceforward(viewNormal, incident, viewNormal);
    vec3 bent = refractSafe(incident, facing, 1.0 / WATER_IOR);
    if (dot(bent, bent) < 1e-6) return vec2(0.0);

    vec2 offset = (bent - incident).xy * projScale;
    offset *= WATER_REFRACT_REACH * REFRACTION_INTENSITY / max(viewDist, 1.0);
    return clamp(offset, vec2(-WATER_REFRACT_CLAMP), vec2(WATER_REFRACT_CLAMP));
}

vec3 waterReflectionColor(vec3 reflection) {
    vec3 bounded = 1.0 - exp(-max(reflection, vec3(0.0)) * 0.65);
    return mix(bounded, bounded * bounded, 0.35) * 0.78;
}

vec3 waterGlintColor(vec3 glint) {
    return glint * (0.75 / (1.0 + luminance(glint)));
}

float waterDepthOpacity(vec3 transmittance) {
    return saturate(1.0 - dot(transmittance, vec3(0.20, 0.65, 0.15)));
}

vec3 waterBodyColor(vec3 biomeTint, vec3 transmittance, vec3 lighting) {
    float depth = waterDepthOpacity(transmittance);
    vec3 shallow = mix(WATER_COLOR * WATER_COLOR, srgbToLinear(biomeTint) * 0.20, 0.20) * lighting * 0.32;
    vec3 deep = vec3(0.0015, 0.0060, 0.0180) * (0.75 + min(luminance(lighting), 1.5) * 0.20);
    return mix(shallow, deep, smoothstep(0.18, 0.78, depth));
}

float waterSurfaceAlpha(vec3 transmittance, float fresnel) {
    float depthOpacity = waterDepthOpacity(transmittance);
    float bodyAlpha = mix(WATER_OPACITY, 0.90, depthOpacity);
    return mix(bodyAlpha, 1.0, fresnel);
}

vec3 waterTransmittance(float dist) {
    return exp(-WATER_ABSORB * WATER_ABSORPTION * max(dist, 0.0));
}

vec3 waterTransmittanceTinted(vec3 biomeTint, float dist) {
    vec3 absorb = (vec3(1.05) - saturate(biomeTint)) * 1.5 * WATER_ABSORPTION;
    return exp(-absorb * max(dist, 0.0));
}

vec3 underwaterFogTint(vec3 fogCol, vec3 sunDir, float eyeSky, float rain) {
    vec3 fogLin = srgbToLinear(max(fogCol, vec3(0.0)));
    vec3 fogHue = fogLin / max(luminance(fogLin), 0.015);
    fogHue = clamp(fogHue * vec3(0.050, 0.095, 0.220), vec3(0.0), vec3(0.28, 0.46, 0.86));

    vec3 deepWater = vec3(0.006, 0.020, 0.055);
    vec3 clearWater = vec3(0.018, 0.060, 0.135);
    vec3 litWater = vec3(0.050, 0.130, 0.285);
    float daylight = saturate(sunDir.y * 0.55 + 0.45);
    vec3 tint = mix(deepWater, clearWater, saturate(eyeSky * 1.35));
    tint = mix(tint, litWater, eyeSky * (0.22 + 0.38 * daylight));
    tint = mix(tint, tint + fogHue, saturate(0.18 + eyeSky * 0.30));

    return max(tint * mix(0.48, 0.98, eyeSky) * (1.0 - rain * 0.18), vec3(0.002));
}

#endif
