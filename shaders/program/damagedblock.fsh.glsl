/* Refrax - program/damagedblock.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 uv;
in vec4 vcolor;

/* RENDERTARGETS: 11 */
layout(location = 0) out vec4 outCrack;

void main() {
    vec4 tex = texture(gtexture, uv);

    /* Tested against the texture alpha alone rather than tex.a * vcolor.a: if
       the crumbling pass ever supplies a zero vertex alpha, folding it in here
       would discard every fragment and silently kill the effect. */
    if (tex.a < alphaTestRef) discard;

    vec3 tint = vcolor.a > 0.0 ? vcolor.rgb : vec3(1.0);
    float darken = 1.0 - saturate(luminance(tex.rgb * tint) * 2.0);
    outCrack = vec4(saturate(darken * CRACK_STRENGTH));
}
