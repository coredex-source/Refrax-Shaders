/* Refrax :: gbuffers_basic */
in vec4 vcolor;
#if MC_VERSION >= 260100
/* RENDERTARGETS: 0 */
#else
/* RENDERTARGETS: 7 */
#endif
layout(location = 0) out vec4 outColor;
void main() { outColor = vcolor; }
