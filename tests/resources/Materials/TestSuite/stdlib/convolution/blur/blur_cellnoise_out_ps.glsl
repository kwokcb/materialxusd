#version 400


struct BSDF { vec3 response; vec3 throughput; };
#define EDF vec3
struct surfaceshader { vec3 color; vec3 transparency; };
struct volumeshader { vec3 color; vec3 transparency; };
struct displacementshader { vec3 offset; float scale; };
struct lightshader { vec3 intensity; vec3 direction; };
#define material surfaceshader

const float c_box_filter_weights[84] = float[84](1.000000, 0.111111, 0.111111, 0.111111, 0.111111, 0.111111, 0.111111, 0.111111, 0.111111, 0.111111, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.040000, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408, 0.020408);
const float c_gaussian_filter_weights[84] = float[84](1.000000, 0.077847, 0.123317, 0.077847, 0.123317, 0.195346, 0.123317, 0.077847, 0.123317, 0.077847, 0.003765, 0.015019, 0.023792, 0.015019, 0.003765, 0.015019, 0.059912, 0.094907, 0.059912, 0.015019, 0.023792, 0.094907, 0.150342, 0.094907, 0.023792, 0.015019, 0.059912, 0.094907, 0.059912, 0.015019, 0.003765, 0.015019, 0.023792, 0.015019, 0.003765, 0.000036, 0.000363, 0.001446, 0.002291, 0.001446, 0.000363, 0.000036, 0.000363, 0.003676, 0.014662, 0.023226, 0.014662, 0.003676, 0.000363, 0.001446, 0.014662, 0.058488, 0.092651, 0.058488, 0.014662, 0.001446, 0.002291, 0.023226, 0.092651, 0.146768, 0.092651, 0.023226, 0.002291, 0.001446, 0.014662, 0.058488, 0.092651, 0.058488, 0.014662, 0.001446, 0.000363, 0.003676, 0.014662, 0.023226, 0.014662, 0.003676, 0.000363, 0.000036, 0.000363, 0.001446, 0.002291, 0.001446, 0.000363, 0.000036);

// Uniform block: PublicUniforms
uniform int texcoord1_index = 0;
uniform float multiply1_in2 = 100.000000;
uniform float blur_cellnoise_size = 0.500000;
uniform int blur_cellnoise_filtertype = 1;

in VertexData
{
    vec2 texcoord_0;
} vd;

// Pixel shader outputs
out vec4 out1;

#define M_FLOAT_EPS 1e-8

#define mx_mod mod
#define mx_inverse inverse
#define mx_inversesqrt inversesqrt
#define mx_sin sin
#define mx_cos cos
#define mx_tan tan
#define mx_asin asin
#define mx_acos acos
#define mx_atan atan
#define mx_radians radians

float mx_square(float x)
{
    return x*x;
}

vec2 mx_square(vec2 x)
{
    return x*x;
}

vec3 mx_square(vec3 x)
{
    return x*x;
}

