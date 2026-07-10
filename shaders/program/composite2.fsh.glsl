/* Refrax — program/composite2.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/fsr1.glsl"

uniform sampler2D colortex0;
uniform float viewWidth, viewHeight;

in vec2 uv;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
#ifdef FSR
    vec2 inSize = floor(vec2(viewWidth, viewHeight) * FSR_SCALE);
    vec3 c = clamp(fsrEasu(colortex0, uv, inSize), 0.0, 0.98);
    float m = max(c.r, max(c.g, c.b));
    outColor = vec4(c / max(1.0 - m, 0.02), 1.0);
#else
    outColor = texture(colortex0, uv);
#endif
}
