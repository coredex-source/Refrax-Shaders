/* Refrax — program/bloom_blur.vsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/bloom.glsl"

uniform float viewWidth;

out vec2 uv;

void main() {
    float xEnd = min((floor(viewWidth * bloomLevelScale(0) + 0.5) + 1.0) / viewWidth, 1.0);
    vec2 pos = vec2(gl_Vertex.x * xEnd, gl_Vertex.y);
    gl_Position = vec4(pos * 2.0 - 1.0, 0.0, 1.0);
    uv = pos;
}
