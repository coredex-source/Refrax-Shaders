/* Refrax — program/atmos_cloudshadow.csh.glsl */

#define REFRAX_CLOUD_SHADOW_GEN
#include "/lib/settings.glsl"
#include "/lib/clouds.glsl"

layout(local_size_x = 16, local_size_y = 16) in;
const ivec3 workGroups = ivec3(32, 32, 1);

layout(rgba16f) writeonly uniform image2D refraxCloudShadowImg;

uniform mat4 gbufferModelViewInverse;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;

void main() {
    ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
    if (texel.x >= CLOUD_SHADOW_RES || texel.y >= CLOUD_SHADOW_RES) return;

    vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

    vec3 od = vec3(0.0);
    if (lightDir.y >= 0.06) {
        vec2 q = cloudShadowMapPos(texel, cameraPosition, lightDir);
        od = cloudShadowSlabs(q, lightDir, cloudWind(frameTimeCounter), rainStrength, cloudDailyBias());
    }

    imageStore(refraxCloudShadowImg, texel, vec4(od, 1.0));
}
