/* Refrax :: shadow */

#include "/lib/settings.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 uv;
in vec4 vcolor;

layout(location = 0) out vec4 outColor0;

void main() {
    vec4 color = texture(gtexture, uv) * vcolor;
    if (color.a < alphaTestRef) discard;
    vec3 hue = color.rgb / max(max(color.r, max(color.g, color.b)), 1e-3);
    hue = pow(hue, vec3(1.8));
    hue = mix(vec3(1.0), hue, 0.90);
    float w = SHADOW_TINT * smoothstep(0.0, 0.4, color.a);
    outColor0 = vec4(mix(vec3(1.0), hue, w), 1.0);
}
