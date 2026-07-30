/* Refrax — program/armor_glint.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 uv;
in vec4 vcolor;

#if MC_VERSION >= 260100
/* RENDERTARGETS: 7 */
#else
/* RENDERTARGETS: 0 */
#endif
layout(location = 0) out vec4 outGlint;

void main() {
#if defined ARMOR_GLINT && MC_VERSION >= 260100
    vec4 glint = texture(gtexture, uv) * vcolor;
    if (glint.a < alphaTestRef) discard;
    vec3 col = srgbToLinear(glint.rgb);
    outGlint = vec4(col * col * glint.a * GLINT_STRENGTH, 1.0);
#else
    discard;
#endif
}
