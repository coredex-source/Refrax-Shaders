/* Refrax — program/solid.vsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/blockid.glsl"

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float viewWidth, viewHeight;
uniform int frameCounter;

in vec4 mc_Entity;
in vec2 mc_midTexCoord;
in vec4 at_tangent;
in vec3 at_midBlock;

out vec2 uv;
out vec2 lmcoord;
out vec4 vcolor;
out vec3 normalW;
out vec3 tangentW;
out float tangentSign;
out vec3 scenePos;
flat out int blockId;
flat out vec2 tileBase;
flat out vec2 tileSize;

#ifdef TERRAIN
uniform sampler2D gtexture;
flat out vec2 tileAlphaRange;

vec2 tileAlphaMinMax(vec2 base, vec2 size) {
    float a00 = textureLod(gtexture, base + size * vec2(0.125, 0.125), 0.0).a;
    float a10 = textureLod(gtexture, base + size * vec2(0.500, 0.125), 0.0).a;
    float a20 = textureLod(gtexture, base + size * vec2(0.875, 0.125), 0.0).a;
    float a01 = textureLod(gtexture, base + size * vec2(0.125, 0.500), 0.0).a;
    float a11 = textureLod(gtexture, base + size * vec2(0.500, 0.500), 0.0).a;
    float a21 = textureLod(gtexture, base + size * vec2(0.875, 0.500), 0.0).a;
    float a02 = textureLod(gtexture, base + size * vec2(0.125, 0.875), 0.0).a;
    float a12 = textureLod(gtexture, base + size * vec2(0.500, 0.875), 0.0).a;
    float a22 = textureLod(gtexture, base + size * vec2(0.875, 0.875), 0.0).a;
    return vec2(min(min(min(a00, a10), min(a20, a01)), min(min(a11, a21), min(a02, min(a12, a22)))),
                max(max(max(a00, a10), max(a20, a01)), max(max(a11, a21), max(a02, max(a12, a22)))));
}
#endif

void main() {
    uv = vec2(gl_TextureMatrix[0] * gl_MultiTexCoord0);
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vcolor = gl_Color;
    blockId = int(mc_Entity.x + 0.5);

    normalW = normalize(mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal));
    tangentW = normalize(mat3(gbufferModelViewInverse) * (gl_NormalMatrix * at_tangent.xyz));
    tangentSign = at_tangent.w;

    vec2 half_ = abs(uv - mc_midTexCoord);
    tileSize = max(half_ * 2.0, vec2(1e-6));
    tileBase = mc_midTexCoord - half_;
#ifdef TERRAIN
    tileAlphaRange = tileAlphaMinMax(tileBase, tileSize);
#endif

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    scenePos = (gbufferModelViewInverse * viewPos).xyz;

#if defined TERRAIN && defined WAVING_PLANTS
    scenePos += wavingOffset(blockId, scenePos + cameraPosition, at_midBlock, frameTimeCounter, rainStrength);
    viewPos = gbufferModelView * vec4(scenePos, 1.0);
#endif

    gl_Position = taaJitterPos(gl_ProjectionMatrix * viewPos, vec2(viewWidth, viewHeight), frameCounter);
}