vec3 mx_srgb_encode(vec3 color)
{
    bvec3 isAbove = greaterThan(color, vec3(0.0031308));
    vec3 linSeg = color * 12.92;
    vec3 powSeg = 1.055 * pow(max(color, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
    return mix(linSeg, powSeg, isAbove);
}

/*
Noise Library.

This library is a modified version of the noise library found in
Open Shading Language:
github.com/imageworks/OpenShadingLanguage/blob/master/src/include/OSL/oslnoise.h

It contains the subset of noise types needed to implement the MaterialX
standard library. The modifications are mainly conversions from C++ to GLSL.
Produced results should be identical to the OSL noise functions.

Original copyright notice:
------------------------------------------------------------------------
Copyright (c) 2009-2010 Sony Pictures Imageworks Inc., et al.
All Rights Reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:
* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.
* Neither the name of Sony Pictures Imageworks nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
------------------------------------------------------------------------
*/

float mx_select(bool b, float t, float f)
{
    return b ? t : f;
}

float mx_negate_if(float val, bool b)
{
    return b ? -val : val;
}

int mx_floor(float x)
{
    return int(floor(x));
}

// return mx_floor as well as the fractional remainder
float mx_floorfrac(float x, out int i)
{
    i = mx_floor(x);
    return x - float(i);
}

float mx_bilerp(float v0, float v1, float v2, float v3, float s, float t)
{
    float s1 = 1.0 - s;
    return (1.0 - t) * (v0*s1 + v1*s) + t * (v2*s1 + v3*s);
}
vec3 mx_bilerp(vec3 v0, vec3 v1, vec3 v2, vec3 v3, float s, float t)
{
    float s1 = 1.0 - s;
    return (1.0 - t) * (v0*s1 + v1*s) + t * (v2*s1 + v3*s);
}
float mx_trilerp(float v0, float v1, float v2, float v3, float v4, float v5, float v6, float v7, float s, float t, float r)
{
    float s1 = 1.0 - s;
    float t1 = 1.0 - t;
    float r1 = 1.0 - r;
    return (r1*(t1*(v0*s1 + v1*s) + t*(v2*s1 + v3*s)) +
            r*(t1*(v4*s1 + v5*s) + t*(v6*s1 + v7*s)));
}
vec3 mx_trilerp(vec3 v0, vec3 v1, vec3 v2, vec3 v3, vec3 v4, vec3 v5, vec3 v6, vec3 v7, float s, float t, float r)
{
    float s1 = 1.0 - s;
    float t1 = 1.0 - t;
    float r1 = 1.0 - r;
    return (r1*(t1*(v0*s1 + v1*s) + t*(v2*s1 + v3*s)) +
            r*(t1*(v4*s1 + v5*s) + t*(v6*s1 + v7*s)));
}

// 2 and 3 dimensional gradient functions - perform a dot product against a
// randomly chosen vector. Note that the gradient vector is not normalized, but
// this only affects the overall "scale" of the result, so we simply account for
// the scale by multiplying in the corresponding "perlin" function.
float mx_gradient_float(uint hash, float x, float y)
{
    // 8 possible directions (+-1,+-2) and (+-2,+-1)
    uint h = hash & 7u;
    float u = mx_select(h<4u, x, y);
    float v = 2.0 * mx_select(h<4u, y, x);
    // compute the dot product with (x,y).
    return mx_negate_if(u, bool(h&1u)) + mx_negate_if(v, bool(h&2u));
}
float mx_gradient_float(uint hash, float x, float y, float z)
{
    // use vectors pointing to the edges of the cube
    uint h = hash & 15u;
    float u = mx_select(h<8u, x, y);
    float v = mx_select(h<4u, y, mx_select((h==12u)||(h==14u), x, z));
    return mx_negate_if(u, bool(h&1u)) + mx_negate_if(v, bool(h&2u));
}
vec3 mx_gradient_vec3(uvec3 hash, float x, float y)
{
    return vec3(mx_gradient_float(hash.x, x, y), mx_gradient_float(hash.y, x, y), mx_gradient_float(hash.z, x, y));
}
vec3 mx_gradient_vec3(uvec3 hash, float x, float y, float z)
{
    return vec3(mx_gradient_float(hash.x, x, y, z), mx_gradient_float(hash.y, x, y, z), mx_gradient_float(hash.z, x, y, z));
}
// Scaling factors to normalize the result of gradients above.
// These factors were experimentally calculated to be:
//    2D:   0.6616
//    3D:   0.9820
float mx_gradient_scale2d(float v) { return 0.6616 * v; }
float mx_gradient_scale3d(float v) { return 0.9820 * v; }
vec3 mx_gradient_scale2d(vec3 v) { return 0.6616 * v; }
vec3 mx_gradient_scale3d(vec3 v) { return 0.9820 * v; }

/// Bitwise circular rotation left by k bits (for 32 bit unsigned integers)
uint mx_rotl32(uint x, int k)
{
    return (x<<k) | (x>>(32-k));
}

void mx_bjmix(inout uint a, inout uint b, inout uint c)
{
    a -= c; a ^= mx_rotl32(c, 4); c += b;
    b -= a; b ^= mx_rotl32(a, 6); a += c;
    c -= b; c ^= mx_rotl32(b, 8); b += a;
    a -= c; a ^= mx_rotl32(c,16); c += b;
    b -= a; b ^= mx_rotl32(a,19); a += c;
    c -= b; c ^= mx_rotl32(b, 4); b += a;
}

// Mix up and combine the bits of a, b, and c (doesn't change them, but
// returns a hash of those three original values).
uint mx_bjfinal(uint a, uint b, uint c)
{
    c ^= b; c -= mx_rotl32(b,14);
    a ^= c; a -= mx_rotl32(c,11);
    b ^= a; b -= mx_rotl32(a,25);
    c ^= b; c -= mx_rotl32(b,16);
    a ^= c; a -= mx_rotl32(c,4);
    b ^= a; b -= mx_rotl32(a,14);
    c ^= b; c -= mx_rotl32(b,24);
    return c;
}

// Convert a 32 bit integer into a floating point number in [0,1]
float mx_bits_to_01(uint bits)
{
    return float(bits) / float(uint(0xffffffff));
}

float mx_fade(float t)
{
   return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

uint mx_hash_int(int x)
{
    uint len = 1u;
    uint seed = uint(0xdeadbeef) + (len << 2u) + 13u;
    return mx_bjfinal(seed+uint(x), seed, seed);
}

uint mx_hash_int(int x, int y)
{
    uint len = 2u;
    uint a, b, c;
    a = b = c = uint(0xdeadbeef) + (len << 2u) + 13u;
    a += uint(x);
    b += uint(y);
    return mx_bjfinal(a, b, c);
}

uint mx_hash_int(int x, int y, int z)
{
    uint len = 3u;
    uint a, b, c;
    a = b = c = uint(0xdeadbeef) + (len << 2u) + 13u;
    a += uint(x);
    b += uint(y);
    c += uint(z);
    return mx_bjfinal(a, b, c);
}

uint mx_hash_int(int x, int y, int z, int xx)
{
    uint len = 4u;
    uint a, b, c;
    a = b = c = uint(0xdeadbeef) + (len << 2u) + 13u;
    a += uint(x);
    b += uint(y);
    c += uint(z);
    mx_bjmix(a, b, c);
    a += uint(xx);
    return mx_bjfinal(a, b, c);
}

uint mx_hash_int(int x, int y, int z, int xx, int yy)
{
    uint len = 5u;
    uint a, b, c;
    a = b = c = uint(0xdeadbeef) + (len << 2u) + 13u;
    a += uint(x);
    b += uint(y);
    c += uint(z);
    mx_bjmix(a, b, c);
    a += uint(xx);
    b += uint(yy);
    return mx_bjfinal(a, b, c);
}

uvec3 mx_hash_vec3(int x, int y)
{
    uint h = mx_hash_int(x, y);
    // we only need the low-order bits to be random, so split out
    // the 32 bit result into 3 parts for each channel
    uvec3 result;
    result.x = (h      ) & 0xFFu;
    result.y = (h >> 8 ) & 0xFFu;
    result.z = (h >> 16) & 0xFFu;
    return result;
}

uvec3 mx_hash_vec3(int x, int y, int z)
{
    uint h = mx_hash_int(x, y, z);
    // we only need the low-order bits to be random, so split out
    // the 32 bit result into 3 parts for each channel
    uvec3 result;
    result.x = (h      ) & 0xFFu;
    result.y = (h >> 8 ) & 0xFFu;
    result.z = (h >> 16) & 0xFFu;
    return result;
}

float mx_perlin_noise_float(vec2 p)
{
    int X, Y;
    float fx = mx_floorfrac(p.x, X);
    float fy = mx_floorfrac(p.y, Y);
    float u = mx_fade(fx);
    float v = mx_fade(fy);
    float result = mx_bilerp(
        mx_gradient_float(mx_hash_int(X  , Y  ), fx    , fy     ),
        mx_gradient_float(mx_hash_int(X+1, Y  ), fx-1.0, fy     ),
        mx_gradient_float(mx_hash_int(X  , Y+1), fx    , fy-1.0),
        mx_gradient_float(mx_hash_int(X+1, Y+1), fx-1.0, fy-1.0),
        u, v);
    return mx_gradient_scale2d(result);
}

float mx_perlin_noise_float(vec3 p)
{
    int X, Y, Z;
    float fx = mx_floorfrac(p.x, X);
    float fy = mx_floorfrac(p.y, Y);
    float fz = mx_floorfrac(p.z, Z);
    float u = mx_fade(fx);
    float v = mx_fade(fy);
    float w = mx_fade(fz);
    float result = mx_trilerp(
        mx_gradient_float(mx_hash_int(X  , Y  , Z  ), fx    , fy    , fz     ),
        mx_gradient_float(mx_hash_int(X+1, Y  , Z  ), fx-1.0, fy    , fz     ),
        mx_gradient_float(mx_hash_int(X  , Y+1, Z  ), fx    , fy-1.0, fz     ),
        mx_gradient_float(mx_hash_int(X+1, Y+1, Z  ), fx-1.0, fy-1.0, fz     ),
        mx_gradient_float(mx_hash_int(X  , Y  , Z+1), fx    , fy    , fz-1.0),
        mx_gradient_float(mx_hash_int(X+1, Y  , Z+1), fx-1.0, fy    , fz-1.0),
        mx_gradient_float(mx_hash_int(X  , Y+1, Z+1), fx    , fy-1.0, fz-1.0),
        mx_gradient_float(mx_hash_int(X+1, Y+1, Z+1), fx-1.0, fy-1.0, fz-1.0),
        u, v, w);
    return mx_gradient_scale3d(result);
}

vec3 mx_perlin_noise_vec3(vec2 p)
{
    int X, Y;
    float fx = mx_floorfrac(p.x, X);
    float fy = mx_floorfrac(p.y, Y);
    float u = mx_fade(fx);
    float v = mx_fade(fy);
    vec3 result = mx_bilerp(
        mx_gradient_vec3(mx_hash_vec3(X  , Y  ), fx    , fy     ),
        mx_gradient_vec3(mx_hash_vec3(X+1, Y  ), fx-1.0, fy     ),
        mx_gradient_vec3(mx_hash_vec3(X  , Y+1), fx    , fy-1.0),
        mx_gradient_vec3(mx_hash_vec3(X+1, Y+1), fx-1.0, fy-1.0),
        u, v);
    return mx_gradient_scale2d(result);
}

vec3 mx_perlin_noise_vec3(vec3 p)
{
    int X, Y, Z;
    float fx = mx_floorfrac(p.x, X);
    float fy = mx_floorfrac(p.y, Y);
    float fz = mx_floorfrac(p.z, Z);
    float u = mx_fade(fx);
    float v = mx_fade(fy);
    float w = mx_fade(fz);
    vec3 result = mx_trilerp(
        mx_gradient_vec3(mx_hash_vec3(X  , Y  , Z  ), fx    , fy    , fz     ),
        mx_gradient_vec3(mx_hash_vec3(X+1, Y  , Z  ), fx-1.0, fy    , fz     ),
        mx_gradient_vec3(mx_hash_vec3(X  , Y+1, Z  ), fx    , fy-1.0, fz     ),
        mx_gradient_vec3(mx_hash_vec3(X+1, Y+1, Z  ), fx-1.0, fy-1.0, fz     ),
        mx_gradient_vec3(mx_hash_vec3(X  , Y  , Z+1), fx    , fy    , fz-1.0),
        mx_gradient_vec3(mx_hash_vec3(X+1, Y  , Z+1), fx-1.0, fy    , fz-1.0),
        mx_gradient_vec3(mx_hash_vec3(X  , Y+1, Z+1), fx    , fy-1.0, fz-1.0),
        mx_gradient_vec3(mx_hash_vec3(X+1, Y+1, Z+1), fx-1.0, fy-1.0, fz-1.0),
        u, v, w);
    return mx_gradient_scale3d(result);
}

float mx_cell_noise_float(float p)
{
    int ix = mx_floor(p);
    return mx_bits_to_01(mx_hash_int(ix));
}

float mx_cell_noise_float(vec2 p)
{
    int ix = mx_floor(p.x);
    int iy = mx_floor(p.y);
    return mx_bits_to_01(mx_hash_int(ix, iy));
}

float mx_cell_noise_float(vec3 p)
{
    int ix = mx_floor(p.x);
    int iy = mx_floor(p.y);
    int iz = mx_floor(p.z);
    return mx_bits_to_01(mx_hash_int(ix, iy, iz));
}

float mx_cell_noise_float(vec4 p)
{
    int ix = mx_floor(p.x);
    int iy = mx_floor(p.y);
    int iz = mx_floor(p.z);
    int iw = mx_floor(p.w);
    return mx_bits_to_01(mx_hash_int(ix, iy, iz, iw));
}

vec3 mx_cell_noise_vec3(float p)
{
    int ix = mx_floor(p);
    return vec3(
            mx_bits_to_01(mx_hash_int(ix, 0)),
            mx_bits_to_01(mx_hash_int(ix, 1)),
            mx_bits_to_01(mx_hash_int(ix, 2))
    );
}

vec3 mx_cell_noise_vec3(vec2 p)
{
    int ix = mx_floor(p.x);
    int iy = mx_floor(p.y);
    return vec3(
            mx_bits_to_01(mx_hash_int(ix, iy, 0)),
            mx_bits_to_01(mx_hash_int(ix, iy, 1)),
            mx_bits_to_01(mx_hash_int(ix, iy, 2))
    );
}

vec3 mx_cell_noise_vec3(vec3 p)
{
    int ix = mx_floor(p.x);
    int iy = mx_floor(p.y);
    int iz = mx_floor(p.z);
    return vec3(
            mx_bits_to_01(mx_hash_int(ix, iy, iz, 0)),
            mx_bits_to_01(mx_hash_int(ix, iy, iz, 1)),
            mx_bits_to_01(mx_hash_int(ix, iy, iz, 2))
    );
}

vec3 mx_cell_noise_vec3(vec4 p)
{
    int ix = mx_floor(p.x);
    int iy = mx_floor(p.y);
    int iz = mx_floor(p.z);
    int iw = mx_floor(p.w);
    return vec3(
            mx_bits_to_01(mx_hash_int(ix, iy, iz, iw, 0)),
            mx_bits_to_01(mx_hash_int(ix, iy, iz, iw, 1)),
            mx_bits_to_01(mx_hash_int(ix, iy, iz, iw, 2))
    );
}

float mx_fractal_noise_float(vec3 p, int octaves, float lacunarity, float diminish)
{
    float result = 0.0;
    float amplitude = 1.0;
    for (int i = 0;  i < octaves; ++i)
    {
        result += amplitude * mx_perlin_noise_float(p);
        amplitude *= diminish;
        p *= lacunarity;
    }
    return result;
}

vec3 mx_fractal_noise_vec3(vec3 p, int octaves, float lacunarity, float diminish)
{
    vec3 result = vec3(0.0);
    float amplitude = 1.0;
    for (int i = 0;  i < octaves; ++i)
    {
        result += amplitude * mx_perlin_noise_vec3(p);
        amplitude *= diminish;
        p *= lacunarity;
    }
    return result;
}

vec2 mx_fractal_noise_vec2(vec3 p, int octaves, float lacunarity, float diminish)
{
    return vec2(mx_fractal_noise_float(p, octaves, lacunarity, diminish),
                mx_fractal_noise_float(p+vec3(19, 193, 17), octaves, lacunarity, diminish));
}

vec4 mx_fractal_noise_vec4(vec3 p, int octaves, float lacunarity, float diminish)
{
    vec3  c = mx_fractal_noise_vec3(p, octaves, lacunarity, diminish);
    float f = mx_fractal_noise_float(p+vec3(19, 193, 17), octaves, lacunarity, diminish);
    return vec4(c, f);
}

vec2 mx_worley_cell_position(int x, int y, int xoff, int yoff, float jitter)
{
    vec3  tmp = mx_cell_noise_vec3(vec2(x+xoff, y+yoff));
    vec2  off = vec2(tmp.x, tmp.y);

    off -= 0.5f;
    off *= jitter;
    off += 0.5f;
    
    return vec2(float(x), float(y)) + off;
}

vec3 mx_worley_cell_position(int x, int y, int z, int xoff, int yoff, int zoff, float jitter)
{
    vec3  off = mx_cell_noise_vec3(vec3(x+xoff, y+yoff, z+zoff));

    off -= 0.5f;
    off *= jitter;
    off += 0.5f;
    
    return vec3(float(x), float(y), float(z)) + off;
}

float mx_worley_distance(vec2 p, int x, int y, int xoff, int yoff, float jitter, int metric)
{
    vec2 cellpos = mx_worley_cell_position(x, y, xoff, yoff, jitter);
    vec2 diff = cellpos - p;
    if (metric == 2)
        return abs(diff.x) + abs(diff.y);       // Manhattan distance
    if (metric == 3)
        return max(abs(diff.x), abs(diff.y));   // Chebyshev distance
    // Either Euclidean or Distance^2
    return dot(diff, diff);
}

float mx_worley_distance(vec3 p, int x, int y, int z, int xoff, int yoff, int zoff, float jitter, int metric)
{
    vec3 cellpos = mx_worley_cell_position(x, y, z, xoff, yoff, zoff, jitter);
    vec3 diff = cellpos - p;
    if (metric == 2)
        return abs(diff.x) + abs(diff.y) + abs(diff.z); // Manhattan distance
    if (metric == 3)
        return max(max(abs(diff.x), abs(diff.y)), abs(diff.z)); // Chebyshev distance
    // Either Euclidean or Distance^2
    return dot(diff, diff);
}

float mx_worley_noise_float(vec2 p, float jitter, int style, int metric)
{
    int X, Y;
    float dist;
    vec2 localpos = vec2(mx_floorfrac(p.x, X), mx_floorfrac(p.y, Y));
    float sqdist = 1e6f;        // Some big number for jitter > 1 (not all GPUs may be IEEE)
    vec2 minpos = vec2(0,0);
    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            float dist = mx_worley_distance(localpos, x, y, X, Y, jitter, metric);
            vec2 cellpos = mx_worley_cell_position(x, y, X, Y, jitter) - localpos;
            if(dist < sqdist)
            {
                sqdist = dist;
                minpos = cellpos;
            }
        }
    }
    if (style == 1)
        return mx_cell_noise_float(minpos + p);
    else
    {
        if (metric == 0)
            sqdist = sqrt(sqdist);
        return sqdist;
    }
}

vec2 mx_worley_noise_vec2(vec2 p, float jitter, int style, int metric)
{
    int X, Y;
    vec2 localpos = vec2(mx_floorfrac(p.x, X), mx_floorfrac(p.y, Y));
    vec2 sqdist = vec2(1e6f, 1e6f);
    vec2 minpos = vec2(0,0);
    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            float dist = mx_worley_distance(localpos, x, y, X, Y, jitter, metric);
            vec2 cellpos = mx_worley_cell_position(x, y, X, Y, jitter) - localpos;
            if (dist < sqdist.x)
            {
                sqdist.y = sqdist.x;
                sqdist.x = dist;
                minpos = cellpos;
            }
            else if (dist < sqdist.y)
            {
                sqdist.y = dist;
            }
        }
    }
    if (style == 1)
    {
        vec3 tmp = mx_cell_noise_vec3(minpos + p);
        return vec2(tmp.x,tmp.y);
    }
    else
    {
        if (metric == 0)
            sqdist = sqrt(sqdist);
        return sqdist;
    }
}

