
/* Refrax — lib/settings.glsl */
#ifndef REFRAX_SETTINGS
#define REFRAX_SETTINGS

#define SHADOWS
#define COLORED_SHADOWS
#define COLORED_LIGHTING
#define GOD_RAYS
#define BLOOM
#define AA_MODE 2           //[0 1 2] 0=off 1=FXAA 2=TAA
#define PBR_MATERIALS
//#define POM
#define PERFORMANCE_MODE 3  //[1 2 3 4 5 6 7] 1=off 2=low 3=medium 4=high 5=very_high 6=extreme 7=overdrive
#define WAVING_PLANTS
#define END_PORTAL_STYLE 1  //[0 1 2 3 4] 0=classic 1=vibrant 2=deep_space 3=amethyst 4=void
#define WATER_WAVES
//#define WATER_NOISY_WAVES
#define HAND_LIGHT

#if AA_MODE == 2
#define TAA
#elif AA_MODE == 1
#define FXAA
#endif

#if PERFORMANCE_MODE == 2
#define PERF_SAMPLE_NUM 3
#define PERF_SAMPLE_DEN 4
#elif PERFORMANCE_MODE == 3
#define PERF_SAMPLE_NUM 1
#define PERF_SAMPLE_DEN 2
#elif PERFORMANCE_MODE == 4
#define PERF_SAMPLE_NUM 1
#define PERF_SAMPLE_DEN 4
#elif PERFORMANCE_MODE == 5
#define PERF_SAMPLE_NUM 1
#define PERF_SAMPLE_DEN 6
#elif PERFORMANCE_MODE == 6
#define PERF_SAMPLE_NUM 1
#define PERF_SAMPLE_DEN 8
#elif PERFORMANCE_MODE == 7
#define PERF_SAMPLE_NUM 1
#define PERF_SAMPLE_DEN 16
#else
#define PERF_SAMPLE_NUM 1
#define PERF_SAMPLE_DEN 1
#endif

#define PERF_SCALED_COUNT(count, floorCount) max((((count) * PERF_SAMPLE_NUM + PERF_SAMPLE_DEN - 1) / PERF_SAMPLE_DEN), (floorCount))
#define PERF_SCALED_CONST(count) (((count) * PERF_SAMPLE_NUM + PERF_SAMPLE_DEN - 1) / PERF_SAMPLE_DEN)

#define CLOUD_MODE 2        //[0 1 2] 0=off 1=2D 2=volumetric
#define AO_MODE 1           //[0 1 2] 0=off 1=SSAO 2=GTAO-ish
#define REFLECTION_MODE 1   //[0 1 2] 0=sky-only 1=SSR 2=high SSR
#define TONEMAP_OPERATOR 1  //[0 1 2 3] 0=AgX 1=ACES 2=Reinhard-Jodie 3=Uncharted2

#define VL_STEPS 12          // [4 6 8 12 16 24 32 48]
#define CLOUD_STEPS 12       // [6 8 12 16 20 24 32 48 64]
#define CLOUD_LIGHT_STEPS 3  // [2 3 4 6 8]
#define SSR_STEPS 24         // [8 12 16 24 32 48 64]
#define SSAO_SAMPLES 8       // [4 6 8 12 16 24]
#define SHADOW_SAMPLES 4     // [1 2 4 6 9 12 16 25]
#define POM_SAMPLES 16       // [8 16 24 32 48]

