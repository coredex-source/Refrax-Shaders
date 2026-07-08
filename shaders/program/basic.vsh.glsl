/* Refrax :: gbuffers_basic */
#include "/lib/settings.glsl"
#include "/lib/common.glsl"
uniform float viewWidth, viewHeight;
uniform int frameCounter;
out vec4 vcolor;
void main() {
    vcolor = gl_Color;
    gl_Position = taaJitterPos(ftransform(), vec2(viewWidth, viewHeight), frameCounter);
}
