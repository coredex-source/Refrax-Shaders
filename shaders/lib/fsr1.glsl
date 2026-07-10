/* Refrax — lib/fsr1.glsl
 *
 * AMD FidelityFX Super Resolution 1.0 (FSR 1)
 *
 * FSR is developed by AMD. The original source is licensed under the MIT License:
 *
 *   Copyright (c) 2021 Advanced Micro Devices, Inc. All rights reserved.
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
 *   Source: https://github.com/GPUOpen-Effects/FidelityFX-FSR
 */
#ifndef REFRAX_FSR1
#define REFRAX_FSR1

float fsrMax3(vec3 c) { return max(c.r, max(c.g, c.b)); }
vec3 fsrTonemap(vec3 c)   { return c / (1.0 + fsrMax3(c)); }
vec3 fsrUntonemap(vec3 c) { return c / max(1.0 - fsrMax3(c), 1e-4); }

/* ---------------- EASU ---------------- */
void fsrEasuSet(inout vec2 dir, inout float len, vec2 pp,
                bool biS, bool biT, bool biU, bool biV,
                float lA, float lB, float lC, float lD, float lE) {
    float w = 0.0;
    if (biS) w = (1.0 - pp.x) * (1.0 - pp.y);
    if (biT) w =        pp.x  * (1.0 - pp.y);
    if (biU) w = (1.0 - pp.x) *        pp.y;
    if (biV) w =        pp.x  *        pp.y;

    float dc = lD - lC;
    float cb = lC - lB;
    float lenX = max(abs(dc), abs(cb));
    lenX = 1.0 / max(lenX, 3.05185e-5);
    float dirX = lD - lB;
    dir.x += dirX * w;
    lenX = saturate(abs(dirX) * lenX);
    len += lenX * lenX * w;

    float ec = lE - lC;
    float ca = lC - lA;
    float lenY = max(abs(ec), abs(ca));
    lenY = 1.0 / max(lenY, 3.05185e-5);
    float dirY = lE - lA;
    dir.y += dirY * w;
    lenY = saturate(abs(dirY) * lenY);
    len += lenY * lenY * w;
}

void fsrEasuTap(inout vec3 aC, inout float aW, vec2 off, vec2 dir, vec2 len,
                float lob, float clp, vec3 c) {
    vec2 v = vec2(off.x * dir.x + off.y * dir.y,
                  off.x * (-dir.y) + off.y * dir.x);
    v *= len;
    float d2 = min(dot(v, v), clp);
    float wB = 2.0 / 5.0 * d2 - 1.0;
    float wA = lob * d2 - 1.0;
    wB *= wB;
    wA *= wA;
    wB = 25.0 / 16.0 * wB - (25.0 / 16.0 - 1.0);
    float w = wB * wA;
    aC += c * w;
    aW += w;
}