vec3 mx_worley_noise_vec3(vec2 p, float jitter, int style, int metric)
{
    int X, Y;
    vec2 localpos = vec2(mx_floorfrac(p.x, X), mx_floorfrac(p.y, Y));
    vec3 sqdist = vec3(1e6f, 1e6f, 1e6f);
    vec2 minpos = vec2(0,0);
    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            float dist = mx_worley_distance(localpos, x, y, X, Y, jitter, metric);
            vec2 cellpos = mx_worley_cell_position(x, y, X, Y, jitter) - localpos;
            if (dist < sqdist.x)
            {
                sqdist.z = sqdist.y;
                sqdist.y = sqdist.x;
                sqdist.x = dist;
                minpos = cellpos;
            }
            else if (dist < sqdist.y)
            {
                sqdist.z = sqdist.y;
                sqdist.y = dist;
            }
            else if (dist < sqdist.z)
            {
                sqdist.z = dist;
            }
        }
    }
    if (style == 1)
        return mx_cell_noise_vec3(minpos + p);
    else
    {
        if (metric == 0)
            sqdist = sqrt(sqdist);
        return sqdist;
    }
}

float mx_worley_noise_float(vec3 p, float jitter, int style, int metric)
{
    int X, Y, Z;
    vec3 localpos = vec3(mx_floorfrac(p.x, X), mx_floorfrac(p.y, Y), mx_floorfrac(p.z, Z));
    float sqdist = 1e6f;
    vec3 minpos = vec3(0,0,0);
    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            for (int z = -1; z <= 1; ++z)
            {
                float dist = mx_worley_distance(localpos, x, y, z, X, Y, Z, jitter, metric);
                vec3 cellpos = mx_worley_cell_position(x, y, z, X, Y, Z, jitter) - localpos;
                if(dist < sqdist)
                {
                    sqdist = dist;
                    minpos = cellpos;
                }
            }
        }
    }
    if (style == 1)
        return mx_cell_noise_float(minpos + p);
    else
    {
        if (metric == 0)
            sqdist = sqrt(sqdist);
        return sqdist;
    }
}

