/* Refrax — program/forward.vsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/blockid.glsl"
#include "/lib/water.glsl"

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float viewWidth, viewHeight;
uniform int frameCounter;

in vec4 mc_Entity;
in vec2 mc_midTexCoord;
in vec4 at_tangent;

out vec2 uv;
out vec2 lmcoord;
out vec4 vcolor;
out vec3 normalW;
out vec3 tangentW;
out float tangentSign;
out vec3 scenePos;
flat out int blockId;
out vec2 tileBase;
out vec2 tileSize;

void main() {
    uv = vec2(gl_TextureMatrix[0] * gl_MultiTexCoord0);
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vcolor = gl_Color;
    blockId = int(mc_Entity.x + 0.5);

    vec2 half_ = abs(uv - mc_midTexCoord);
    tileSize = max(half_ * 2.0, vec2(1e-6));
    tileBase = mc_midTexCoord - half_;

    normalW = normalize(mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal));
    tangentW = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * at_tangent.xyz);
    tangentSign = at_tangent.w;

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    scenePos = (gbufferModelViewInverse * viewPos).xyz;

#ifdef WATER
  #ifdef WATER_WAVES
    if (blockId == 10061 && normalW.y > 0.5) {
        vec3 worldPos = scenePos + cameraPosition;
        scenePos.y += waveHeight(worldPos.xz, frameTimeCounter);
        viewPos = gbufferModelView * vec4(scenePos, 1.0);
    }
  #endif
#endif

    gl_Position = taaJitterPos(gl_ProjectionMatrix * viewPos, vec2(viewWidth, viewHeight), frameCounter);
}
