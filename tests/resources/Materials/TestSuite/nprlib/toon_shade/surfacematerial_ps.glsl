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
uniform vec3 toon_shade1_base_color = vec3(0.400000, 0.400000, 0.400000);
uniform vec3 toon_shade1_ambient_color = vec3(0.100000, 0.100000, 0.100000);
uniform vec3 toon_shade1_specular_color = vec3(0.769337, 0.872861, 0.599692);
uniform float toon_shade1_glossiness = 16.000000;
uniform vec3 toon_shade1_rim_color = vec3(0.500000, 0.500000, 0.500000);
uniform vec3 toon_shade1_light_direction = vec3(1.000000, -0.500000, -0.500000);
uniform vec3 toon_shade1_light_color = vec3(0.968215, 0.968215, 0.968215);
uniform float surface_unlit_emission = 1.000000;
uniform float surface_unlit_transmission = 0.000000;
uniform vec3 surface_unlit_transmission_color = vec3(1.000000, 1.000000, 1.000000);
uniform float surface_unlit_opacity = 1.000000;

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

void mx_smoothstep_float(float val, float low, float high, out float result)
{
    if (val >= high)
        result = 1.0;
    else if (val <= low)
        result = 0.0;
    else
        result = smoothstep(low, high, val);
}

void NG_convert_float_color3(float in1, out vec3 out1)
{
    vec3 combine_out = vec3(in1,in1,in1);
    out1 = combine_out;
}

void NG_toon_sample(vec3 base_color, vec3 ambient_color, vec3 specular_color, float glossiness, vec3 rim_color, vec3 light_direction, vec3 light_color, out vec3 output_color3)
{
    vec3 normal_out = normalize(vd.normalWorld);
    vec3 unit_light_direction_out = normalize(light_direction);
    vec3 viewdirection_vector3_out = normalize(vd.positionWorld - u_viewPosition);
    const float add_float_in1_tmp = 0.700000;
    const float add_float_in2_tmp = 0.010000;
    float add_float_out = add_float_in1_tmp + add_float_in2_tmp;
    const float subtract_float_in1_tmp = 0.700000;
    const float subtract_float_in2_tmp = 0.010000;
    float subtract_float_out = subtract_float_in1_tmp - subtract_float_in2_tmp;
    vec3 unit_normal_out = normalize(normal_out);
    const vec3 multiply_vector4_in2_tmp = vec3(-1.000000, -1.000000, -1.000000);
    vec3 multiply_vector4_out = unit_light_direction_out * multiply_vector4_in2_tmp;
    vec3 unit_viewdirection_out = normalize(viewdirection_vector3_out);
    float NdotL_out = dot(unit_normal_out, multiply_vector4_out);
    vec3 reflect_out = vec3(0.0);
    NG_reflect_vector3(unit_viewdirection_out, unit_normal_out, reflect_out);
    const vec3 multiply_vector3_in2_tmp = vec3(-1.000000, -1.000000, -1.000000);
    vec3 multiply_vector3_out = unit_viewdirection_out * multiply_vector3_in2_tmp;
    float smooth_gradient_out = 0.0;
    mx_smoothstep_float(NdotL_out, 0.000000, 0.001000, smooth_gradient_out);
    const float rim_power_in2_tmp = 0.100000;
    float rim_power_out = pow(NdotL_out, rim_power_in2_tmp);
    float LdotV_out = dot(multiply_vector4_out, reflect_out);
    float NdotV_out = dot(unit_normal_out, multiply_vector3_out);
    vec3 gradient_light_out = light_color * smooth_gradient_out;
    const float max_float_in2_tmp = 0.000000;
    float max_float_out = max(LdotV_out, max_float_in2_tmp);
    const float NdotV_invert_amount_tmp = 1.000000;
    float NdotV_invert_out = NdotV_invert_amount_tmp - NdotV_out;
    vec3 add_color3_out = gradient_light_out + ambient_color;
    float multiply_float_out = smooth_gradient_out * max_float_out;
    float rmi_intensity_out = NdotV_invert_out * rim_power_out;
    float specular_intensity_power_out = pow(multiply_float_out, glossiness);
    float rim_gradient_out = 0.0;
    mx_smoothstep_float(rmi_intensity_out, add_float_out, subtract_float_out, rim_gradient_out);
    float specular_remap_out = 0.0;
    mx_smoothstep_float(specular_intensity_power_out, 0.005000, 0.008000, specular_remap_out);
    vec3 rim_out = rim_color * rim_gradient_out;
    vec3 specular_intensity_color_out = vec3(0.0);
    NG_convert_float_color3(specular_remap_out, specular_intensity_color_out);
    vec3 specular_out = specular_intensity_color_out * specular_color;
    vec3 add_color4_out = add_color3_out + specular_out;
    vec3 add_color5_out = add_color4_out + rim_out;
    vec3 multiply_color3_out = base_color * add_color5_out;
    output_color3 = multiply_color3_out;
}

void main()
{
    vec3 toon_shade1_output_color3 = vec3(0.0);
    NG_toon_sample(toon_shade1_base_color, toon_shade1_ambient_color, toon_shade1_specular_color, toon_shade1_glossiness, toon_shade1_rim_color, toon_shade1_light_direction, toon_shade1_light_color, toon_shade1_output_color3);
    surfaceshader surface_unlit_out = surfaceshader(vec3(0.0),vec3(0.0));
    surface_unlit_out.color = surface_unlit_emission * toon_shade1_output_color3;
    surface_unlit_out.transparency = surface_unlit_transmission * surface_unlit_transmission_color;
    surface_unlit_out.color *= surface_unlit_opacity;
    surface_unlit_out.transparency = mix(vec3(1.0), surface_unlit_out.transparency, surface_unlit_opacity);
    material surfacematerial_out = surface_unlit_out;
    out1 = vec4(surfacematerial_out.color, 1.0);
}