vec3 fsrEasu(sampler2D tex, vec2 uvOut, vec2 inSize) {
    vec2 pp = uvOut * inSize - 0.5;
    vec2 fp = floor(pp);
    pp -= fp;
    ivec2 base = ivec2(fp);
    ivec2 maxT = ivec2(inSize) - 1;

    #define EASU_FETCH(dx, dy) fsrTonemap(max(texelFetch(tex, clamp(base + ivec2(dx, dy), ivec2(0), maxT), 0).rgb, vec3(0.0)))
    vec3 tB = EASU_FETCH( 0, -1), tC = EASU_FETCH( 1, -1);
    vec3 tE = EASU_FETCH(-1,  0), tF = EASU_FETCH( 0,  0), tG = EASU_FETCH( 1,  0), tH = EASU_FETCH( 2,  0);
    vec3 tI = EASU_FETCH(-1,  1), tJ = EASU_FETCH( 0,  1), tK = EASU_FETCH( 1,  1), tL = EASU_FETCH( 2,  1);
    vec3 tN = EASU_FETCH( 0,  2), tO = EASU_FETCH( 1,  2);
    #undef EASU_FETCH

    #define EASU_LUMA(t) (t.b * 0.5 + (t.r * 0.5 + t.g))
    float lB = EASU_LUMA(tB), lC = EASU_LUMA(tC);
    float lE = EASU_LUMA(tE), lF = EASU_LUMA(tF), lG = EASU_LUMA(tG), lH = EASU_LUMA(tH);
    float lI = EASU_LUMA(tI), lJ = EASU_LUMA(tJ), lK = EASU_LUMA(tK), lL = EASU_LUMA(tL);
    float lN = EASU_LUMA(tN), lO = EASU_LUMA(tO);
    #undef EASU_LUMA

    vec2 dir = vec2(0.0);
    float len = 0.0;
    fsrEasuSet(dir, len, pp, true, false, false, false, lB, lE, lF, lG, lJ);
    fsrEasuSet(dir, len, pp, false, true, false, false, lC, lF, lG, lH, lK);
    fsrEasuSet(dir, len, pp, false, false, true, false, lF, lI, lJ, lK, lN);
    fsrEasuSet(dir, len, pp, false, false, false, true, lG, lJ, lK, lL, lO);

    vec2 dir2 = dir * dir;
    float dirR = dir2.x + dir2.y;
    bool zro = dirR < (1.0 / 32768.0);
    dirR = inversesqrt(max(dirR, 1e-12));
    dirR = zro ? 1.0 : dirR;
    dir.x = zro ? 1.0 : dir.x;
    dir *= dirR;

    len = len * 0.5;
    len *= len;
    float stretch = (dir.x * dir.x + dir.y * dir.y) / max(abs(dir.x), abs(dir.y));
    vec2 len2 = vec2(1.0 + (stretch - 1.0) * len, 1.0 - 0.5 * len);
    float lob = 0.5 + ((1.0 / 4.0 - 0.04) - 0.5) * len;
    float clp = 1.0 / lob;

    vec3 min4 = min(min(tF, tG), min(tJ, tK));
    vec3 max4 = max(max(tF, tG), max(tJ, tK));

    vec3 aC = vec3(0.0);
    float aW = 0.0;
    fsrEasuTap(aC, aW, vec2( 0.0, -1.0) - pp, dir, len2, lob, clp, tB);
    fsrEasuTap(aC, aW, vec2( 1.0, -1.0) - pp, dir, len2, lob, clp, tC);
    fsrEasuTap(aC, aW, vec2(-1.0,  0.0) - pp, dir, len2, lob, clp, tE);
    fsrEasuTap(aC, aW, vec2( 0.0,  0.0) - pp, dir, len2, lob, clp, tF);
    fsrEasuTap(aC, aW, vec2( 1.0,  0.0) - pp, dir, len2, lob, clp, tG);
    fsrEasuTap(aC, aW, vec2( 2.0,  0.0) - pp, dir, len2, lob, clp, tH);
    fsrEasuTap(aC, aW, vec2(-1.0,  1.0) - pp, dir, len2, lob, clp, tI);
    fsrEasuTap(aC, aW, vec2( 0.0,  1.0) - pp, dir, len2, lob, clp, tJ);
    fsrEasuTap(aC, aW, vec2( 1.0,  1.0) - pp, dir, len2, lob, clp, tK);
    fsrEasuTap(aC, aW, vec2( 2.0,  1.0) - pp, dir, len2, lob, clp, tL);
    fsrEasuTap(aC, aW, vec2( 0.0,  2.0) - pp, dir, len2, lob, clp, tN);
    fsrEasuTap(aC, aW, vec2( 1.0,  2.0) - pp, dir, len2, lob, clp, tO);

    vec3 pix = min(max4, max(min4, aC / aW));
    return fsrUntonemap(pix);
}

/* ---------------- RCAS ---------------- */
#define FSR_RCAS_LIMIT (0.25 - 1.0 / 16.0)

vec3 rcasSharpen(vec3 b, vec3 d, vec3 e, vec3 f, vec3 h, float scale) {
    float bL = b.b * 0.5 + (b.r * 0.5 + b.g);
    float dL = d.b * 0.5 + (d.r * 0.5 + d.g);
    float eL = e.b * 0.5 + (e.r * 0.5 + e.g);
    float fL = f.b * 0.5 + (f.r * 0.5 + f.g);
    float hL = h.b * 0.5 + (h.r * 0.5 + h.g);

    float nz = 0.25 * bL + 0.25 * dL + 0.25 * fL + 0.25 * hL - eL;
    float rangeL = max(max(bL, dL), max(eL, max(fL, hL)))
                 - min(min(bL, dL), min(eL, min(fL, hL)));
    nz = saturate(abs(nz) / max(rangeL, 1e-4));
    nz = -0.5 * nz + 1.0;

    vec3 mn4 = min(min(b, d), min(f, h));
    vec3 mx4 = max(max(b, d), max(f, h));
    vec3 hitMin = mn4 / max(4.0 * mx4, vec3(1e-4));
    vec3 hitMax = (1.0 - mx4) / min(4.0 * mn4 - 4.0, vec3(-1e-4));
    vec3 lobeRGB = max(-hitMin, hitMax);
    float lobe = max(-FSR_RCAS_LIMIT, min(max(lobeRGB.r, max(lobeRGB.g, lobeRGB.b)), 0.0)) * scale;
    lobe *= nz;

    float rcpL = 1.0 / (4.0 * lobe + 1.0);
    return saturate(((b + d + f + h) * lobe + e) * rcpL);
}

#endif