vec2 mx_worley_noise_vec2(vec3 p, float jitter, int style, int metric)
{
    int X, Y, Z;
    vec3 localpos = vec3(mx_floorfrac(p.x, X), mx_floorfrac(p.y, Y), mx_floorfrac(p.z, Z));
    vec2 sqdist = vec2(1e6f, 1e6f);
    vec3 minpos = vec3(0,0,0);
    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            for (int z = -1; z <= 1; ++z)
            {
                float dist = mx_worley_distance(localpos, x, y, z, X, Y, Z, jitter, metric);
                vec3 cellpos = mx_worley_cell_position(x, y, z, X, Y, Z, jitter) - localpos;
                if (dist < sqdist.x)
                {
                    sqdist.y = sqdist.x;
                    sqdist.x = dist;
                    minpos = cellpos;
                }
                else if (dist < sqdist.y)
                {
                    sqdist.y = dist;
                }
            }
        }
    }
    if (style == 1)
    {
        vec3 tmp = mx_cell_noise_vec3(minpos + p);
        return vec2(tmp.x,tmp.y);
    }
    else
    {
        if (metric == 0)
            sqdist = sqrt(sqdist);
        return sqdist;
    }
}

vec3 mx_worley_noise_vec3(vec3 p, float jitter, int style, int metric)
{
    int X, Y, Z;
    vec3 localpos = vec3(mx_floorfrac(p.x, X), mx_floorfrac(p.y, Y), mx_floorfrac(p.z, Z));
    vec3 sqdist = vec3(1e6f, 1e6f, 1e6f);
    vec3 minpos = vec3(0,0,0);
    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            for (int z = -1; z <= 1; ++z)
            {
                float dist = mx_worley_distance(localpos, x, y, z, X, Y, Z, jitter, metric);
                vec3 cellpos = mx_worley_cell_position(x, y, z, X, Y, Z, jitter) - localpos;
                if (dist < sqdist.x)
                {
                    sqdist.z = sqdist.y;
                    sqdist.y = sqdist.x;
                    sqdist.x = dist;
                    minpos = cellpos;
                }
                else if (dist < sqdist.y)
                {
                    sqdist.z = sqdist.y;
                    sqdist.y = dist;
                }
                else if (dist < sqdist.z)
                {
                    sqdist.z = dist;
                }
            }
        }
    }
    if (style == 1)
        return mx_cell_noise_vec3(minpos + p);
    else
    {
        if (metric == 0)
            sqdist = sqrt(sqdist);
        return sqdist;
    }
}

