#version 400


struct BSDF { vec3 response; vec3 throughput; };
#define EDF vec3
struct surfaceshader { vec3 color; vec3 transparency; };
struct volumeshader { vec3 color; vec3 transparency; };
struct displacementshader { vec3 offset; float scale; };
struct lightshader { vec3 intensity; vec3 direction; };
#define material surfaceshader

// Uniform block: PublicUniforms
uniform int geomprop_UV0_index = 0;
uniform sampler2D b_image_file;
uniform int b_image_layer = 0;
uniform vec3 b_image_default = vec3(0.000000, 0.000000, 0.000000);
uniform int b_image_uaddressmode = 2;
uniform int b_image_vaddressmode = 2;
uniform int b_image_filtertype = 1;
uniform int b_image_framerange = 0;
uniform int b_image_frameoffset = 0;
uniform int b_image_frameendaction = 0;
uniform vec2 b_image_uv_scale = vec2(1.000000, 1.000000);
uniform vec2 b_image_uv_offset = vec2(0.000000, 0.000000);
uniform float impl_normalmap_scale = 1.500000;

in VertexData
{
    vec3 normalWorld;
    vec3 tangentWorld;
    vec3 bitangentWorld;
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

void mx_image_color3(sampler2D tex_sampler, int layer, vec3 defaultval, vec2 texcoord, int uaddressmode, int vaddressmode, int filtertype, int framerange, int frameoffset, int frameendaction, vec2 uv_scale, vec2 uv_offset, out vec3 result)
{
    vec2 uv = mx_transform_uv(texcoord, uv_scale, uv_offset);
    result = texture(tex_sampler, uv).rgb;
}

void NG_separate3_color3(vec3 in1, out float outr, out float outg, out float outb)
{
    const int N_extract_0_index_tmp = 0;
    float N_extract_0_out = in1[N_extract_0_index_tmp];
    const int N_extract_1_index_tmp = 1;
    float N_extract_1_out = in1[N_extract_1_index_tmp];
    const int N_extract_2_index_tmp = 2;
    float N_extract_2_out = in1[N_extract_2_index_tmp];
    outr = N_extract_0_out;
    outg = N_extract_1_out;
    outb = N_extract_2_out;
}

void NG_srgb_texture_to_lin_rec709_color3(vec3 in1, out vec3 out1)
{
    const float bias_in2_tmp = 0.055000;
    vec3 bias_out = in1 + bias_in2_tmp;
    const float linSeg_in2_tmp = 12.920000;
    vec3 linSeg_out = in1 / linSeg_in2_tmp;
    float colorSeparate_outr = 0.0;
    float colorSeparate_outg = 0.0;
    float colorSeparate_outb = 0.0;
    NG_separate3_color3(in1, colorSeparate_outr, colorSeparate_outg, colorSeparate_outb);
    const float max_in2_tmp = 0.000000;
    vec3 max_out = max(bias_out, max_in2_tmp);
    const float isAboveR_value2_tmp = 0.040450;
    const float isAboveR_in1_tmp = 1.000000;
    const float isAboveR_in2_tmp = 0.000000;
    float isAboveR_out = (colorSeparate_outr > isAboveR_value2_tmp) ? isAboveR_in1_tmp : isAboveR_in2_tmp;
    const float isAboveG_value2_tmp = 0.040450;
    const float isAboveG_in1_tmp = 1.000000;
    const float isAboveG_in2_tmp = 0.000000;
    float isAboveG_out = (colorSeparate_outg > isAboveG_value2_tmp) ? isAboveG_in1_tmp : isAboveG_in2_tmp;
    const float isAboveB_value2_tmp = 0.040450;
    const float isAboveB_in1_tmp = 1.000000;
    const float isAboveB_in2_tmp = 0.000000;
    float isAboveB_out = (colorSeparate_outb > isAboveB_value2_tmp) ? isAboveB_in1_tmp : isAboveB_in2_tmp;
    const float scale_in2_tmp = 1.055000;
    vec3 scale_out = max_out / scale_in2_tmp;
    vec3 isAbove_out = vec3(isAboveR_out,isAboveG_out,isAboveB_out);
    const float powSeg_in2_tmp = 2.400000;
    vec3 powSeg_out = pow(scale_out, vec3(powSeg_in2_tmp));
    vec3 mix_out = mix(linSeg_out, powSeg_out, isAbove_out);
    out1 = mix_out;
}

void NG_convert_color3_vector3(vec3 in1, out vec3 out1)
{
    float separate_outr = 0.0;
    float separate_outg = 0.0;
    float separate_outb = 0.0;
    NG_separate3_color3(in1, separate_outr, separate_outg, separate_outb);
    vec3 combine_out = vec3(separate_outr,separate_outg,separate_outb);
    out1 = combine_out;
}

void mx_normalmap_vector2(vec3 value, vec2 normal_scale, vec3 N, vec3 T, vec3 B, out vec3 result)
{
    value = (dot(value, value) == 0.0) ? vec3(0.0, 0.0, 1.0) : value * 2.0 - 1.0;
    value = T * value.x * normal_scale.x +
            B * value.y * normal_scale.y +
            N * value.z;
    result = normalize(value);
}

void mx_normalmap_float(vec3 value, float normal_scale, vec3 N, vec3 T, vec3 B, out vec3 result)
{
    mx_normalmap_vector2(value, vec2(normal_scale), N, T, B, result);
}

void main()
{
    vec3 geomprop_Nworld_out1 = normalize(vd.normalWorld);
    vec3 geomprop_Tworld_out1 = normalize(vd.tangentWorld);
    vec3 geomprop_Bworld_out1 = normalize(vd.bitangentWorld);
    vec2 geomprop_UV0_out1 = vd.texcoord_0.xy;
    vec3 b_image_out = vec3(0.0);
    mx_image_color3(b_image_file, b_image_layer, b_image_default, geomprop_UV0_out1, b_image_uaddressmode, b_image_vaddressmode, b_image_filtertype, b_image_framerange, b_image_frameoffset, b_image_frameendaction, b_image_uv_scale, b_image_uv_offset, b_image_out);
    vec3 b_image_out_cm_out = vec3(0.0);
    NG_srgb_texture_to_lin_rec709_color3(b_image_out, b_image_out_cm_out);
    vec3 c3tov3_out = vec3(0.0);
    NG_convert_color3_vector3(b_image_out_cm_out, c3tov3_out);
    vec3 impl_normalmap_out = vec3(0.0);
    mx_normalmap_float(c3tov3_out, impl_normalmap_scale, geomprop_Nworld_out1, geomprop_Tworld_out1, geomprop_Bworld_out1, impl_normalmap_out);
    out1 = vec4(impl_normalmap_out, 1.0);
}

