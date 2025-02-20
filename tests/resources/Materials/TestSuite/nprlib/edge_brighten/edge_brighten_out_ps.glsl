#version 400


struct BSDF { vec3 response; vec3 throughput; };
#define EDF vec3
struct surfaceshader { vec3 color; vec3 transparency; };
struct volumeshader { vec3 color; vec3 transparency; };
struct displacementshader { vec3 offset; float scale; };
struct lightshader { vec3 intensity; vec3 direction; };
#define material surfaceshader

// Uniform block: PrivateUniforms
uniform vec3 u_viewPosition = vec3(0.0);

// Uniform block: PublicUniforms
uniform bool facingratio_float_faceforward = true;
uniform bool facingratio_float_invert = true;
uniform float power_float_in2 = 3.000000;
uniform vec3 mix_color3_fg = vec3(0.735294, 0.735294, 0.735294);
uniform vec3 mix_color3_bg = vec3(0.000000, 0.098619, 0.186275);

in VertexData
{
    vec3 positionWorld;
    vec3 normalWorld;
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

void NG_facingratio_float(vec3 viewdirection, vec3 normal, bool faceforward, bool invert, out float out1)
{
    float N_dotproduct_out = dot(viewdirection, normal);
    float N_absval_out = abs(N_dotproduct_out);
    const float N_scale_in2_tmp = -1.000000;
    float N_scale_out = N_dotproduct_out * N_scale_in2_tmp;
    const bool N_facing_value2_tmp = true;
    float N_facing_out = (faceforward == N_facing_value2_tmp) ? N_absval_out : N_scale_out;
    const float N_invert_amount_tmp = 1.000000;
    float N_invert_out = N_invert_amount_tmp - N_facing_out;
    const bool N_result_value2_tmp = true;
    float N_result_out = (invert == N_result_value2_tmp) ? N_invert_out : N_facing_out;
    out1 = N_result_out;
}

void main()
{
    vec3 geomprop_Vworld_out1 = normalize(vd.positionWorld - u_viewPosition);
    vec3 geomprop_Nworld_out1 = normalize(vd.normalWorld);
    float facingratio_float_out = 0.0;
    NG_facingratio_float(geomprop_Vworld_out1, geomprop_Nworld_out1, facingratio_float_faceforward, facingratio_float_invert, facingratio_float_out);
    float power_float_out = pow(facingratio_float_out, power_float_in2);
    vec3 mix_color3_out = mix(mix_color3_bg, mix_color3_fg, power_float_out);
    out1 = vec4(mix_color3_out, 1.0);
}