void mx_cellnoise2d_float(vec2 texcoord, out float result)
{
    result = mx_cell_noise_float(texcoord);
}

// Restrict to 7x7 kernel size for performance reasons
#define MX_MAX_SAMPLE_COUNT 49
// Size of all weights for all levels (including level 1)
#define MX_WEIGHT_ARRAY_SIZE 84

//
// Function to compute the sample size relative to a texture coordinate
//
vec2 mx_compute_sample_size_uv(vec2 uv, float filterSize, float filterOffset)
{
   vec2 derivUVx = dFdx(uv) * 0.5f;
   vec2 derivUVy = dFdy(uv) * 0.5f;
   float derivX = abs(derivUVx.x) + abs(derivUVy.x);
   float derivY = abs(derivUVx.y) + abs(derivUVy.y);
   float sampleSizeU = 2.0f * filterSize * derivX + filterOffset;
   if (sampleSizeU < 1.0E-05f)
       sampleSizeU = 1.0E-05f;
   float sampleSizeV = 2.0f * filterSize * derivY + filterOffset;
   if (sampleSizeV < 1.0E-05f)
       sampleSizeV = 1.0E-05f;
   return vec2(sampleSizeU, sampleSizeV);
}

//
// Compute a normal mapped to 0..1 space based on a set of input
// samples using a Sobel filter.
//
vec3 mx_normal_from_samples_sobel(float S[9], float _scale)
{
    float nx = S[0] - S[2] + (2.0*S[3]) - (2.0*S[5]) + S[6] - S[8];
    float ny = S[0] + (2.0*S[1]) + S[2] - S[6] - (2.0*S[7]) - S[8];
    float nz = max(_scale, M_FLOAT_EPS) * sqrt(max(1.0 - nx * nx - ny * ny, M_FLOAT_EPS));
    vec3 norm = normalize(vec3(nx, ny, nz));
    return (norm + 1.0) * 0.5;
}

