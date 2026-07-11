/* Refrax — program/dh_gbuffer.vsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform mat4 gbufferModelViewInverse;
uniform float viewWidth, viewHeight;
uniform int frameCounter;

out vec2 lmcoord;
out vec4 vcolor;
out vec3 normalW;
out vec3 scenePos;
out float viewZ;
flat out int matId;

void main() {
    lmcoord = saturate((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
    vcolor = gl_Color;
#ifdef DISTANT_HORIZONS
    matId = dhMaterialId;
#else
    matId = 0;
#endif

    normalW = normalize(mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal));

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    viewZ = viewPos.z;
    scenePos = (gbufferModelViewInverse * viewPos).xyz;

    gl_Position = taaJitterPos(gl_ProjectionMatrix * viewPos, vec2(viewWidth, viewHeight), frameCounter);
}
