/* Refrax — program/composite1.fsh.glsl */

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;
uniform vec3 cameraPosition, previousCameraPosition;
uniform float viewWidth, viewHeight;

in vec2 uv;

/* RENDERTARGETS: 0,5 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outHistory;

#ifdef TAA
float max3(vec3 v) { return max(v.x, max(v.y, v.z)); }
vec3 taaTonemap(vec3 c)   { return c / (1.0 + max3(c)); }
vec3 taaUntonemap(vec3 c) { return c / max(1.0 - max3(c), 1e-4); }

vec3 clipToAABB(vec3 h, vec3 mn, vec3 mx) {
    vec3 c = 0.5 * (mx + mn);
    vec3 e = 0.5 * (mx - mn) + 1e-5;
    vec3 v = h - c;
    vec3 a = abs(v / e);
    float m = max(a.x, max(a.y, a.z));
    return m > 1.0 ? c + v / m : h;
}
#endif

void main() {
    vec4 c0 = texture(colortex0, uv);
    vec3 current = c0.rgb;
    if (any(isnan(current))) current = vec3(0.0);
    current = max(current, vec3(0.0));
    float reflectable = texture(colortex2, uv).a > 2.5 ? 0.0 : 1.0;
#ifndef TAA
    outColor = vec4(current, 1.0);
    outHistory = vec4(current, reflectable);
#else
    float depth = texture(depthtex0, uv).r;
    vec3 prevUV;
    if (depth < 0.56) {
        prevUV = vec3(uv, depth);
    } else if (depth >= 1.0) {
        vec3 viewPos = screenToView(vec3(uv, depth), gbufferProjectionInverse);
        vec3 scenePos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        prevUV = reprojectScene(scenePos, gbufferPreviousModelView, gbufferPreviousProjection, previousCameraPosition, previousCameraPosition);
    } else {
        vec3 viewPos = screenToView(vec3(uv, depth), gbufferProjectionInverse);
        vec3 scenePos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        prevUV = reprojectScene(scenePos, gbufferPreviousModelView, gbufferPreviousProjection, cameraPosition, previousCameraPosition);
    }

    if (clamp(prevUV.xy, 0.0, 1.0) != prevUV.xy) {
        outColor = vec4(current, 1.0);
        outHistory = vec4(current, reflectable);
        return;
    }

    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    vec3 cw = taaTonemap(current);
    vec3 m1 = cw, m2 = cw * cw;
    for (int x = -1; x <= 1; x++)
    for (int y = -1; y <= 1; y++) {
        if (x == 0 && y == 0) continue;
        vec3 s = taaTonemap(texture(colortex0, uv + vec2(x, y) * px).rgb);
        m1 += s; m2 += s * s;
    }
    vec3 mu = m1 / 9.0;
    vec3 sigma = sqrt(max(m2 / 9.0 - mu * mu, 0.0));
    vec3 hist = texture(colortex5, prevUV.xy).rgb;
    if (any(isnan(hist))) hist = current;
    vec3 hw = taaTonemap(max(hist, vec3(0.0)));
    hw = clipToAABB(hw, mu - TAA_CLIP_GAMMA * sigma, mu + TAA_CLIP_GAMMA * sigma);

    float motion = length((prevUV.xy - uv) / px);
    float blend = TAA_BLEND * saturate(1.0 - motion * 0.03);
    if (c0.a < 0.5) blend = min(blend, 0.15);
    vec3 resolved = min(taaUntonemap(mix(cw, hw, blend)), vec3(60000.0));
    outColor = vec4(resolved, 1.0);
    outHistory = vec4(resolved, reflectable);
#endif
}
