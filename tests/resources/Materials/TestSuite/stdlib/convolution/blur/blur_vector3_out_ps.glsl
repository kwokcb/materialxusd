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
uniform int geomprop_UV0_index = 0;
uniform sampler2D tiledimage1_file;
uniform vec3 tiledimage1_default = vec3(0.000000, 0.000000, 0.000000);
uniform vec2 tiledimage1_uvtiling = vec2(1.000000, 1.000000);
uniform vec2 tiledimage1_uvoffset = vec2(0.000000, 0.000000);
uniform vec2 tiledimage1_realworldimagesize = vec2(1.000000, 1.000000);
uniform vec2 tiledimage1_realworldtilesize = vec2(1.000000, 1.000000);
uniform int tiledimage1_filtertype = 1;
uniform int tiledimage1_framerange = 0;
uniform int tiledimage1_frameoffset = 0;
uniform int tiledimage1_frameendaction = 0;
uniform float blur_vector3_size = 0.500000;
uniform int blur_vector3_filtertype = 0;

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

vec2 mx_transform_uv(vec2 uv, vec2 uv_scale, vec2 uv_offset)
{
    uv = uv * uv_scale + uv_offset;
    return uv;
}

void mx_image_vector3(sampler2D tex_sampler, int layer, vec3 defaultval, vec2 texcoord, int uaddressmode, int vaddressmode, int filtertype, int framerange, int frameoffset, int frameendaction, vec2 uv_scale, vec2 uv_offset, out vec3 result)
{
    vec2 uv = mx_transform_uv(texcoord, uv_scale, uv_offset);
    result = texture(tex_sampler, uv).rgb;
}

