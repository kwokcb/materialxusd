#version 400


struct BSDF { vec3 response; vec3 throughput; };
#define EDF vec3
struct surfaceshader { vec3 color; vec3 transparency; };
struct volumeshader { vec3 color; vec3 transparency; };
struct displacementshader { vec3 offset; float scale; };
struct lightshader { vec3 intensity; vec3 direction; };
#define material surfaceshader

// Uniform block: PublicUniforms
uniform vec2 scale = vec2(8.000000, 8.000000);
uniform int texcoord1_index = 0;
uniform int mult1_x_index = 0;
uniform int mult1_y_index = 1;
uniform float mod1_in2 = 2.000000;

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

void main()
{
    vec2 texcoord1_out = vd.texcoord_0.xy;
    vec2 mult1_out = texcoord1_out * scale;
    float mult1_x_out = mult1_out[mult1_x_index];
    float mult1_y_out = mult1_out[mult1_y_index];
    float floor1_out = floor(mult1_x_out);
    float floor2_out = floor(mult1_y_out);
    float add1_out = floor1_out + floor2_out;
    float mod1_out = mx_mod(add1_out, mod1_in2);
    out1 = vec4(mod1_out, mod1_out, mod1_out, 1.0);
}

