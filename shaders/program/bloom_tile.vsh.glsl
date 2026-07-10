/* Refrax — program/bloom_tile.vsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/bloom.glsl"

void main() {
#if BLOOM_LEVEL == 0
    const float yStart = 0.0;
    const float xEnd = bloomLevelScale(0);
#else
    const float yStart = bloomLevelY(BLOOM_LEVEL - 1);
    const float xEnd = bloomLevelScale(BLOOM_LEVEL - 1);
#endif
    const float yEnd = bloomLevelY(BLOOM_LEVEL + 1);

    vec2 pos = vec2(gl_Vertex.x * xEnd, mix(yStart, yEnd, gl_Vertex.y));
    gl_Position = vec4(pos * 2.0 - 1.0, 0.0, 1.0);
}