//
// Apply filter for float samples S, using weights W.
// sampleCount should be a square of a odd number in the range { 1, 3, 5, 7 }
//
float mx_convolution_float(float S[MX_MAX_SAMPLE_COUNT], float W[MX_WEIGHT_ARRAY_SIZE], int offset, int sampleCount)
{
    float result = 0.0;
    for (int i = 0;  i < sampleCount; i++)
    {
        result += S[i]*W[i+offset];
    }
    return result;
}

//
// Apply filter for vec2 samples S, using weights W.
// sampleCount should be a square of a odd number in the range { 1, 3, 5, 7 }
//
vec2 mx_convolution_vec2(vec2 S[MX_MAX_SAMPLE_COUNT], float W[MX_WEIGHT_ARRAY_SIZE], int offset, int sampleCount)
{
    vec2 result = vec2(0.0);
    for (int i=0;  i<sampleCount; i++)
    {
        result += S[i]*W[i+offset];
    }
    return result;
}

//
// Apply filter for vec3 samples S, using weights W.
// sampleCount should be a square of a odd number in the range { 1, 3, 5, 7 }
//
vec3 mx_convolution_vec3(vec3 S[MX_MAX_SAMPLE_COUNT], float W[MX_WEIGHT_ARRAY_SIZE], int offset, int sampleCount)
{
    vec3 result = vec3(0.0);
    for (int i=0;  i<sampleCount; i++)
    {
        result += S[i]*W[i+offset];
    }
    return result;
}

