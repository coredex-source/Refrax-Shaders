/* Refrax — lib/dh.glsl */
#ifndef REFRAX_DH
#define REFRAX_DH

#if defined VOXY && defined DISTANT_HORIZONS
#undef DISTANT_HORIZONS
#endif

#if defined DISTANT_HORIZONS || defined VOXY
#define LOD_ACTIVE
#endif

#ifdef VOXY
uniform sampler2D vxDepthTexTrans;
uniform sampler2D vxDepthTexOpaque;
uniform mat4 vxProj;
uniform mat4 vxProjInv;
uniform mat4 vxProjPrev;
uniform int vxRenderDistance;

#define lodDepthTex0 vxDepthTexTrans
#define lodDepthTex1 vxDepthTexOpaque
#define lodProjection vxProj
#define lodProjectionInverse vxProjInv
#define lodPreviousProjection vxProjPrev
#define lodFarPlane (float(vxRenderDistance) * 16.0)
#elif defined DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform sampler2D dhDepthTex1;
uniform mat4 dhProjection;
uniform mat4 dhProjectionInverse;
uniform mat4 dhPreviousProjection;
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform int dhRenderDistance;

#define lodDepthTex0 dhDepthTex0
#define lodDepthTex1 dhDepthTex1
#define lodProjection dhProjection
#define lodProjectionInverse dhProjectionInverse
#define lodPreviousProjection dhPreviousProjection
#define lodFarPlane dhFarPlane
#endif

#ifdef DISTANT_HORIZONS
float dhOverdrawFade(float dist, float vanillaFar) {
    float end = max(vanillaFar - 16.0, 64.0);
    return smoothstep(end - 32.0, end, dist);
}
#endif

#endif