#define EXPOSURE 1.0         // [0.25 0.4 0.55 0.7 0.85 1.0 1.15 1.3 1.5 1.75 2.0 2.5 3.0]
#define BLOOM_STRENGTH 1.0   // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0 2.5 3.0]
#define SHADOW_SOFTNESS 1.0  // [0.25 0.5 0.75 1.0 1.25 1.5 2.0 2.5 3.0]
#define CLOUD_COVERAGE 0.5   // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define FOG_DENSITY 1.0      // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0 4.0]
#define VL_STRENGTH 1.0      // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define EMISSION_STRENGTH 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define SATURATION 1.0       // [0.0 0.2 0.4 0.6 0.8 0.9 1.0 1.1 1.2 1.4 1.6 1.8 2.0]
#define CONTRAST 1.0         // [0.6 0.7 0.8 0.9 0.95 1.0 1.05 1.1 1.2 1.3 1.4]
#define VIBRANCE 1.0         // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define WHITE_BALANCE 0.0    // [-1.0 -0.75 -0.5 -0.25 0.0 0.25 0.5 0.75 1.0]
#define MIN_AMBIENT 1.0      // [0.0 0.25 0.5 0.75 1.0 1.5 2.0 3.0 4.0]
#define WATER_ABSORPTION 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define POM_DEPTH 0.25       // [0.05 0.1 0.15 0.2 0.25 0.35 0.5 0.75 1.0]
#define LPV_INTENSITY 1.0    // [0.25 0.5 0.75 1.0 1.5 2.0 3.0 4.0]
#define LPV_FALLOFF 0.80     // [0.50 0.60 0.70 0.75 0.80 0.85 0.90 0.95]

const int   shadowMapResolution = 2048;  // [512 1024 2048 3072 4096 6144 8192]
const float shadowDistance = 128.0; // [48.0 64.0 96.0 128.0 160.0 192.0 256.0 320.0 384.0]
const float sunPathRotation = -30.0; // [-60.0 -45.0 -30.0 -15.0 0.0 15.0 30.0 45.0 60.0]
const float shadowDistanceRenderMul = 1.0;
const float entityShadowDistanceMul = 0.5;
const float ambientOcclusionLevel = 1.0;

/* Manual edits */
#define SUN_BRIGHTNESS 2.8
#define MOON_BRIGHTNESS 0.25
#define SKY_SATURATION 1.0

#define CLOUD_ALTITUDE 280.0
#define CLOUD_THICKNESS 140.0
#define CLOUD_SCALE 0.0011
#define CLOUD_WIND vec2(6.0, 1.5)
#define CLOUD_DENSITY 0.055

#define FOG_BASE 0.0016
#define FOG_HEIGHT_FALLOFF 0.012
#define VL_DISTANCE 96.0

#define WATER_COLOR vec3(0.05, 0.30, 0.43)
#define WATER_ABSORB vec3(0.36, 0.11, 0.07)
#define WATER_SCATTER 0.055
#define WATER_WAVE_HEIGHT 0.045
#define WATER_WAVE_INTENSITY 0.55 // [0.0 0.25 0.4 0.55 0.7 0.85 1.0 1.25 1.5]
#define WATER_ROUGHNESS  0.018
#define WATER_REFLECTION_MODE 0 //[0 1 2] 0=sky-only 1=fast SSR 2=full SSR
#define REFRACTION_INTENSITY 1.0
#define UNDERWATER_DISTORTION 1.0

#define SUN_GLINT_RADIUS 0.075
#define SUN_GLINT_STRENGTH 150.0
#define PBR_GLINT_STRENGTH 12.0
#define SHADOW_TINT 0.90

#define BLOCKLIGHT_SCALE 2.2
#define LPV_SEED 4.0
#define FALLBACK_BLOCKLIGHT vec3(1.0, 0.60, 0.34)
#define LPV_COLOR_SATURATION 0.95
#define NETHER_LPV_SCALE 2.0
#define NETHER_FALLBACK_SCALE 1.0
#define NETHER_PORTAL_BRIGHTNESS 4.0
//#define DEBUG_LPV
//#define DEBUG_PBR

#define NETHER_AMBIENT 1.0
#define END_AMBIENT 1.0
#define END_LIGHT 1.0
#define DIMENSION_EXPOSURE 1.05

#define TAA_BLEND 0.90
#define TAA_CLIP_GAMMA 1.25

#define WAVE_SPEED 1.0
#define WAVE_AMOUNT 1.0

#endif
