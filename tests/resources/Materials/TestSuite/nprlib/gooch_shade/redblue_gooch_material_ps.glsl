#version 400


struct BSDF { vec3 response; vec3 throughput; };
#define EDF vec3
struct surfaceshader { vec3 color; vec3 transparency; };
struct volumeshader { vec3 color; vec3 transparency; };
struct displacementshader { vec3 offset; float scale; };
struct lightshader { vec3 intensity; vec3 direction; };
#define material surfaceshader

// Uniform block: PrivateUniforms
uniform mat4 u_envMatrix = mat4(-1.000000, 0.000000, 0.000000, 0.000000, 0.000000, 1.000000, 0.000000, 0.000000, 0.000000, 0.000000, -1.000000, 0.000000, 0.000000, 0.000000, 0.000000, 1.000000);
uniform sampler2D u_envRadiance;
uniform float u_envLightIntensity = 1.000000;
uniform int u_envRadianceMips = 1;
uniform int u_envRadianceSamples = 16;
uniform sampler2D u_envIrradiance;
uniform bool u_refractionTwoSided = false;
uniform vec3 u_viewPosition = vec3(0.0);

// Uniform block: PublicUniforms
uniform surfaceshader backsurfaceshader;
uniform displacementshader displacementshader1;
uniform vec3 red_blue_gooch_warm_color = vec3(0.900000, 0.100000, 0.100000);
uniform vec3 red_blue_gooch_cool_color = vec3(0.100000, 0.100000, 0.900000);
uniform float red_blue_gooch_specular_intensity = 1.000000;
uniform float red_blue_gooch_shininess = 64.000000;
uniform vec3 red_blue_gooch_light_direction = vec3(1.000000, -0.500000, -0.500000);
uniform float redblue_gooch_surface_emission = 1.000000;
uniform float redblue_gooch_surface_transmission = 0.000000;
uniform vec3 redblue_gooch_surface_transmission_color = vec3(1.000000, 1.000000, 1.000000);
uniform float redblue_gooch_surface_opacity = 1.000000;

in VertexData
{
    vec3 normalWorld;
    vec3 positionWorld;
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

void NG_reflect_vector3(vec3 in1, vec3 normal, out vec3 out1)
{
    float NdotI_out = dot(normal, in1);
    const float NdotI_2_in2_tmp = 2.000000;
    float NdotI_2_out = NdotI_out * NdotI_2_in2_tmp;
    vec3 NdotI_N_2_out = normal * NdotI_2_out;
    vec3 reflection_vector_out = in1 - NdotI_N_2_out;
    out1 = reflection_vector_out;
}

void NG_gooch_shade(vec3 warm_color, vec3 cool_color, float specular_intensity, float shininess, vec3 light_direction, out vec3 out1)
{
    vec3 normal_out = normalize(vd.normalWorld);
    vec3 unit_lightdir_out = normalize(light_direction);
    vec3 viewdir_out = normalize(vd.positionWorld - u_viewPosition);
    vec3 unit_normal_out = normalize(normal_out);
    const float invert_lightdir_in2_tmp = -1.000000;
    vec3 invert_lightdir_out = unit_lightdir_out * invert_lightdir_in2_tmp;
    vec3 unit_viewdir_out = normalize(viewdir_out);
    float NdotL_out = dot(unit_normal_out, unit_lightdir_out);
    vec3 view_reflect_out = vec3(0.0);
    NG_reflect_vector3(unit_viewdir_out, unit_normal_out, view_reflect_out);
    const float one_plus_NdotL_in1_tmp = 1.000000;
    float one_plus_NdotL_out = one_plus_NdotL_in1_tmp + NdotL_out;
    float VdotR_out = dot(invert_lightdir_out, view_reflect_out);
    const float cool_intensity_in2_tmp = 2.000000;
    float cool_intensity_out = one_plus_NdotL_out / cool_intensity_in2_tmp;
    const float VdotR_nonnegative_in2_tmp = 0.000000;
    float VdotR_nonnegative_out = max(VdotR_out, VdotR_nonnegative_in2_tmp);
    vec3 diffuse_out = mix(warm_color, cool_color, cool_intensity_out);
    float specular_highlight_out = pow(VdotR_nonnegative_out, shininess);
    float specular_out = specular_highlight_out * specular_intensity;
    vec3 final_color_out = diffuse_out + specular_out;
    out1 = final_color_out;
}

void main()
{
    vec3 red_blue_gooch_out = vec3(0.0);
    NG_gooch_shade(red_blue_gooch_warm_color, red_blue_gooch_cool_color, red_blue_gooch_specular_intensity, red_blue_gooch_shininess, red_blue_gooch_light_direction, red_blue_gooch_out);
    surfaceshader redblue_gooch_surface_out = surfaceshader(vec3(0.0),vec3(0.0));
    redblue_gooch_surface_out.color = redblue_gooch_surface_emission * red_blue_gooch_out;
    redblue_gooch_surface_out.transparency = redblue_gooch_surface_transmission * redblue_gooch_surface_transmission_color;
    redblue_gooch_surface_out.color *= redblue_gooch_surface_opacity;
    redblue_gooch_surface_out.transparency = mix(vec3(1.0), redblue_gooch_surface_out.transparency, redblue_gooch_surface_opacity);
    material redblue_gooch_material_out = redblue_gooch_surface_out;
    out1 = vec4(redblue_gooch_material_out.color, 1.0);
}

