/* Refrax :: shadow */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/caustics.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;
#ifdef CAUSTICS_ACTIVE
uniform sampler2D noisetex;
uniform mat4 gbufferModelViewInverse;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform float frameTimeCounter, rainStrength;
#endif

in vec2 uv;
in vec4 vcolor;
in vec3 scenePos;
flat in int blockId;

layout(location = 0) out vec4 outColor0;

void main() {
    vec4 color = texture(gtexture, uv) * vcolor;
    if (color.a < alphaTestRef) discard;

#ifdef COLORED_SHADOWS
    vec3 hue = color.rgb / max(max(color.r, max(color.g, color.b)), 1e-3);
    hue = pow(hue, vec3(1.8));
    hue = mix(vec3(1.0), hue, 0.90);
    float w = SHADOW_TINT * smoothstep(0.0, 0.4, color.a);
    vec3 tint = mix(vec3(1.0), hue, w);
#else
    vec3 tint = vec3(1.0);
#endif

#ifdef CAUSTICS_ACTIVE
    if (blockId == 10061) {
        vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
        tint *= waterCaustic(noisetex, scenePos, cameraPosition, lightDir, frameTimeCounter, rainStrength);
    }
#endif

    outColor0 = vec4(min(tint, vec3(CAUSTIC_CLAMP)) * SHADOW_COLOR_ENCODE, 1.0);
}
