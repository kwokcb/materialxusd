#version 400


struct BSDF { vec3 response; vec3 throughput; };
#define EDF vec3
struct surfaceshader { vec3 color; vec3 transparency; };
struct volumeshader { vec3 color; vec3 transparency; };
struct displacementshader { vec3 offset; float scale; };
struct lightshader { vec3 intensity; vec3 direction; };
#define material surfaceshader

// Uniform block: PublicUniforms
uniform sampler2D file;
uniform int geomprop_UV0_index = 0;
uniform float tiledimage_default = 0.000000;
uniform vec2 tiledimage_uvtiling = vec2(10.000000, 10.000000);
uniform vec2 tiledimage_uvoffset = vec2(0.000000, 0.000000);
uniform vec2 tiledimage_realworldimagesize = vec2(1.000000, 1.000000);
uniform vec2 tiledimage_realworldtilesize = vec2(1.000000, 1.000000);
uniform int tiledimage_filtertype = 1;
uniform int tiledimage_framerange = 0;
uniform int tiledimage_frameoffset = 0;
uniform int tiledimage_frameendaction = 0;
uniform float heighttonormal_scale = 0.200000;

in VertexData
{
    vec2 texcoord_0;
} vd;

// Pixel shader outputs
out vec4 vector3_out;

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

vec2 mx_transform_uv(vec2 uv, vec2 uv_scale, vec2 uv_offset)
{
    uv = uv * uv_scale + uv_offset;
    return uv;
}

void mx_image_float(sampler2D tex_sampler, int layer, float defaultval, vec2 texcoord, int uaddressmode, int vaddressmode, int filtertype, int framerange, int frameoffset, int frameendaction, vec2 uv_scale, vec2 uv_offset, out float result)
{
    vec2 uv = mx_transform_uv(texcoord, uv_scale, uv_offset);
    result = texture(tex_sampler, uv).r;
}

