/* Refrax :: shadow */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/blockid.glsl"
#include "/lib/voxel.glsl"
#include "/lib/shadows.glsl"

uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform int renderStage;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

in vec4 mc_Entity;
in vec3 at_midBlock;

out vec2 uv;
out vec4 vcolor;

#ifdef COLORED_LIGHTING
writeonly uniform image3D voxelImg;
#endif

void main() {
    uv = vec2(gl_TextureMatrix[0] * gl_MultiTexCoord0);
    vcolor = gl_Color;
    int id = int(mc_Entity.x + 0.5);

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vec3 scenePos = (shadowModelViewInverse * viewPos).xyz;

#ifdef COLORED_LIGHTING
    bool voxelStage =
        renderStage == MC_RENDER_STAGE_NONE ||
        renderStage == MC_RENDER_STAGE_TERRAIN_SOLID ||
        renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT ||
        renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED ||
        renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT;
    if (gl_VertexID % 4 == 0 && voxelStage) {
        vec4 centerView = gl_ModelViewMatrix * (gl_Vertex + vec4(at_midBlock / 64.0, 0.0));
        vec3 blockCenter = (shadowModelViewInverse * centerView).xyz;
        ivec3 idx = sceneToVoxelIndex(blockCenter, cameraPosition);
        if (voxelInBounds(idx)) {
            if (isEmitter(id)) {
                vec3 c = blockLightColor(id);
                imageStore(voxelImg, idx, vec4(c * c * LPV_SEED, 1.0));
            } else if (!isNoOcclude(id)) {
                vec3 cell = fract(scenePos + cameraPosition);
                vec3 cornerDist = min(cell, 1.0 - cell);
                if (all(lessThan(cornerDist, vec3(0.02))))
                    imageStore(voxelImg, idx, vec4(0.0, 0.0, 0.0, 1.0)); // occluder
            }
        }
    }
#endif

#ifdef WAVING_PLANTS
    scenePos += wavingOffset(id, scenePos + cameraPosition, at_midBlock, frameTimeCounter, rainStrength);
#endif

    vec4 clip = gl_ProjectionMatrix * (shadowModelView * vec4(scenePos, 1.0));
    clip.xyz = distortShadowClip(clip.xyz / clip.w) * clip.w;
    gl_Position = clip;
}
