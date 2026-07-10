/* Refrax — lib/cas.glsl
 *
 * Contrast Adaptive Sharpening (CAS).
 * Ported from AMD FidelityFX CAS (ffx_cas.h), sharpen-only (non-scaling) path,
 * adapted to run on an already-resolved LDR 3x3 neighborhood.
 *
 * CAS is developed by AMD. The original source is licensed under the MIT License:
 *
 *   Copyright (c) 2020 Advanced Micro Devices, Inc. All rights reserved.
 *
 *   Permission is hereby granted, free of charge, to any person obtaining a copy
 *   of this software and associated documentation files (the "Software"), to deal
 *   in the Software without restriction, including without limitation the rights
 *   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *   copies of the Software, and to permit persons to whom the Software is
 *   furnished to do so, subject to the following conditions:
 *
 *   The above copyright notice and this permission notice shall be included in
 *   all copies or substantial portions of the Software.
 *
 *   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *   SOFTWARE.
 *
 *   Source: https://github.com/GPUOpen-Effects/FidelityFX-CAS
 */
#ifndef REFRAX_CAS
#define REFRAX_CAS

vec3 casSharpen(vec3 a, vec3 b, vec3 c, vec3 d, vec3 e, vec3 f, vec3 g, vec3 h, vec3 i, float sharpness) {
    vec3 mn = min(min(min(d, e), min(f, b)), h);
    mn += min(mn, min(min(a, c), min(g, i)));
    vec3 mx = max(max(max(d, e), max(f, b)), h);
    mx += max(mx, max(max(a, c), max(g, i)));
    vec3 rcpMx = 1.0 / max(mx, vec3(1e-5));
    vec3 amp = clamp(min(mn, 2.0 - mx) * rcpMx, 0.0, 1.0);
    amp = sqrt(amp);
    float peak = -1.0 / mix(8.0, 5.0, clamp(sharpness, 0.0, 1.0));
    vec3 w = amp * peak;
    vec3 rcpW = 1.0 / (1.0 + 4.0 * w);
    return clamp((b * w + d * w + f * w + h * w + e) * rcpW, 0.0, 1.0);
}

#endif
