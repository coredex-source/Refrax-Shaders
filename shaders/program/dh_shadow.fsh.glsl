/* Refrax — program/dh_shadow.fsh.glsl */

#include "/lib/settings.glsl"

in vec4 vcolor;

layout(location = 0) out vec4 outColor0;

void main() {
    vec3 hue = vcolor.rgb / max(max(vcolor.r, max(vcolor.g, vcolor.b)), 1e-3);
    hue = pow(hue, vec3(1.8));
    hue = mix(vec3(1.0), hue, 0.90);
    float w = SHADOW_TINT * smoothstep(0.0, 0.4, vcolor.a);
    outColor0 = vec4(mix(vec3(1.0), hue, w), 1.0);
}
