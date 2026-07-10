#version 400 compatibility
#define WORLD_END
out vec2 uv;
void main() { gl_Position = ftransform(); uv = gl_MultiTexCoord0.xy; }
