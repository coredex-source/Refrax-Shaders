/* Refrax - basic.fsh.glsl */
in vec4 vcolor;
#if MC_VERSION >= 260100
/* RENDERTARGETS: 0,7 */
#else
/* RENDERTARGETS: 7 */
#endif
layout(location = 0) out vec4 outColor;
#if MC_VERSION >= 260100
layout(location = 1) out vec4 outLineMask;
#endif
void main() {
#if MC_VERSION >= 260100
    float tag = clamp(vcolor.a, 0.001, 0.75);
    outColor = vec4(vcolor.rgb * (vcolor.a / tag), tag);
    outLineMask = vec4(0.0, 0.0, 0.0, 1.0);
#else
    outColor = vcolor;
#endif
}
