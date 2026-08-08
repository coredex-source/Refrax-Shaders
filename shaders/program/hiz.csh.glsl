/* Refrax — program/hiz.csh.glsl */

#include "/lib/settings.glsl"
#include "/lib/hiz.glsl"

layout(local_size_x = 16, local_size_y = 16) in;
const vec2 workGroupsRender = vec2(HIZ_DISPATCH, HIZ_DISPATCH);

layout(rgba32f) uniform image2D refraxHiZImg;

uniform sampler2D depthtex0;
uniform float viewWidth, viewHeight;

void main() {
    ivec2 full = ivec2(viewWidth, viewHeight);
    ivec2 sz = hizSize(full, HIZ_LEVEL);
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    if (p.x >= sz.x || p.y >= sz.y) return;

    vec2 mm;
#if HIZ_LEVEL == 1
    ivec2 s = p * 2;
    float d0 = texelFetch(depthtex0, min(s + ivec2(0, 0), full - 1), 0).r;
    float d1 = texelFetch(depthtex0, min(s + ivec2(1, 0), full - 1), 0).r;
    float d2 = texelFetch(depthtex0, min(s + ivec2(0, 1), full - 1), 0).r;
    float d3 = texelFetch(depthtex0, min(s + ivec2(1, 1), full - 1), 0).r;
    mm = vec2(min(min(d0, d1), min(d2, d3)), max(max(d0, d1), max(d2, d3)));
#else
    ivec2 ps = hizSize(full, HIZ_LEVEL - 1);
    ivec2 s = p * 2;
    vec2 a = imageLoad(refraxHiZImg, hizTexel(full, HIZ_LEVEL - 1, min(s + ivec2(0, 0), ps - 1))).rg;
    vec2 b = imageLoad(refraxHiZImg, hizTexel(full, HIZ_LEVEL - 1, min(s + ivec2(1, 0), ps - 1))).rg;
    vec2 c = imageLoad(refraxHiZImg, hizTexel(full, HIZ_LEVEL - 1, min(s + ivec2(0, 1), ps - 1))).rg;
    vec2 d = imageLoad(refraxHiZImg, hizTexel(full, HIZ_LEVEL - 1, min(s + ivec2(1, 1), ps - 1))).rg;
    mm = vec2(min(min(a.x, b.x), min(c.x, d.x)), max(max(a.y, b.y), max(c.y, d.y)));
#endif

    ivec2 dst = hizTexel(full, HIZ_LEVEL, p);
    if (dst.y >= imageSize(refraxHiZImg).y) return;
    imageStore(refraxHiZImg, dst, vec4(mm, 0.0, 1.0));
}