void NG_tiledimage_vector3(sampler2D file, vec3 default1, vec2 texcoord1, vec2 uvtiling, vec2 uvoffset, vec2 realworldimagesize, vec2 realworldtilesize, int filtertype, int framerange, int frameoffset, int frameendaction, out vec3 out1)
{
    vec2 N_mult_vector3_out = texcoord1 * uvtiling;
    vec2 N_sub_vector3_out = N_mult_vector3_out - uvoffset;
    vec2 N_divtilesize_vector3_out = N_sub_vector3_out / realworldimagesize;
    vec2 N_multtilesize_vector3_out = N_divtilesize_vector3_out * realworldtilesize;
    vec3 N_img_vector3_out = vec3(0.0);
    mx_image_vector3(file, 0, default1, N_multtilesize_vector3_out, 2, 2, filtertype, framerange, frameoffset, frameendaction, vec2(1.000000, 1.000000), vec2(0.000000, 0.000000), N_img_vector3_out);
    out1 = N_img_vector3_out;
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
    vec3 tiledimage1_out = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1, tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out);
    vec2 blur_vector3_out_sample_size = mx_compute_sample_size_uv(geomprop_UV0_out1,1.000000,0.000000);
    vec3 tiledimage1_out_blur_vector3_out0 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(-2.000000,-2.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out0);
    vec3 tiledimage1_out_blur_vector3_out1 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(-1.000000,-2.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out1);
    vec3 tiledimage1_out_blur_vector3_out2 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(0.000000,-2.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out2);
    vec3 tiledimage1_out_blur_vector3_out3 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(1.000000,-2.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out3);
    vec3 tiledimage1_out_blur_vector3_out4 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(2.000000,-2.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out4);
    vec3 tiledimage1_out_blur_vector3_out5 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(-2.000000,-1.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out5);
    vec3 tiledimage1_out_blur_vector3_out6 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(-1.000000,-1.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out6);
    vec3 tiledimage1_out_blur_vector3_out7 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(0.000000,-1.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out7);
    vec3 tiledimage1_out_blur_vector3_out8 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(1.000000,-1.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out8);
    vec3 tiledimage1_out_blur_vector3_out9 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(2.000000,-1.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out9);
    vec3 tiledimage1_out_blur_vector3_out10 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(-2.000000,0.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out10);
    vec3 tiledimage1_out_blur_vector3_out11 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(-1.000000,0.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out11);
    vec3 tiledimage1_out_blur_vector3_out12 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(0.000000,0.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out12);
    vec3 tiledimage1_out_blur_vector3_out13 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(1.000000,0.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out13);
    vec3 tiledimage1_out_blur_vector3_out14 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(2.000000,0.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out14);
    vec3 tiledimage1_out_blur_vector3_out15 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(-2.000000,1.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out15);
    vec3 tiledimage1_out_blur_vector3_out16 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(-1.000000,1.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out16);
    vec3 tiledimage1_out_blur_vector3_out17 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(0.000000,1.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out17);
    vec3 tiledimage1_out_blur_vector3_out18 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(1.000000,1.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out18);
    vec3 tiledimage1_out_blur_vector3_out19 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(2.000000,1.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out19);
    vec3 tiledimage1_out_blur_vector3_out20 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(-2.000000,2.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out20);
    vec3 tiledimage1_out_blur_vector3_out21 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(-1.000000,2.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out21);
    vec3 tiledimage1_out_blur_vector3_out22 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(0.000000,2.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out22);
    vec3 tiledimage1_out_blur_vector3_out23 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(1.000000,2.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out23);
    vec3 tiledimage1_out_blur_vector3_out24 = vec3(0.0);
    NG_tiledimage_vector3(tiledimage1_file, tiledimage1_default, geomprop_UV0_out1 + blur_vector3_out_sample_size * vec2(2.000000,2.000000), tiledimage1_uvtiling, tiledimage1_uvoffset, tiledimage1_realworldimagesize, tiledimage1_realworldtilesize, tiledimage1_filtertype, tiledimage1_framerange, tiledimage1_frameoffset, tiledimage1_frameendaction, tiledimage1_out_blur_vector3_out24);
    vec3 blur_vector3_out_samples[MX_MAX_SAMPLE_COUNT];
    blur_vector3_out_samples[0] = tiledimage1_out_blur_vector3_out0;
    blur_vector3_out_samples[1] = tiledimage1_out_blur_vector3_out1;
    blur_vector3_out_samples[2] = tiledimage1_out_blur_vector3_out2;
    blur_vector3_out_samples[3] = tiledimage1_out_blur_vector3_out3;
    blur_vector3_out_samples[4] = tiledimage1_out_blur_vector3_out4;
    blur_vector3_out_samples[5] = tiledimage1_out_blur_vector3_out5;
    blur_vector3_out_samples[6] = tiledimage1_out_blur_vector3_out6;
    blur_vector3_out_samples[7] = tiledimage1_out_blur_vector3_out7;
    blur_vector3_out_samples[8] = tiledimage1_out_blur_vector3_out8;
    blur_vector3_out_samples[9] = tiledimage1_out_blur_vector3_out9;
    blur_vector3_out_samples[10] = tiledimage1_out_blur_vector3_out10;
    blur_vector3_out_samples[11] = tiledimage1_out_blur_vector3_out11;
    blur_vector3_out_samples[12] = tiledimage1_out_blur_vector3_out12;
    blur_vector3_out_samples[13] = tiledimage1_out_blur_vector3_out13;
    blur_vector3_out_samples[14] = tiledimage1_out_blur_vector3_out14;
    blur_vector3_out_samples[15] = tiledimage1_out_blur_vector3_out15;
    blur_vector3_out_samples[16] = tiledimage1_out_blur_vector3_out16;
    blur_vector3_out_samples[17] = tiledimage1_out_blur_vector3_out17;
    blur_vector3_out_samples[18] = tiledimage1_out_blur_vector3_out18;
    blur_vector3_out_samples[19] = tiledimage1_out_blur_vector3_out19;
    blur_vector3_out_samples[20] = tiledimage1_out_blur_vector3_out20;
    blur_vector3_out_samples[21] = tiledimage1_out_blur_vector3_out21;
    blur_vector3_out_samples[22] = tiledimage1_out_blur_vector3_out22;
    blur_vector3_out_samples[23] = tiledimage1_out_blur_vector3_out23;
    blur_vector3_out_samples[24] = tiledimage1_out_blur_vector3_out24;
    vec3 blur_vector3_out;
    if (blur_vector3_filtertype == 1)
    {
        blur_vector3_out = mx_convolution_vec3(blur_vector3_out_samples, c_gaussian_filter_weights, 10, 25);
    }
    else
    {
        blur_vector3_out = mx_convolution_vec3(blur_vector3_out_samples, c_box_filter_weights, 10, 25);
    }
    out1 = vec4(blur_vector3_out, 1.0);
}

