/* Refrax - damagedblock.vsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform float viewWidth, viewHeight;
uniform int frameCounter;

out vec2 uv;
out vec4 vcolor;

void main() {
    uv = vec2(gl_TextureMatrix[0] * gl_MultiTexCoord0);
    vcolor = gl_Color;
    gl_Position = taaJitterPos(ftransform(), vec2(viewWidth, viewHeight), frameCounter);
}
