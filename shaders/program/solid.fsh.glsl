/* Refrax — program/solid.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/blockid.glsl"
#include "/lib/labpbr.glsl"
#ifdef BLOCK_ENTITY
#include "/lib/endportal.glsl"
#endif

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform float alphaTestRef;
#ifdef ENTITY
uniform vec4 entityColor;
uniform int entityId;
#endif
#ifdef BLOCK_ENTITY
uniform int blockEntityId;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
#endif

in vec2 uv;
in vec2 lmcoord;
in vec4 vcolor;
in vec3 normalW;
in vec3 tangentW;
in float tangentSign;
in vec3 scenePos;
flat in int blockId;
in vec2 tileBase;
in vec2 tileSize;

/* RENDERTARGETS: 1,2,3 */
layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outMaterial;

void main() {
    vec2 texcoord = uv;
    vec3 N = normalize(normalW);

#ifdef BLOCK_ENTITY
    if (blockEntityId == 10030) {
#if MC_VERSION < 12100
        N = normalize(cross(dFdx(scenePos), dFdy(scenePos)));
        if (dot(N, scenePos) > 0.0) N = -N;
#endif
        vec3 portal = endPortalColor(scenePos, cameraPosition, N, frameTimeCounter);
        outAlbedo = vec4(linearToSrgb(portal), 1.0);
        outNormal = vec4(N, 0.55);
        outMaterial = vec4(lmcoord, 1.0, 0.0);
        return;
    }
#endif

    float alphaRef = alphaTestRef;
#if defined ENTITY || defined HAND || defined EMISSIVE_FULL || defined BLOCK_ENTITY
    alphaRef = max(alphaRef, 0.5);
#endif
    float baseAlpha = texture(gtexture, uv).a * vcolor.a;
    bool terrainFoliage = false;
    bool alphaCutoutTile = false;
#ifdef TERRAIN
    float a00 = texture(gtexture, tileBase + tileSize * vec2(0.125, 0.125)).a;
    float a10 = texture(gtexture, tileBase + tileSize * vec2(0.500, 0.125)).a;
    float a20 = texture(gtexture, tileBase + tileSize * vec2(0.875, 0.125)).a;
    float a01 = texture(gtexture, tileBase + tileSize * vec2(0.125, 0.500)).a;
    float a11 = texture(gtexture, tileBase + tileSize * vec2(0.500, 0.500)).a;
    float a21 = texture(gtexture, tileBase + tileSize * vec2(0.875, 0.500)).a;
    float a02 = texture(gtexture, tileBase + tileSize * vec2(0.125, 0.875)).a;
    float a12 = texture(gtexture, tileBase + tileSize * vec2(0.500, 0.875)).a;
    float a22 = texture(gtexture, tileBase + tileSize * vec2(0.875, 0.875)).a;
    float tileMinAlpha = min(min(min(a00, a10), min(a20, a01)), min(min(a11, a21), min(a02, min(a12, a22)))) * vcolor.a;
    float tileMaxAlpha = max(max(max(a00, a10), max(a20, a01)), max(max(a11, a21), max(a02, max(a12, a22)))) * vcolor.a;
    alphaCutoutTile = tileMinAlpha < 0.05 && tileMaxAlpha > 0.95;
    terrainFoliage = isFoliage(blockId) || alphaCutoutTile;
    if (alphaCutoutTile) alphaRef = max(alphaRef, 0.5);
#endif
    if (baseAlpha < alphaRef) discard;

    float texAO = 1.0;
    float pomShadow = 1.0;
    Material mat;
    mat.roughness = 0.9; mat.f0 = 0.04; mat.emission = 0.0; mat.sss = 0.0;

#ifdef PBR_MATERIALS
  #ifdef TERRAIN
    bool foliage = terrainFoliage;
  #else
    const bool foliage = false;
  #endif
    if (!foliage && dot(tangentW, tangentW) > 1e-6) {
        vec3 T = normalize(tangentW);
        vec3 B = cross(N, T) * tangentSign;
        mat3 TBN = mat3(T, B, N);
      #ifdef POM
        vec3 viewDirT = normalize(transpose(TBN) * -normalize(scenePos));
        float pomHeight;
        texcoord = pomOffset(normals, texcoord, tileBase, tileSize, viewDirT, dFdx(uv), dFdy(uv), pomHeight);
        texcoord = wrapTile(texcoord, tileBase, tileSize);
        float pomFade = smoothstep(64.0, 96.0, length(scenePos));
        pomShadow = pomDirectShadow(pomHeight, pomFade);
      #endif
        vec4 nTex = texture(normals, texcoord);
        if (nTex.r + nTex.g > 0.0005) {
            N = normalize(TBN * decodeNormalTex(nTex));
            texAO = decodeTexAO(nTex);
        }
    }
    if (!foliage) mat = decodeSpecular(texture(specular, texcoord));
#endif

    vec4 albedo = texture(gtexture, texcoord) * vcolor;
#ifdef ENTITY
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
#endif
    if (albedo.a < alphaRef) discard;
    albedo.rgb *= texAO;

    float emission = mat.emission;
#ifdef EMISSIVE_FULL
    emission = 1.0;
#endif
#ifdef ENTITY
    if (entityId >= 10101 && entityId <= 10119) {
        float glow = smoothstep(0.18, 0.75, luminance(albedo.rgb));
        emission = max(emission, glow * (entityId == 10101 ? 1.0 : 0.75));
    }
#endif
#ifdef TERRAIN
    if (terrainFoliage) {
        mat.roughness = 1.0;
        mat.f0 = MATTE_FOLIAGE_F0;
    }
    if (emission <= 0.0 && isEmitter(blockId))
        emission = emitterEmission(blockId, luminance(albedo.rgb));
    if (mat.roughness > 0.85) {
        if (blockId == 10040) { mat.roughness = 0.28; mat.f0 = 0.045; }
        else if (blockId == 10041) { mat.roughness = 0.12; mat.f0 = 0.055; }
        else if (blockId == 10042) { mat.roughness = 0.22; mat.f0 = 1.0;   }
        else if (blockId == 10043) { mat.roughness = 0.15; mat.f0 = 0.060; }
    }
#endif

#ifdef DEBUG_PBR
#ifdef PBR_MATERIALS
    vec4 dbgN = texture(normals, texcoord);
    vec4 dbgS = texture(specular, texcoord);
    outAlbedo = vec4(fract(scenePos.x / 8.0) < 0.5 ? dbgN.rgb : dbgS.rgb, 1.0);
    outNormal = vec4(normalize(normalW), 1.0);
    outMaterial = vec4(lmcoord, 1.0, 0.0);
    return;
#endif
#endif

    outAlbedo = vec4(albedo.rgb, pomShadow);
    outNormal = vec4(N, emission);
    outMaterial = vec4(lmcoord, mat.roughness, mat.f0);
}
