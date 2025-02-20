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
uniform sampler2D image1_file;
uniform int image1_layer = 0;
uniform float image1_default = 0.000000;
uniform int image1_uaddressmode = 2;
uniform int image1_vaddressmode = 2;
uniform int image1_filtertype = 1;
uniform int image1_framerange = 0;
uniform int image1_frameoffset = 0;
uniform int image1_frameendaction = 0;
uniform vec2 image1_uv_scale = vec2(1.000000, 1.000000);
uniform vec2 image1_uv_offset = vec2(0.000000, 0.000000);
uniform float blur_float_size = 0.500000;
uniform int blur_float_filtertype = 0;

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

void mx_image_float(sampler2D tex_sampler, int layer, float defaultval, vec2 texcoord, int uaddressmode, int vaddressmode, int filtertype, int framerange, int frameoffset, int frameendaction, vec2 uv_scale, vec2 uv_offset, out float result)
{
    vec2 uv = mx_transform_uv(texcoord, uv_scale, uv_offset);
    result = texture(tex_sampler, uv).r;
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
    float image1_out = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1, image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out);
    vec2 blur_float_out_sample_size = mx_compute_sample_size_uv(geomprop_UV0_out1,1.000000,0.000000);
    float image1_out_blur_float_out0 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(-2.000000,-2.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out0);
    float image1_out_blur_float_out1 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(-1.000000,-2.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out1);
    float image1_out_blur_float_out2 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(0.000000,-2.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out2);
    float image1_out_blur_float_out3 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(1.000000,-2.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out3);
    float image1_out_blur_float_out4 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(2.000000,-2.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out4);
    float image1_out_blur_float_out5 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(-2.000000,-1.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out5);
    float image1_out_blur_float_out6 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(-1.000000,-1.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out6);
    float image1_out_blur_float_out7 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(0.000000,-1.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out7);
    float image1_out_blur_float_out8 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(1.000000,-1.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out8);
    float image1_out_blur_float_out9 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(2.000000,-1.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out9);
    float image1_out_blur_float_out10 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(-2.000000,0.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out10);
    float image1_out_blur_float_out11 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(-1.000000,0.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out11);
    float image1_out_blur_float_out12 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(0.000000,0.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out12);
    float image1_out_blur_float_out13 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(1.000000,0.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out13);
    float image1_out_blur_float_out14 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(2.000000,0.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out14);
    float image1_out_blur_float_out15 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(-2.000000,1.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out15);
    float image1_out_blur_float_out16 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(-1.000000,1.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out16);
    float image1_out_blur_float_out17 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(0.000000,1.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out17);
    float image1_out_blur_float_out18 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(1.000000,1.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out18);
    float image1_out_blur_float_out19 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(2.000000,1.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out19);
    float image1_out_blur_float_out20 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(-2.000000,2.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out20);
    float image1_out_blur_float_out21 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(-1.000000,2.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out21);
    float image1_out_blur_float_out22 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(0.000000,2.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out22);
    float image1_out_blur_float_out23 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(1.000000,2.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out23);
    float image1_out_blur_float_out24 = 0.0;
    mx_image_float(image1_file, image1_layer, image1_default, geomprop_UV0_out1 + blur_float_out_sample_size * vec2(2.000000,2.000000), image1_uaddressmode, image1_vaddressmode, image1_filtertype, image1_framerange, image1_frameoffset, image1_frameendaction, image1_uv_scale, image1_uv_offset, image1_out_blur_float_out24);
    float blur_float_out_samples[MX_MAX_SAMPLE_COUNT];
    blur_float_out_samples[0] = image1_out_blur_float_out0;
    blur_float_out_samples[1] = image1_out_blur_float_out1;
    blur_float_out_samples[2] = image1_out_blur_float_out2;
    blur_float_out_samples[3] = image1_out_blur_float_out3;
    blur_float_out_samples[4] = image1_out_blur_float_out4;
    blur_float_out_samples[5] = image1_out_blur_float_out5;
    blur_float_out_samples[6] = image1_out_blur_float_out6;
    blur_float_out_samples[7] = image1_out_blur_float_out7;
    blur_float_out_samples[8] = image1_out_blur_float_out8;
    blur_float_out_samples[9] = image1_out_blur_float_out9;
    blur_float_out_samples[10] = image1_out_blur_float_out10;
    blur_float_out_samples[11] = image1_out_blur_float_out11;
    blur_float_out_samples[12] = image1_out_blur_float_out12;
    blur_float_out_samples[13] = image1_out_blur_float_out13;
    blur_float_out_samples[14] = image1_out_blur_float_out14;
    blur_float_out_samples[15] = image1_out_blur_float_out15;
    blur_float_out_samples[16] = image1_out_blur_float_out16;
    blur_float_out_samples[17] = image1_out_blur_float_out17;
    blur_float_out_samples[18] = image1_out_blur_float_out18;
    blur_float_out_samples[19] = image1_out_blur_float_out19;
    blur_float_out_samples[20] = image1_out_blur_float_out20;
    blur_float_out_samples[21] = image1_out_blur_float_out21;
    blur_float_out_samples[22] = image1_out_blur_float_out22;
    blur_float_out_samples[23] = image1_out_blur_float_out23;
    blur_float_out_samples[24] = image1_out_blur_float_out24;
    float blur_float_out;
    if (blur_float_filtertype == 1)
    {
        blur_float_out = mx_convolution_float(blur_float_out_samples, c_gaussian_filter_weights, 10, 25);
    }
    else
    {
        blur_float_out = mx_convolution_float(blur_float_out_samples, c_box_filter_weights, 10, 25);
    }
    out1 = vec4(blur_float_out, blur_float_out, blur_float_out, 1.0);
}