//
// Apply filter for vec4 samples S, using weights W.
// sampleCount should be a square of a odd number { 1, 3, 5, 7 }
//
vec4 mx_convolution_vec4(vec4 S[MX_MAX_SAMPLE_COUNT], float W[MX_WEIGHT_ARRAY_SIZE], int offset, int sampleCount)
{
    vec4 result = vec4(0.0);
    for (int i=0;  i<sampleCount; i++)
    {
        result += S[i]*W[i+offset];
    }
    return result;
}

void main()
{
    vec2 texcoord1_out = vd.texcoord_0.xy;
    vec2 multiply1_out = texcoord1_out * multiply1_in2;
    float cellnoise2d1_out = 0.0;
    mx_cellnoise2d_float(multiply1_out, cellnoise2d1_out);
    vec2 blur_cellnoise_out_sample_size = mx_compute_sample_size_uv(multiply1_out,1.000000,0.000000);
    float cellnoise2d1_out_blur_cellnoise_out0 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(-2.000000,-2.000000), cellnoise2d1_out_blur_cellnoise_out0);
    float cellnoise2d1_out_blur_cellnoise_out1 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(-1.000000,-2.000000), cellnoise2d1_out_blur_cellnoise_out1);
    float cellnoise2d1_out_blur_cellnoise_out2 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(0.000000,-2.000000), cellnoise2d1_out_blur_cellnoise_out2);
    float cellnoise2d1_out_blur_cellnoise_out3 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(1.000000,-2.000000), cellnoise2d1_out_blur_cellnoise_out3);
    float cellnoise2d1_out_blur_cellnoise_out4 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(2.000000,-2.000000), cellnoise2d1_out_blur_cellnoise_out4);
    float cellnoise2d1_out_blur_cellnoise_out5 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(-2.000000,-1.000000), cellnoise2d1_out_blur_cellnoise_out5);
    float cellnoise2d1_out_blur_cellnoise_out6 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(-1.000000,-1.000000), cellnoise2d1_out_blur_cellnoise_out6);
    float cellnoise2d1_out_blur_cellnoise_out7 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(0.000000,-1.000000), cellnoise2d1_out_blur_cellnoise_out7);
    float cellnoise2d1_out_blur_cellnoise_out8 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(1.000000,-1.000000), cellnoise2d1_out_blur_cellnoise_out8);
    float cellnoise2d1_out_blur_cellnoise_out9 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(2.000000,-1.000000), cellnoise2d1_out_blur_cellnoise_out9);
    float cellnoise2d1_out_blur_cellnoise_out10 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(-2.000000,0.000000), cellnoise2d1_out_blur_cellnoise_out10);
    float cellnoise2d1_out_blur_cellnoise_out11 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(-1.000000,0.000000), cellnoise2d1_out_blur_cellnoise_out11);
    float cellnoise2d1_out_blur_cellnoise_out12 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(0.000000,0.000000), cellnoise2d1_out_blur_cellnoise_out12);
    float cellnoise2d1_out_blur_cellnoise_out13 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(1.000000,0.000000), cellnoise2d1_out_blur_cellnoise_out13);
    float cellnoise2d1_out_blur_cellnoise_out14 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(2.000000,0.000000), cellnoise2d1_out_blur_cellnoise_out14);
    float cellnoise2d1_out_blur_cellnoise_out15 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(-2.000000,1.000000), cellnoise2d1_out_blur_cellnoise_out15);
    float cellnoise2d1_out_blur_cellnoise_out16 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(-1.000000,1.000000), cellnoise2d1_out_blur_cellnoise_out16);
    float cellnoise2d1_out_blur_cellnoise_out17 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(0.000000,1.000000), cellnoise2d1_out_blur_cellnoise_out17);
    float cellnoise2d1_out_blur_cellnoise_out18 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(1.000000,1.000000), cellnoise2d1_out_blur_cellnoise_out18);
    float cellnoise2d1_out_blur_cellnoise_out19 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(2.000000,1.000000), cellnoise2d1_out_blur_cellnoise_out19);
    float cellnoise2d1_out_blur_cellnoise_out20 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(-2.000000,2.000000), cellnoise2d1_out_blur_cellnoise_out20);
    float cellnoise2d1_out_blur_cellnoise_out21 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(-1.000000,2.000000), cellnoise2d1_out_blur_cellnoise_out21);
    float cellnoise2d1_out_blur_cellnoise_out22 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(0.000000,2.000000), cellnoise2d1_out_blur_cellnoise_out22);
    float cellnoise2d1_out_blur_cellnoise_out23 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(1.000000,2.000000), cellnoise2d1_out_blur_cellnoise_out23);
    float cellnoise2d1_out_blur_cellnoise_out24 = 0.0;
    mx_cellnoise2d_float(multiply1_out + blur_cellnoise_out_sample_size * vec2(2.000000,2.000000), cellnoise2d1_out_blur_cellnoise_out24);
    float blur_cellnoise_out_samples[MX_MAX_SAMPLE_COUNT];
    blur_cellnoise_out_samples[0] = cellnoise2d1_out_blur_cellnoise_out0;
    blur_cellnoise_out_samples[1] = cellnoise2d1_out_blur_cellnoise_out1;
    blur_cellnoise_out_samples[2] = cellnoise2d1_out_blur_cellnoise_out2;
    blur_cellnoise_out_samples[3] = cellnoise2d1_out_blur_cellnoise_out3;
    blur_cellnoise_out_samples[4] = cellnoise2d1_out_blur_cellnoise_out4;
    blur_cellnoise_out_samples[5] = cellnoise2d1_out_blur_cellnoise_out5;
    blur_cellnoise_out_samples[6] = cellnoise2d1_out_blur_cellnoise_out6;
    blur_cellnoise_out_samples[7] = cellnoise2d1_out_blur_cellnoise_out7;
    blur_cellnoise_out_samples[8] = cellnoise2d1_out_blur_cellnoise_out8;
    blur_cellnoise_out_samples[9] = cellnoise2d1_out_blur_cellnoise_out9;
    blur_cellnoise_out_samples[10] = cellnoise2d1_out_blur_cellnoise_out10;
    blur_cellnoise_out_samples[11] = cellnoise2d1_out_blur_cellnoise_out11;
    blur_cellnoise_out_samples[12] = cellnoise2d1_out_blur_cellnoise_out12;
    blur_cellnoise_out_samples[13] = cellnoise2d1_out_blur_cellnoise_out13;
    blur_cellnoise_out_samples[14] = cellnoise2d1_out_blur_cellnoise_out14;
    blur_cellnoise_out_samples[15] = cellnoise2d1_out_blur_cellnoise_out15;
    blur_cellnoise_out_samples[16] = cellnoise2d1_out_blur_cellnoise_out16;
    blur_cellnoise_out_samples[17] = cellnoise2d1_out_blur_cellnoise_out17;
    blur_cellnoise_out_samples[18] = cellnoise2d1_out_blur_cellnoise_out18;
    blur_cellnoise_out_samples[19] = cellnoise2d1_out_blur_cellnoise_out19;
    blur_cellnoise_out_samples[20] = cellnoise2d1_out_blur_cellnoise_out20;
    blur_cellnoise_out_samples[21] = cellnoise2d1_out_blur_cellnoise_out21;
    blur_cellnoise_out_samples[22] = cellnoise2d1_out_blur_cellnoise_out22;
    blur_cellnoise_out_samples[23] = cellnoise2d1_out_blur_cellnoise_out23;
    blur_cellnoise_out_samples[24] = cellnoise2d1_out_blur_cellnoise_out24;
    float blur_cellnoise_out;
    if (blur_cellnoise_filtertype == 1)
    {
        blur_cellnoise_out = mx_convolution_float(blur_cellnoise_out_samples, c_gaussian_filter_weights, 10, 25);
    }
    else
    {
        blur_cellnoise_out = mx_convolution_float(blur_cellnoise_out_samples, c_box_filter_weights, 10, 25);
    }
    out1 = vec4(blur_cellnoise_out, blur_cellnoise_out, blur_cellnoise_out, 1.0);
}