void NG_tiledimage_float(sampler2D file, float default1, vec2 texcoord1, vec2 uvtiling, vec2 uvoffset, vec2 realworldimagesize, vec2 realworldtilesize, int filtertype, int framerange, int frameoffset, int frameendaction, out float out1)
{
    vec2 N_mult_float_out = texcoord1 * uvtiling;
    vec2 N_sub_float_out = N_mult_float_out - uvoffset;
    vec2 N_divtilesize_float_out = N_sub_float_out / realworldimagesize;
    vec2 N_multtilesize_float_out = N_divtilesize_float_out * realworldtilesize;
    float N_img_float_out = 0.0;
    mx_image_float(file, 0, default1, N_multtilesize_float_out, 2, 2, filtertype, framerange, frameoffset, frameendaction, vec2(1.000000, 1.000000), vec2(0.000000, 0.000000), N_img_float_out);
    out1 = N_img_float_out;
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
    vec2 geomprop_UV0_out1 = vd.texcoord_0.xy;
    float tiledimage_out = 0.0;
    NG_tiledimage_float(file, tiledimage_default, geomprop_UV0_out1, tiledimage_uvtiling, tiledimage_uvoffset, tiledimage_realworldimagesize, tiledimage_realworldtilesize, tiledimage_filtertype, tiledimage_framerange, tiledimage_frameoffset, tiledimage_frameendaction, tiledimage_out);
    vec2 heighttonormal_out_sample_size = mx_compute_sample_size_uv(geomprop_UV0_out1,1.000000,0.000000);
    float tiledimage_out_heighttonormal_out0 = 0.0;
    NG_tiledimage_float(file, tiledimage_default, geomprop_UV0_out1 + heighttonormal_out_sample_size * vec2(-1.000000,-1.000000), tiledimage_uvtiling, tiledimage_uvoffset, tiledimage_realworldimagesize, tiledimage_realworldtilesize, tiledimage_filtertype, tiledimage_framerange, tiledimage_frameoffset, tiledimage_frameendaction, tiledimage_out_heighttonormal_out0);
    float tiledimage_out_heighttonormal_out1 = 0.0;
    NG_tiledimage_float(file, tiledimage_default, geomprop_UV0_out1 + heighttonormal_out_sample_size * vec2(0.000000,-1.000000), tiledimage_uvtiling, tiledimage_uvoffset, tiledimage_realworldimagesize, tiledimage_realworldtilesize, tiledimage_filtertype, tiledimage_framerange, tiledimage_frameoffset, tiledimage_frameendaction, tiledimage_out_heighttonormal_out1);
    float tiledimage_out_heighttonormal_out2 = 0.0;
    NG_tiledimage_float(file, tiledimage_default, geomprop_UV0_out1 + heighttonormal_out_sample_size * vec2(1.000000,-1.000000), tiledimage_uvtiling, tiledimage_uvoffset, tiledimage_realworldimagesize, tiledimage_realworldtilesize, tiledimage_filtertype, tiledimage_framerange, tiledimage_frameoffset, tiledimage_frameendaction, tiledimage_out_heighttonormal_out2);
    float tiledimage_out_heighttonormal_out3 = 0.0;
    NG_tiledimage_float(file, tiledimage_default, geomprop_UV0_out1 + heighttonormal_out_sample_size * vec2(-1.000000,0.000000), tiledimage_uvtiling, tiledimage_uvoffset, tiledimage_realworldimagesize, tiledimage_realworldtilesize, tiledimage_filtertype, tiledimage_framerange, tiledimage_frameoffset, tiledimage_frameendaction, tiledimage_out_heighttonormal_out3);
    float tiledimage_out_heighttonormal_out4 = 0.0;
    NG_tiledimage_float(file, tiledimage_default, geomprop_UV0_out1 + heighttonormal_out_sample_size * vec2(0.000000,0.000000), tiledimage_uvtiling, tiledimage_uvoffset, tiledimage_realworldimagesize, tiledimage_realworldtilesize, tiledimage_filtertype, tiledimage_framerange, tiledimage_frameoffset, tiledimage_frameendaction, tiledimage_out_heighttonormal_out4);
    float tiledimage_out_heighttonormal_out5 = 0.0;
    NG_tiledimage_float(file, tiledimage_default, geomprop_UV0_out1 + heighttonormal_out_sample_size * vec2(1.000000,0.000000), tiledimage_uvtiling, tiledimage_uvoffset, tiledimage_realworldimagesize, tiledimage_realworldtilesize, tiledimage_filtertype, tiledimage_framerange, tiledimage_frameoffset, tiledimage_frameendaction, tiledimage_out_heighttonormal_out5);
    float tiledimage_out_heighttonormal_out6 = 0.0;
    NG_tiledimage_float(file, tiledimage_default, geomprop_UV0_out1 + heighttonormal_out_sample_size * vec2(-1.000000,1.000000), tiledimage_uvtiling, tiledimage_uvoffset, tiledimage_realworldimagesize, tiledimage_realworldtilesize, tiledimage_filtertype, tiledimage_framerange, tiledimage_frameoffset, tiledimage_frameendaction, tiledimage_out_heighttonormal_out6);
    float tiledimage_out_heighttonormal_out7 = 0.0;
    NG_tiledimage_float(file, tiledimage_default, geomprop_UV0_out1 + heighttonormal_out_sample_size * vec2(0.000000,1.000000), tiledimage_uvtiling, tiledimage_uvoffset, tiledimage_realworldimagesize, tiledimage_realworldtilesize, tiledimage_filtertype, tiledimage_framerange, tiledimage_frameoffset, tiledimage_frameendaction, tiledimage_out_heighttonormal_out7);
    float tiledimage_out_heighttonormal_out8 = 0.0;
    NG_tiledimage_float(file, tiledimage_default, geomprop_UV0_out1 + heighttonormal_out_sample_size * vec2(1.000000,1.000000), tiledimage_uvtiling, tiledimage_uvoffset, tiledimage_realworldimagesize, tiledimage_realworldtilesize, tiledimage_filtertype, tiledimage_framerange, tiledimage_frameoffset, tiledimage_frameendaction, tiledimage_out_heighttonormal_out8);
    float heighttonormal_out_samples[9];
    heighttonormal_out_samples[0] = tiledimage_out_heighttonormal_out0;
    heighttonormal_out_samples[1] = tiledimage_out_heighttonormal_out1;
    heighttonormal_out_samples[2] = tiledimage_out_heighttonormal_out2;
    heighttonormal_out_samples[3] = tiledimage_out_heighttonormal_out3;
    heighttonormal_out_samples[4] = tiledimage_out_heighttonormal_out4;
    heighttonormal_out_samples[5] = tiledimage_out_heighttonormal_out5;
    heighttonormal_out_samples[6] = tiledimage_out_heighttonormal_out6;
    heighttonormal_out_samples[7] = tiledimage_out_heighttonormal_out7;
    heighttonormal_out_samples[8] = tiledimage_out_heighttonormal_out8;
    vec3 heighttonormal_out = mx_normal_from_samples_sobel(heighttonormal_out_samples, heighttonormal_scale);
    vector3_out = vec4(heighttonormal_out, 1.0);
}

