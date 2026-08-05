/* Refrax — program/grade.vsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/lens.glsl"

#ifdef LENS_FLARE_ACTIVE
uniform sampler2D colortex12;
uniform mat4 gbufferProjection;
uniform vec3 sunPosition;
#endif

out vec2 uv;
#ifdef LENS_FLARE_ACTIVE
flat out vec2 flareOrigin;
flat out vec3 flareColor;
flat out float flareWeight;
flat out float flareFov;
#endif

void main() {
    gl_Position = ftransform();
    uv = gl_MultiTexCoord0.xy;

#ifdef LENS_FLARE_ACTIVE
    flareOrigin = flareOriginUV(sunPosition, gbufferProjection);
    flareFov = flareFovScale(gbufferProjection);
    flareColor = max(textureLod(colortex12, EXPOSURE_UV, 0.0).gba, vec3(0.0)) * (LENS_FLARE_STRENGTH * FLARE_GAIN);
    flareWeight = luminance(flareColor);
#endif
}
