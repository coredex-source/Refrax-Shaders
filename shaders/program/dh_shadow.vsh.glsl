/* Refrax — program/dh_shadow.vsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/shadows.glsl"

out vec4 vcolor;

void main() {
    vcolor = gl_Color;

    vec4 clip = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
    clip.xyz = distortShadowClip(clip.xyz / clip.w) * clip.w;
    gl_Position = clip;
}
