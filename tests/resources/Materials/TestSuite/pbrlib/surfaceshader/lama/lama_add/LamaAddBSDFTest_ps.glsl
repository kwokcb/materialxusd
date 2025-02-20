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
uniform vec3 LamaDielectric_scatterColor_cm_in = vec3(0.000000, 0.000000, 0.000000);
uniform vec3 LamaConductor_tint_cm_in = vec3(1.000000, 1.000000, 1.000000);
uniform vec3 LamaConductor_reflectivity_cm_in = vec3(0.945000, 0.777200, 0.373700);
uniform vec3 LamaConductor_edgeColor_cm_in = vec3(0.997900, 0.981300, 0.752300);
uniform vec3 LamaDielectric_transmissionTint_cm_in = vec3(1.000000, 1.000000, 1.000000);
uniform vec3 LamaDielectric_reflectionTint_cm_in = vec3(1.000000, 1.000000, 1.000000);
uniform vec3 LamaDielectric_absorptionColor_cm_in = vec3(1.000000, 1.000000, 1.000000);
uniform int LamaConductor_fresnelMode = 0;
uniform vec3 LamaConductor_IOR = vec3(0.180000, 0.420000, 1.370000);
uniform vec3 LamaConductor_extinction = vec3(3.420000, 2.350000, 1.770000);
uniform float LamaConductor_roughness = 0.100000;
uniform float LamaConductor_anisotropy = 0.000000;
uniform float LamaConductor_anisotropyRotation = 0.000000;
uniform int LamaDielectric_fresnelMode = 0;
uniform float LamaDielectric_IOR = 1.500000;
uniform float LamaDielectric_reflectivity = 0.040000;
uniform float LamaDielectric_roughness = 0.100000;
uniform float LamaDielectric_anisotropy = 0.000000;
uniform float LamaDielectric_rotation = 0.000000;
uniform float LamaDielectric_absorptionRadius = 1.000000;
uniform float LamaDielectric_scatterAnisotropy = 0.000000;
uniform float LamaAddBSDF_weight1 = 0.500000;
uniform float LamaAddBSDF_weight2 = 0.500000;
uniform float LamaAddBSDFSurface_opacity = 1.000000;
uniform bool LamaAddBSDFSurface_thin_walled = false;

in VertexData
{
    vec3 normalWorld;
    vec3 tangentWorld;
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

#define DIRECTIONAL_ALBEDO_METHOD 0

#define M_PI 3.1415926535897932
#define M_PI_INV (1.0 / M_PI)

float mx_pow5(float x)
{
    return mx_square(mx_square(x)) * x;
}

float mx_pow6(float x)
{
    float x2 = mx_square(x);
    return mx_square(x2) * x2;
}

// Standard Schlick Fresnel
float mx_fresnel_schlick(float cosTheta, float F0)
{
    float x = clamp(1.0 - cosTheta, 0.0, 1.0);
    float x5 = mx_pow5(x);
    return F0 + (1.0 - F0) * x5;
}
vec3 mx_fresnel_schlick(float cosTheta, vec3 F0)
{
    float x = clamp(1.0 - cosTheta, 0.0, 1.0);
    float x5 = mx_pow5(x);
    return F0 + (1.0 - F0) * x5;
}

// Generalized Schlick Fresnel
float mx_fresnel_schlick(float cosTheta, float F0, float F90)
{
    float x = clamp(1.0 - cosTheta, 0.0, 1.0);
    float x5 = mx_pow5(x);
    return mix(F0, F90, x5);
}
vec3 mx_fresnel_schlick(float cosTheta, vec3 F0, vec3 F90)
{
    float x = clamp(1.0 - cosTheta, 0.0, 1.0);
    float x5 = mx_pow5(x);
    return mix(F0, F90, x5);
}

// Generalized Schlick Fresnel with a variable exponent
float mx_fresnel_schlick(float cosTheta, float F0, float F90, float exponent)
{
    float x = clamp(1.0 - cosTheta, 0.0, 1.0);
    return mix(F0, F90, pow(x, exponent));
}
vec3 mx_fresnel_schlick(float cosTheta, vec3 F0, vec3 F90, float exponent)
{
    float x = clamp(1.0 - cosTheta, 0.0, 1.0);
    return mix(F0, F90, pow(x, exponent));
}

// Enforce that the given normal is forward-facing from the specified view direction.
vec3 mx_forward_facing_normal(vec3 N, vec3 V)
{
    return (dot(N, V) < 0.0) ? -N : N;
}

// https://www.graphics.rwth-aachen.de/publication/2/jgt.pdf
float mx_golden_ratio_sequence(int i)
{
    const float GOLDEN_RATIO = 1.6180339887498948;
    return fract((float(i) + 1.0) * GOLDEN_RATIO);
}

// https://people.irisa.fr/Ricardo.Marques/articles/2013/SF_CGF.pdf
vec2 mx_spherical_fibonacci(int i, int numSamples)
{
    return vec2((float(i) + 0.5) / float(numSamples), mx_golden_ratio_sequence(i));
}

// Generate a uniform-weighted sample on the unit hemisphere.
vec3 mx_uniform_sample_hemisphere(vec2 Xi)
{
    float phi = 2.0 * M_PI * Xi.x;
    float cosTheta = 1.0 - Xi.y;
    float sinTheta = sqrt(1.0 - mx_square(cosTheta));
    return vec3(mx_cos(phi) * sinTheta,
                mx_sin(phi) * sinTheta,
                cosTheta);
}

// Generate a cosine-weighted sample on the unit hemisphere.
vec3 mx_cosine_sample_hemisphere(vec2 Xi)
{
    float phi = 2.0 * M_PI * Xi.x;
    float cosTheta = sqrt(Xi.y);
    float sinTheta = sqrt(1.0 - Xi.y);
    return vec3(mx_cos(phi) * sinTheta,
                mx_sin(phi) * sinTheta,
                cosTheta);
}

// Construct an orthonormal basis from a unit vector.
// https://graphics.pixar.com/library/OrthonormalB/paper.pdf
mat3 mx_orthonormal_basis(vec3 N)
{
    float sign = (N.z < 0.0) ? -1.0 : 1.0;
    float a = -1.0 / (sign + N.z);
    float b = N.x * N.y * a;
    vec3 X = vec3(1.0 + sign * N.x * N.x * a, sign * b, -sign * N.x);
    vec3 Y = vec3(b, sign + N.y * N.y * a, -N.y);
    return mat3(X, Y, N);
}

const int FRESNEL_MODEL_DIELECTRIC = 0;
const int FRESNEL_MODEL_CONDUCTOR = 1;
const int FRESNEL_MODEL_SCHLICK = 2;

// Parameters for Fresnel calculations
struct FresnelData
{
    // Fresnel model
    int model;
    bool airy;

    // Physical Fresnel
    vec3 ior;
    vec3 extinction;

    // Generalized Schlick Fresnel
    vec3 F0;
    vec3 F82;
    vec3 F90;
    float exponent;

    // Thin film
    float tf_thickness;
    float tf_ior;

    // Refraction
    bool refraction;
};

// https://media.disneyanimation.com/uploads/production/publication_asset/48/asset/s2012_pbs_disney_brdf_notes_v3.pdf
// Appendix B.2 Equation 13
float mx_ggx_NDF(vec3 H, vec2 alpha)
{
    vec2 He = H.xy / alpha;
    float denom = dot(He, He) + mx_square(H.z);
    return 1.0 / (M_PI * alpha.x * alpha.y * mx_square(denom));
}

// https://ggx-research.github.io/publication/2023/06/09/publication-ggx.html
vec3 mx_ggx_importance_sample_VNDF(vec2 Xi, vec3 V, vec2 alpha)
{
    // Transform the view direction to the hemisphere configuration.
    V = normalize(vec3(V.xy * alpha, V.z));

    // Sample a spherical cap in (-V.z, 1].
    float phi = 2.0 * M_PI * Xi.x;
    float z = (1.0 - Xi.y) * (1.0 + V.z) - V.z;
    float sinTheta = sqrt(clamp(1.0 - z * z, 0.0, 1.0));
    float x = sinTheta * mx_cos(phi);
    float y = sinTheta * mx_sin(phi);
    vec3 c = vec3(x, y, z);

    // Compute the microfacet normal.
    vec3 H = c + V;

    // Transform the microfacet normal back to the ellipsoid configuration.
    H = normalize(vec3(H.xy * alpha, max(H.z, 0.0)));

    return H;
}

// https://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.pdf
// Equation 34
float mx_ggx_smith_G1(float cosTheta, float alpha)
{
    float cosTheta2 = mx_square(cosTheta);
    float tanTheta2 = (1.0 - cosTheta2) / cosTheta2;
    return 2.0 / (1.0 + sqrt(1.0 + mx_square(alpha) * tanTheta2));
}

// Height-correlated Smith masking-shadowing
// http://jcgt.org/published/0003/02/03/paper.pdf
// Equations 72 and 99
float mx_ggx_smith_G2(float NdotL, float NdotV, float alpha)
{
    float alpha2 = mx_square(alpha);
    float lambdaL = sqrt(alpha2 + (1.0 - alpha2) * mx_square(NdotL));
    float lambdaV = sqrt(alpha2 + (1.0 - alpha2) * mx_square(NdotV));
    return 2.0 / (lambdaL / NdotL + lambdaV / NdotV);
}

// Rational quadratic fit to Monte Carlo data for GGX directional albedo.
vec3 mx_ggx_dir_albedo_analytic(float NdotV, float alpha, vec3 F0, vec3 F90)
{
    float x = NdotV;
    float y = alpha;
    float x2 = mx_square(x);
    float y2 = mx_square(y);
    vec4 r = vec4(0.1003, 0.9345, 1.0, 1.0) +
             vec4(-0.6303, -2.323, -1.765, 0.2281) * x +
             vec4(9.748, 2.229, 8.263, 15.94) * y +
             vec4(-2.038, -3.748, 11.53, -55.83) * x * y +
             vec4(29.34, 1.424, 28.96, 13.08) * x2 +
             vec4(-8.245, -0.7684, -7.507, 41.26) * y2 +
             vec4(-26.44, 1.436, -36.11, 54.9) * x2 * y +
             vec4(19.99, 0.2913, 15.86, 300.2) * x * y2 +
             vec4(-5.448, 0.6286, 33.37, -285.1) * x2 * y2;
    vec2 AB = clamp(r.xy / r.zw, 0.0, 1.0);
    return F0 * AB.x + F90 * AB.y;
}

vec3 mx_ggx_dir_albedo_table_lookup(float NdotV, float alpha, vec3 F0, vec3 F90)
{
#if DIRECTIONAL_ALBEDO_METHOD == 1
    if (textureSize(u_albedoTable, 0).x > 1)
    {
        vec2 AB = texture(u_albedoTable, vec2(NdotV, alpha)).rg;
        return F0 * AB.x + F90 * AB.y;
    }
#endif
    return vec3(0.0);
}

// https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf
vec3 mx_ggx_dir_albedo_monte_carlo(float NdotV, float alpha, vec3 F0, vec3 F90)
{
    NdotV = clamp(NdotV, M_FLOAT_EPS, 1.0);
    vec3 V = vec3(sqrt(1.0 - mx_square(NdotV)), 0, NdotV);

    vec2 AB = vec2(0.0);
    const int SAMPLE_COUNT = 64;
    for (int i = 0; i < SAMPLE_COUNT; i++)
    {
        vec2 Xi = mx_spherical_fibonacci(i, SAMPLE_COUNT);

        // Compute the half vector and incoming light direction.
        vec3 H = mx_ggx_importance_sample_VNDF(Xi, V, vec2(alpha));
        vec3 L = -reflect(V, H);
        
        // Compute dot products for this sample.
        float NdotL = clamp(L.z, M_FLOAT_EPS, 1.0);
        float VdotH = clamp(dot(V, H), M_FLOAT_EPS, 1.0);

        // Compute the Fresnel term.
        float Fc = mx_fresnel_schlick(VdotH, 0.0, 1.0);

        // Compute the per-sample geometric term.
        // https://hal.inria.fr/hal-00996995v2/document, Algorithm 2
        float G2 = mx_ggx_smith_G2(NdotL, NdotV, alpha);
        
        // Add the contribution of this sample.
        AB += vec2(G2 * (1.0 - Fc), G2 * Fc);
    }

    // Apply the global component of the geometric term and normalize.
    AB /= mx_ggx_smith_G1(NdotV, alpha) * float(SAMPLE_COUNT);

    // Return the final directional albedo.
    return F0 * AB.x + F90 * AB.y;
}

vec3 mx_ggx_dir_albedo(float NdotV, float alpha, vec3 F0, vec3 F90)
{
#if DIRECTIONAL_ALBEDO_METHOD == 0
    return mx_ggx_dir_albedo_analytic(NdotV, alpha, F0, F90);
#elif DIRECTIONAL_ALBEDO_METHOD == 1
    return mx_ggx_dir_albedo_table_lookup(NdotV, alpha, F0, F90);
#else
    return mx_ggx_dir_albedo_monte_carlo(NdotV, alpha, F0, F90);
#endif
}

float mx_ggx_dir_albedo(float NdotV, float alpha, float F0, float F90)
{
    return mx_ggx_dir_albedo(NdotV, alpha, vec3(F0), vec3(F90)).x;
}

// https://blog.selfshadow.com/publications/turquin/ms_comp_final.pdf
// Equations 14 and 16
vec3 mx_ggx_energy_compensation(float NdotV, float alpha, vec3 Fss)
{
    float Ess = mx_ggx_dir_albedo(NdotV, alpha, 1.0, 1.0);
    return 1.0 + Fss * (1.0 - Ess) / Ess;
}

float mx_ggx_energy_compensation(float NdotV, float alpha, float Fss)
{
    return mx_ggx_energy_compensation(NdotV, alpha, vec3(Fss)).x;
}

// Compute the average of an anisotropic alpha pair.
float mx_average_alpha(vec2 alpha)
{
    return sqrt(alpha.x * alpha.y);
}

// Convert a real-valued index of refraction to normal-incidence reflectivity.
float mx_ior_to_f0(float ior)
{
    return mx_square((ior - 1.0) / (ior + 1.0));
}

// Convert normal-incidence reflectivity to real-valued index of refraction.
float mx_f0_to_ior(float F0)
{
    float sqrtF0 = sqrt(clamp(F0, 0.01, 0.99));
    return (1.0 + sqrtF0) / (1.0 - sqrtF0);
}
vec3 mx_f0_to_ior(vec3 F0)
{
    vec3 sqrtF0 = sqrt(clamp(F0, 0.01, 0.99));
    return (vec3(1.0) + sqrtF0) / (vec3(1.0) - sqrtF0);
}

// https://renderwonk.com/publications/wp-generalization-adobe/gen-adobe.pdf
vec3 mx_fresnel_hoffman_schlick(float cosTheta, FresnelData fd)
{
    const float COS_THETA_MAX = 1.0 / 7.0;
    const float COS_THETA_FACTOR = 1.0 / (COS_THETA_MAX * pow(1.0 - COS_THETA_MAX, 6.0));

    float x = clamp(cosTheta, 0.0, 1.0);
    vec3 a = mix(fd.F0, fd.F90, pow(1.0 - COS_THETA_MAX, fd.exponent)) * (vec3(1.0) - fd.F82) * COS_THETA_FACTOR;
    return mix(fd.F0, fd.F90, pow(1.0 - x, fd.exponent)) - a * x * mx_pow6(1.0 - x);
}

// https://seblagarde.wordpress.com/2013/04/29/memo-on-fresnel-equations/
float mx_fresnel_dielectric(float cosTheta, float ior)
{
    float c = cosTheta;
    float g2 = ior*ior + c*c - 1.0;
    if (g2 < 0.0)
    {
        // Total internal reflection
        return 1.0;
    }

    float g = sqrt(g2);
    return 0.5 * mx_square((g - c) / (g + c)) *
                (1.0 + mx_square(((g + c) * c - 1.0) / ((g - c) * c + 1.0)));
}

// https://seblagarde.wordpress.com/2013/04/29/memo-on-fresnel-equations/
vec2 mx_fresnel_dielectric_polarized(float cosTheta, float ior)
{
    float cosTheta2 = mx_square(clamp(cosTheta, 0.0, 1.0));
    float sinTheta2 = 1.0 - cosTheta2;

    float t0 = max(ior * ior - sinTheta2, 0.0);
    float t1 = t0 + cosTheta2;
    float t2 = 2.0 * sqrt(t0) * cosTheta;
    float Rs = (t1 - t2) / (t1 + t2);

    float t3 = cosTheta2 * t0 + sinTheta2 * sinTheta2;
    float t4 = t2 * sinTheta2;
    float Rp = Rs * (t3 - t4) / (t3 + t4);

    return vec2(Rp, Rs);
}

// https://seblagarde.wordpress.com/2013/04/29/memo-on-fresnel-equations/
void mx_fresnel_conductor_polarized(float cosTheta, vec3 n, vec3 k, out vec3 Rp, out vec3 Rs)
{
    float cosTheta2 = mx_square(clamp(cosTheta, 0.0, 1.0));
    float sinTheta2 = 1.0 - cosTheta2;
    vec3 n2 = n * n;
    vec3 k2 = k * k;

    vec3 t0 = n2 - k2 - vec3(sinTheta2);
    vec3 a2plusb2 = sqrt(t0 * t0 + 4.0 * n2 * k2);
    vec3 t1 = a2plusb2 + vec3(cosTheta2);
    vec3 a = sqrt(max(0.5 * (a2plusb2 + t0), 0.0));
    vec3 t2 = 2.0 * a * cosTheta;
    Rs = (t1 - t2) / (t1 + t2);

    vec3 t3 = cosTheta2 * a2plusb2 + vec3(sinTheta2 * sinTheta2);
    vec3 t4 = t2 * sinTheta2;
    Rp = Rs * (t3 - t4) / (t3 + t4);
}

vec3 mx_fresnel_conductor(float cosTheta, vec3 n, vec3 k)
{
    vec3 Rp, Rs;
    mx_fresnel_conductor_polarized(cosTheta, n, k, Rp, Rs);
    return 0.5 * (Rp  + Rs);
}

// https://belcour.github.io/blog/research/publication/2017/05/01/brdf-thin-film.html
void mx_fresnel_conductor_phase_polarized(float cosTheta, float eta1, vec3 eta2, vec3 kappa2, out vec3 phiP, out vec3 phiS)
{
    vec3 k2 = kappa2 / eta2;
    vec3 sinThetaSqr = vec3(1.0) - cosTheta * cosTheta;
    vec3 A = eta2*eta2*(vec3(1.0)-k2*k2) - eta1*eta1*sinThetaSqr;
    vec3 B = sqrt(A*A + mx_square(2.0*eta2*eta2*k2));
    vec3 U = sqrt((A+B)/2.0);
    vec3 V = max(vec3(0.0), sqrt((B-A)/2.0));

    phiS = mx_atan(2.0*eta1*V*cosTheta, U*U + V*V - mx_square(eta1*cosTheta));
    phiP = mx_atan(2.0*eta1*eta2*eta2*cosTheta * (2.0*k2*U - (vec3(1.0)-k2*k2) * V),
                   mx_square(eta2*eta2*(vec3(1.0)+k2*k2)*cosTheta) - eta1*eta1*(U*U+V*V));
}

// https://belcour.github.io/blog/research/publication/2017/05/01/brdf-thin-film.html
vec3 mx_eval_sensitivity(float opd, vec3 shift)
{
    // Use Gaussian fits, given by 3 parameters: val, pos and var
    float phase = 2.0*M_PI * opd;
    vec3 val = vec3(5.4856e-13, 4.4201e-13, 5.2481e-13);
    vec3 pos = vec3(1.6810e+06, 1.7953e+06, 2.2084e+06);
    vec3 var = vec3(4.3278e+09, 9.3046e+09, 6.6121e+09);
    vec3 xyz = val * sqrt(2.0*M_PI * var) * mx_cos(pos * phase + shift) * exp(- var * phase*phase);
    xyz.x   += 9.7470e-14 * sqrt(2.0*M_PI * 4.5282e+09) * mx_cos(2.2399e+06 * phase + shift[0]) * exp(- 4.5282e+09 * phase*phase);
    return xyz / 1.0685e-7;
}

// A Practical Extension to Microfacet Theory for the Modeling of Varying Iridescence
// https://belcour.github.io/blog/research/publication/2017/05/01/brdf-thin-film.html
vec3 mx_fresnel_airy(float cosTheta, FresnelData fd)
{
    // XYZ to CIE 1931 RGB color space (using neutral E illuminant)
    const mat3 XYZ_TO_RGB = mat3(2.3706743, -0.5138850, 0.0052982, -0.9000405, 1.4253036, -0.0146949, -0.4706338, 0.0885814, 1.0093968);

    // Assume vacuum on the outside
    float eta1 = 1.0;
    float eta2 = max(fd.tf_ior, eta1);
    vec3 eta3 = (fd.model == FRESNEL_MODEL_SCHLICK) ? mx_f0_to_ior(fd.F0) : fd.ior;
    vec3 kappa3 = (fd.model == FRESNEL_MODEL_SCHLICK) ? vec3(0.0) : fd.extinction;
    float cosThetaT = sqrt(1.0 - (1.0 - mx_square(cosTheta)) * mx_square(eta1 / eta2));

    // First interface
    vec2 R12 = mx_fresnel_dielectric_polarized(cosTheta, eta2 / eta1);
    if (cosThetaT <= 0.0)
    {
        // Total internal reflection
        R12 = vec2(1.0);
    }
    vec2 T121 = vec2(1.0) - R12;

    // Second interface
    vec3 R23p, R23s;
    if (fd.model == FRESNEL_MODEL_SCHLICK)
    {
        vec3 f = mx_fresnel_hoffman_schlick(cosThetaT, fd);
        R23p = 0.5 * f;
        R23s = 0.5 * f;
    }
    else
    {
        mx_fresnel_conductor_polarized(cosThetaT, eta3 / eta2, kappa3 / eta2, R23p, R23s);
    }

    // Phase shift
    float cosB = mx_cos(mx_atan(eta2 / eta1));
    vec2 phi21 = vec2(cosTheta < cosB ? 0.0 : M_PI, M_PI);
    vec3 phi23p, phi23s;
    if (fd.model == FRESNEL_MODEL_SCHLICK)
    {
        phi23p = vec3((eta3[0] < eta2) ? M_PI : 0.0,
                      (eta3[1] < eta2) ? M_PI : 0.0,
                      (eta3[2] < eta2) ? M_PI : 0.0);
        phi23s = phi23p;
    }
    else
    {
        mx_fresnel_conductor_phase_polarized(cosThetaT, eta2, eta3, kappa3, phi23p, phi23s);
    }
    vec3 r123p = max(sqrt(R12.x*R23p), 0.0);
    vec3 r123s = max(sqrt(R12.y*R23s), 0.0);

    // Iridescence term
    vec3 I = vec3(0.0);
    vec3 Cm, Sm;

    // Optical path difference
    float distMeters = fd.tf_thickness * 1.0e-9;
    float opd = 2.0 * eta2 * cosThetaT * distMeters;

    // Iridescence term using spectral antialiasing for Parallel polarization

    // Reflectance term for m=0 (DC term amplitude)
    vec3 Rs = (mx_square(T121.x) * R23p) / (vec3(1.0) - R12.x*R23p);
    I += R12.x + Rs;

    // Reflectance term for m>0 (pairs of diracs)
    Cm = Rs - T121.x;
    for (int m=1; m<=2; m++)
    {
        Cm *= r123p;
        Sm  = 2.0 * mx_eval_sensitivity(float(m) * opd, float(m)*(phi23p+vec3(phi21.x)));
        I  += Cm*Sm;
    }

    // Iridescence term using spectral antialiasing for Perpendicular polarization

    // Reflectance term for m=0 (DC term amplitude)
    vec3 Rp = (mx_square(T121.y) * R23s) / (vec3(1.0) - R12.y*R23s);
    I += R12.y + Rp;

    // Reflectance term for m>0 (pairs of diracs)
    Cm = Rp - T121.y;
    for (int m=1; m<=2; m++)
    {
        Cm *= r123s;
        Sm  = 2.0 * mx_eval_sensitivity(float(m) * opd, float(m)*(phi23s+vec3(phi21.y)));
        I  += Cm*Sm;
    }

    // Average parallel and perpendicular polarization
    I *= 0.5;

    // Convert back to RGB reflectance
    I = clamp(XYZ_TO_RGB * I, 0.0, 1.0);

    return I;
}

FresnelData mx_init_fresnel_dielectric(float ior, float tf_thickness, float tf_ior)
{
    FresnelData fd;
    fd.model = FRESNEL_MODEL_DIELECTRIC;
    fd.airy = tf_thickness > 0.0;
    fd.ior = vec3(ior);
    fd.extinction = vec3(0.0);
    fd.F0 = vec3(0.0);
    fd.F82 = vec3(0.0);
    fd.F90 = vec3(0.0);
    fd.exponent = 0.0;
    fd.tf_thickness = tf_thickness;
    fd.tf_ior = tf_ior;
    fd.refraction = false;
    return fd;
}

FresnelData mx_init_fresnel_conductor(vec3 ior, vec3 extinction, float tf_thickness, float tf_ior)
{
    FresnelData fd;
    fd.model = FRESNEL_MODEL_CONDUCTOR;
    fd.airy = tf_thickness > 0.0;
    fd.ior = ior;
    fd.extinction = extinction;
    fd.F0 = vec3(0.0);
    fd.F82 = vec3(0.0);
    fd.F90 = vec3(0.0);
    fd.exponent = 0.0;
    fd.tf_thickness = tf_thickness;
    fd.tf_ior = tf_ior;
    fd.refraction = false;
    return fd;
}

FresnelData mx_init_fresnel_schlick(vec3 F0, vec3 F82, vec3 F90, float exponent, float tf_thickness, float tf_ior)
{
    FresnelData fd;
    fd.model = FRESNEL_MODEL_SCHLICK;
    fd.airy = tf_thickness > 0.0;
    fd.ior = vec3(0.0);
    fd.extinction = vec3(0.0);
    fd.F0 = F0;
    fd.F82 = F82;
    fd.F90 = F90;
    fd.exponent = exponent;
    fd.tf_thickness = tf_thickness;
    fd.tf_ior = tf_ior;
    fd.refraction = false;
    return fd;
}

vec3 mx_compute_fresnel(float cosTheta, FresnelData fd)
{
    if (fd.airy)
    {
         return mx_fresnel_airy(cosTheta, fd);
    }
    else if (fd.model == FRESNEL_MODEL_DIELECTRIC)
    {
        return vec3(mx_fresnel_dielectric(cosTheta, fd.ior.x));
    }
    else if (fd.model == FRESNEL_MODEL_CONDUCTOR)
    {
        return mx_fresnel_conductor(cosTheta, fd.ior, fd.extinction);
    }
    else
    {
        return mx_fresnel_hoffman_schlick(cosTheta, fd);
    }
}

// Compute the refraction of a ray through a solid sphere.
vec3 mx_refraction_solid_sphere(vec3 R, vec3 N, float ior)
{
    R = refract(R, N, 1.0 / ior);
    vec3 N1 = normalize(R * dot(R, N) - N * 0.5);
    return refract(R, N1, ior);
}

vec2 mx_latlong_projection(vec3 dir)
{
    float latitude = -mx_asin(dir.y) * M_PI_INV + 0.5;
    float longitude = mx_atan(dir.x, -dir.z) * M_PI_INV * 0.5 + 0.5;
    return vec2(longitude, latitude);
}

vec3 mx_latlong_map_lookup(vec3 dir, mat4 transform, float lod, sampler2D envSampler)
{
    vec3 envDir = normalize((transform * vec4(dir,0.0)).xyz);
    vec2 uv = mx_latlong_projection(envDir);
    return textureLod(envSampler, uv, lod).rgb;
}

// Return the mip level with the appropriate coverage for a filtered importance sample.
// https://developer.nvidia.com/gpugems/GPUGems3/gpugems3_ch20.html
// Section 20.4 Equation 13
float mx_latlong_compute_lod(vec3 dir, float pdf, float maxMipLevel, int envSamples)
{
    const float MIP_LEVEL_OFFSET = 1.5;
    float effectiveMaxMipLevel = maxMipLevel - MIP_LEVEL_OFFSET;
    float distortion = sqrt(1.0 - mx_square(dir.y));
    return max(effectiveMaxMipLevel - 0.5 * log2(float(envSamples) * pdf * distortion), 0.0);
}

vec3 mx_environment_radiance(vec3 N, vec3 V, vec3 X, vec2 alpha, int distribution, FresnelData fd)
{
    // Generate tangent frame.
    X = normalize(X - dot(X, N) * N);
    vec3 Y = cross(N, X);
    mat3 tangentToWorld = mat3(X, Y, N);

    // Transform the view vector to tangent space.
    V = vec3(dot(V, X), dot(V, Y), dot(V, N));

    // Compute derived properties.
    float NdotV = clamp(V.z, M_FLOAT_EPS, 1.0);
    float avgAlpha = mx_average_alpha(alpha);
    float G1V = mx_ggx_smith_G1(NdotV, avgAlpha);
    
    // Integrate outgoing radiance using filtered importance sampling.
    // http://cgg.mff.cuni.cz/~jaroslav/papers/2008-egsr-fis/2008-egsr-fis-final-embedded.pdf
    vec3 radiance = vec3(0.0);
    int envRadianceSamples = u_envRadianceSamples;
    for (int i = 0; i < envRadianceSamples; i++)
    {
        vec2 Xi = mx_spherical_fibonacci(i, envRadianceSamples);

        // Compute the half vector and incoming light direction.
        vec3 H = mx_ggx_importance_sample_VNDF(Xi, V, alpha);
        vec3 L = fd.refraction ? mx_refraction_solid_sphere(-V, H, fd.ior.x) : -reflect(V, H);
        
        // Compute dot products for this sample.
        float NdotL = clamp(L.z, M_FLOAT_EPS, 1.0);
        float VdotH = clamp(dot(V, H), M_FLOAT_EPS, 1.0);

        // Sample the environment light from the given direction.
        vec3 Lw = tangentToWorld * L;
        float pdf = mx_ggx_NDF(H, alpha) * G1V / (4.0 * NdotV);
        float lod = mx_latlong_compute_lod(Lw, pdf, float(u_envRadianceMips - 1), envRadianceSamples);
        vec3 sampleColor = mx_latlong_map_lookup(Lw, u_envMatrix, lod, u_envRadiance);

        // Compute the Fresnel term.
        vec3 F = mx_compute_fresnel(VdotH, fd);

        // Compute the geometric term.
        float G = mx_ggx_smith_G2(NdotL, NdotV, avgAlpha);

        // Compute the combined FG term, which simplifies to inverted Fresnel for refraction.
        vec3 FG = fd.refraction ? vec3(1.0) - F : F * G;

        // Add the radiance contribution of this sample.
        // From https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf
        //   incidentLight = sampleColor * NdotL
        //   microfacetSpecular = D * F * G / (4 * NdotL * NdotV)
        //   pdf = D * G1V / (4 * NdotV);
        //   radiance = incidentLight * microfacetSpecular / pdf
        radiance += sampleColor * FG;
    }

    // Apply the global component of the geometric term and normalize.
    radiance /= G1V * float(envRadianceSamples);

    // Return the final radiance.
    return radiance * u_envLightIntensity;
}

vec3 mx_environment_irradiance(vec3 N)
{
    vec3 Li = mx_latlong_map_lookup(N, u_envMatrix, 0.0, u_envIrradiance);
    return Li * u_envLightIntensity;
}


vec3 mx_surface_transmission(vec3 N, vec3 V, vec3 X, vec2 alpha, int distribution, FresnelData fd, vec3 tint)
{
    // Approximate the appearance of surface transmission as glossy
    // environment map refraction, ignoring any scene geometry that might
    // be visible through the surface.
    fd.refraction = true;
    if (u_refractionTwoSided)
    {
        tint = mx_square(tint);
    }
    return mx_environment_radiance(N, V, X, alpha, distribution, fd) * tint;
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

void NG_convert_color3_vector3(vec3 in1, out vec3 out1)
{
    float separate_outr = 0.0;
    float separate_outg = 0.0;
    float separate_outb = 0.0;
    NG_separate3_color3(in1, separate_outr, separate_outg, separate_outb);
    vec3 combine_out = vec3(separate_outr,separate_outg,separate_outb);
    out1 = combine_out;
}

void NG_separate3_vector3(vec3 in1, out float outx, out float outy, out float outz)
{
    const int N_extract_0_index_tmp = 0;
    float N_extract_0_out = in1[N_extract_0_index_tmp];
    const int N_extract_1_index_tmp = 1;
    float N_extract_1_out = in1[N_extract_1_index_tmp];
    const int N_extract_2_index_tmp = 2;
    float N_extract_2_out = in1[N_extract_2_index_tmp];
    outx = N_extract_0_out;
    outy = N_extract_1_out;
    outz = N_extract_2_out;
}

void NG_convert_vector3_color3(vec3 in1, out vec3 out1)
{
    float separate_outx = 0.0;
    float separate_outy = 0.0;
    float separate_outz = 0.0;
    NG_separate3_vector3(in1, separate_outx, separate_outy, separate_outz);
    vec3 combine_out = vec3(separate_outx,separate_outy,separate_outz);
    out1 = combine_out;
}

void NG_acescg_to_lin_rec709_color3(vec3 in1, out vec3 out1)
{
    vec3 asVec_out = vec3(0.0);
    NG_convert_color3_vector3(in1, asVec_out);
    const mat3 transform_mat_tmp = mat3(1.705051, -0.130256, -0.024003, -0.621792, 1.140805, -0.128969, -0.083259, -0.010548, 1.152972);
    vec3 transform_out = transform_mat_tmp * asVec_out;
    vec3 asColor_out = vec3(0.0);
    NG_convert_vector3_color3(transform_out, asColor_out);
    out1 = asColor_out;
}

void mx_artistic_ior(vec3 reflectivity, vec3 edge_color, out vec3 ior, out vec3 extinction)
{
    // "Artist Friendly Metallic Fresnel", Ole Gulbrandsen, 2014
    // http://jcgt.org/published/0003/04/03/paper.pdf

    vec3 r = clamp(reflectivity, 0.0, 0.99);
    vec3 r_sqrt = sqrt(r);
    vec3 n_min = (1.0 - r) / (1.0 + r);
    vec3 n_max = (1.0 + r_sqrt) / (1.0 - r_sqrt);
    ior = mix(n_max, n_min, edge_color);

    vec3 np1 = ior + 1.0;
    vec3 nm1 = ior - 1.0;
    vec3 k2 = (np1*np1 * r - nm1*nm1) / (1.0 - r);
    k2 = max(k2, 0.0);
    extinction = sqrt(k2);
}

void NG_switch_color3I(vec3 in1, vec3 in2, vec3 in3, vec3 in4, vec3 in5, vec3 in6, vec3 in7, vec3 in8, vec3 in9, vec3 in10, int which, out vec3 out1)
{
    const int ifgreater_10_value1_tmp = 10;
    const vec3 ifgreater_10_in2_tmp = vec3(0.000000, 0.000000, 0.000000);
    vec3 ifgreater_10_out = (ifgreater_10_value1_tmp > which) ? in10 : ifgreater_10_in2_tmp;
    const int ifgreater_9_value1_tmp = 9;
    vec3 ifgreater_9_out = (ifgreater_9_value1_tmp > which) ? in9 : ifgreater_10_out;
    const int ifgreater_8_value1_tmp = 8;
    vec3 ifgreater_8_out = (ifgreater_8_value1_tmp > which) ? in8 : ifgreater_9_out;
    const int ifgreater_7_value1_tmp = 7;
    vec3 ifgreater_7_out = (ifgreater_7_value1_tmp > which) ? in7 : ifgreater_8_out;
    const int ifgreater_6_value1_tmp = 6;
    vec3 ifgreater_6_out = (ifgreater_6_value1_tmp > which) ? in6 : ifgreater_7_out;
    const int ifgreater_5_value1_tmp = 5;
    vec3 ifgreater_5_out = (ifgreater_5_value1_tmp > which) ? in5 : ifgreater_6_out;
    const int ifgreater_4_value1_tmp = 4;
    vec3 ifgreater_4_out = (ifgreater_4_value1_tmp > which) ? in4 : ifgreater_5_out;
    const int ifgreater_3_value1_tmp = 3;
    vec3 ifgreater_3_out = (ifgreater_3_value1_tmp > which) ? in3 : ifgreater_4_out;
    const int ifgreater_2_value1_tmp = 2;
    vec3 ifgreater_2_out = (ifgreater_2_value1_tmp > which) ? in2 : ifgreater_3_out;
    const int ifgreater_1_value1_tmp = 1;
    vec3 ifgreater_1_out = (ifgreater_1_value1_tmp > which) ? in1 : ifgreater_2_out;
    out1 = ifgreater_1_out;
}

mat4 mx_rotationMatrix(vec3 axis, float angle)
{
    axis = normalize(axis);
    float s = mx_sin(angle);
    float c = mx_cos(angle);
    float oc = 1.0 - c;

    return mat4(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0,
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0,
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0,
                0.0,                                0.0,                                0.0,                                1.0);
}

void mx_rotate_vector3(vec3 _in, float amount, vec3 axis, out vec3 result)
{
    float rotationRadians = mx_radians(amount);
    mat4 m = mx_rotationMatrix(axis, rotationRadians);
    result = (m * vec4(_in, 1.0)).xyz;
}

// These are defined based on the HwShaderGenerator::ClosureContextType enum
// if that changes - these need to be updated accordingly.

#define CLOSURE_TYPE_DEFAULT 0
#define CLOSURE_TYPE_REFLECTION 1
#define CLOSURE_TYPE_TRANSMISSION 2
#define CLOSURE_TYPE_INDIRECT 3
#define CLOSURE_TYPE_EMISSION 4

struct ClosureData {
    int closureType;
    vec3 L;
    vec3 V;
    vec3 N;
    vec3 P;
    float occlusion;
};

void mx_conductor_bsdf(ClosureData closureData, float weight, vec3 ior_n, vec3 ior_k, vec2 roughness, float thinfilm_thickness, float thinfilm_ior, vec3 N, vec3 X, int distribution, inout BSDF bsdf)
{
    bsdf.throughput = vec3(0.0);

    if (weight < M_FLOAT_EPS)
    {
        return;
    }

    vec3 V = closureData.V;
    vec3 L = closureData.L;
    float occlusion = closureData.occlusion;

    N = mx_forward_facing_normal(N, V);
    float NdotV = clamp(dot(N, V), M_FLOAT_EPS, 1.0);

    FresnelData fd = mx_init_fresnel_conductor(ior_n, ior_k, thinfilm_thickness, thinfilm_ior);

    vec2 safeAlpha = clamp(roughness, M_FLOAT_EPS, 1.0);
    float avgAlpha = mx_average_alpha(safeAlpha);

    if (closureData.closureType == CLOSURE_TYPE_REFLECTION)
    {
        X = normalize(X - dot(X, N) * N);
        vec3 Y = cross(N, X);
        vec3 H = normalize(L + V);

        float NdotL = clamp(dot(N, L), M_FLOAT_EPS, 1.0);
        float VdotH = clamp(dot(V, H), M_FLOAT_EPS, 1.0);

        vec3 Ht = vec3(dot(H, X), dot(H, Y), dot(H, N));

        vec3 F = mx_compute_fresnel(VdotH, fd);
        float D = mx_ggx_NDF(Ht, safeAlpha);
        float G = mx_ggx_smith_G2(NdotL, NdotV, avgAlpha);

        vec3 comp = mx_ggx_energy_compensation(NdotV, avgAlpha, F);

        // Note: NdotL is cancelled out
        bsdf.response = D * F * G * comp * occlusion * weight / (4.0 * NdotV);
    }
    else if (closureData.closureType == CLOSURE_TYPE_INDIRECT)
    {
        vec3 F = mx_compute_fresnel(NdotV, fd);
        vec3 comp = mx_ggx_energy_compensation(NdotV, avgAlpha, F);
        vec3 Li = mx_environment_radiance(N, V, X, safeAlpha, distribution, fd);
        bsdf.response = Li * comp * weight;
    }
}


void mx_multiply_bsdf_color3(ClosureData closureData, BSDF in1, vec3 in2, out BSDF result)
{
    vec3 tint = clamp(in2, 0.0, 1.0);
    result.response = in1.response * tint;
    result.throughput = in1.throughput * tint;
}

void IMPL_lama_conductor(ClosureData closureData, vec3 tint, int fresnelMode, vec3 IOR, vec3 extinction, vec3 reflectivity, vec3 edgeColor, float roughness, vec3 normal, float anisotropy, vec3 anisotropyDirection, float anisotropyRotation, out BSDF out1)
{
    vec3 artistic_ior_ior = vec3(0.0);
    vec3 artistic_ior_extinction = vec3(0.0);
    mx_artistic_ior(reflectivity, edgeColor, artistic_ior_ior, artistic_ior_extinction);
    vec3 convert_ior_out = vec3(0.0);
    NG_convert_vector3_color3(IOR, convert_ior_out);
    vec3 convert_extinction_out = vec3(0.0);
    NG_convert_vector3_color3(extinction, convert_extinction_out);
    const float roughness_inverse_in1_tmp = 1.000000;
    float roughness_inverse_out = roughness_inverse_in1_tmp - roughness;
    const float tangent_rotate_degree_in2_tmp = -360.000000;
    float tangent_rotate_degree_out = anisotropyRotation * tangent_rotate_degree_in2_tmp;
    vec3 eta_switch_out = vec3(0.0);
    NG_switch_color3I(artistic_ior_ior, convert_ior_out, vec3(0.000000, 0.000000, 0.000000), vec3(0.000000, 0.000000, 0.000000), vec3(0.000000, 0.000000, 0.000000), vec3(0.000000, 0.000000, 0.000000), vec3(0.000000, 0.000000, 0.000000), vec3(0.000000, 0.000000, 0.000000), vec3(0.000000, 0.000000, 0.000000), vec3(0.000000, 0.000000, 0.000000), fresnelMode, eta_switch_out);
    vec3 kappa_switch_out = vec3(0.0);
    NG_switch_color3I(artistic_ior_extinction, convert_extinction_out, vec3(0.000000, 0.000000, 0.000000), vec3(0.000000, 0.000000, 0.000000), vec3(0.000000, 0.000000, 0.000000), vec3(0.000000, 0.000000, 0.000000), vec3(0.000000, 0.000000, 0.000000), vec3(0.000000, 0.000000, 0.000000), vec3(0.000000, 0.000000, 0.000000), vec3(0.000000, 0.000000, 0.000000), fresnelMode, kappa_switch_out);
    const float delta_value2_tmp = 0.000000;
    float delta_out = (anisotropy >= delta_value2_tmp) ? roughness_inverse_out : roughness;
    vec3 tangent_rotate_out = vec3(0.0);
    mx_rotate_vector3(anisotropyDirection, tangent_rotate_degree_out, normal, tangent_rotate_out);
    float roughness_additional_out = anisotropy * delta_out;
    vec3 tangent_rotate_normalize_out = normalize(tangent_rotate_out);
    float roughness_bitangent_out = roughness + roughness_additional_out;
    const float roughness_bitangent_clamped_low_tmp = 0.000000;
    const float roughness_bitangent_clamped_high_tmp = 1.000000;
    float roughness_bitangent_clamped_out = clamp(roughness_bitangent_out, roughness_bitangent_clamped_low_tmp, roughness_bitangent_clamped_high_tmp);
    vec2 roughness_linear_out = vec2(roughness,roughness_bitangent_clamped_out);
    const float roughness_anisotropic_squared_in2_tmp = 2.000000;
    vec2 roughness_anisotropic_squared_out = pow(roughness_linear_out, vec2(roughness_anisotropic_squared_in2_tmp));
    const float roughness_anisotropic_squared_clamped_in2_tmp = 0.000001;
    vec2 roughness_anisotropic_squared_clamped_out = max(roughness_anisotropic_squared_out, roughness_anisotropic_squared_clamped_in2_tmp);
    BSDF conductor_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
    mx_conductor_bsdf(closureData, 1.000000, eta_switch_out, kappa_switch_out, roughness_anisotropic_squared_clamped_out, 0.000000, 1.500000, normal, tangent_rotate_normalize_out, 0, conductor_bsdf_out);
    BSDF tinted_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
    mx_multiply_bsdf_color3(closureData, conductor_bsdf_out, tint, tinted_bsdf_out);
    out1 = tinted_bsdf_out;
}

void NG_convert_float_color3(float in1, out vec3 out1)
{
    vec3 combine_out = vec3(in1,in1,in1);
    out1 = combine_out;
}


void mx_anisotropic_vdf(ClosureData closureData, vec3 absorption, vec3 scattering, float anisotropy, inout BSDF bsdf)
{
    // TODO: Add some approximation for volumetric light absorption.
}

void NG_switch_floatI(float in1, float in2, float in3, float in4, float in5, float in6, float in7, float in8, float in9, float in10, int which, out float out1)
{
    const int ifgreater_10_value1_tmp = 10;
    const float ifgreater_10_in2_tmp = 0.000000;
    float ifgreater_10_out = (ifgreater_10_value1_tmp > which) ? in10 : ifgreater_10_in2_tmp;
    const int ifgreater_9_value1_tmp = 9;
    float ifgreater_9_out = (ifgreater_9_value1_tmp > which) ? in9 : ifgreater_10_out;
    const int ifgreater_8_value1_tmp = 8;
    float ifgreater_8_out = (ifgreater_8_value1_tmp > which) ? in8 : ifgreater_9_out;
    const int ifgreater_7_value1_tmp = 7;
    float ifgreater_7_out = (ifgreater_7_value1_tmp > which) ? in7 : ifgreater_8_out;
    const int ifgreater_6_value1_tmp = 6;
    float ifgreater_6_out = (ifgreater_6_value1_tmp > which) ? in6 : ifgreater_7_out;
    const int ifgreater_5_value1_tmp = 5;
    float ifgreater_5_out = (ifgreater_5_value1_tmp > which) ? in5 : ifgreater_6_out;
    const int ifgreater_4_value1_tmp = 4;
    float ifgreater_4_out = (ifgreater_4_value1_tmp > which) ? in4 : ifgreater_5_out;
    const int ifgreater_3_value1_tmp = 3;
    float ifgreater_3_out = (ifgreater_3_value1_tmp > which) ? in3 : ifgreater_4_out;
    const int ifgreater_2_value1_tmp = 2;
    float ifgreater_2_out = (ifgreater_2_value1_tmp > which) ? in2 : ifgreater_3_out;
    const int ifgreater_1_value1_tmp = 1;
    float ifgreater_1_out = (ifgreater_1_value1_tmp > which) ? in1 : ifgreater_2_out;
    out1 = ifgreater_1_out;
}


void mx_dielectric_bsdf(ClosureData closureData, float weight, vec3 tint, float ior, vec2 roughness, float thinfilm_thickness, float thinfilm_ior, vec3 N, vec3 X, int distribution, int scatter_mode, inout BSDF bsdf)
{
    if (weight < M_FLOAT_EPS)
    {
        return;
    }
    if (closureData.closureType != CLOSURE_TYPE_TRANSMISSION && scatter_mode == 1)
    {
        return;
    }

    vec3 V = closureData.V;
    vec3 L = closureData.L;
    float occlusion = closureData.occlusion;

    N = mx_forward_facing_normal(N, V);
    float NdotV = clamp(dot(N, V), M_FLOAT_EPS, 1.0);

    FresnelData fd = mx_init_fresnel_dielectric(ior, thinfilm_thickness, thinfilm_ior);
    float F0 = mx_ior_to_f0(ior);

    vec2 safeAlpha = clamp(roughness, M_FLOAT_EPS, 1.0);
    float avgAlpha = mx_average_alpha(safeAlpha);
    vec3 safeTint = max(tint, 0.0);

    if (closureData.closureType == CLOSURE_TYPE_REFLECTION)
    {
        X = normalize(X - dot(X, N) * N);
        vec3 Y = cross(N, X);
        vec3 H = normalize(L + V);

        float NdotL = clamp(dot(N, L), M_FLOAT_EPS, 1.0);
        float VdotH = clamp(dot(V, H), M_FLOAT_EPS, 1.0);

        vec3 Ht = vec3(dot(H, X), dot(H, Y), dot(H, N));

        vec3 F = mx_compute_fresnel(VdotH, fd);
        float D = mx_ggx_NDF(Ht, safeAlpha);
        float G = mx_ggx_smith_G2(NdotL, NdotV, avgAlpha);

        vec3 comp = mx_ggx_energy_compensation(NdotV, avgAlpha, F);
        vec3 dirAlbedo = mx_ggx_dir_albedo(NdotV, avgAlpha, F0, 1.0) * comp;
        bsdf.throughput = 1.0 - dirAlbedo * weight;

        bsdf.response = D * F * G * comp * safeTint * occlusion * weight / (4.0 * NdotV);
    }
    else if (closureData.closureType == CLOSURE_TYPE_TRANSMISSION)
    {
        vec3 F = mx_compute_fresnel(NdotV, fd);

        vec3 comp = mx_ggx_energy_compensation(NdotV, avgAlpha, F);
        vec3 dirAlbedo = mx_ggx_dir_albedo(NdotV, avgAlpha, F0, 1.0) * comp;
        bsdf.throughput = 1.0 - dirAlbedo * weight;

        if (scatter_mode != 0)
        {
            bsdf.response = mx_surface_transmission(N, V, X, safeAlpha, distribution, fd, safeTint) * weight;
        }
    }
    else if (closureData.closureType == CLOSURE_TYPE_INDIRECT)
    {
        vec3 F = mx_compute_fresnel(NdotV, fd);

        vec3 comp = mx_ggx_energy_compensation(NdotV, avgAlpha, F);
        vec3 dirAlbedo = mx_ggx_dir_albedo(NdotV, avgAlpha, F0, 1.0) * comp;
        bsdf.throughput = 1.0 - dirAlbedo * weight;

        vec3 Li = mx_environment_radiance(N, V, X, safeAlpha, distribution, fd);
        bsdf.response = Li * safeTint * comp * weight;
    }
}


void mx_layer_vdf(ClosureData closureData, BSDF top, BSDF base, out BSDF result)
{
    result.response = top.response + base.response;
    result.throughput = top.throughput + base.throughput;
}


void mx_layer_bsdf(ClosureData closureData, BSDF top, BSDF base, out BSDF result)
{
    result.response = top.response + base.response * top.throughput;
    result.throughput = top.throughput + base.throughput;
}

void IMPL_lama_dielectric(ClosureData closureData, vec3 reflectionTint, vec3 transmissionTint, int fresnelMode, float IOR, float reflectivity, float roughness, vec3 normal, float anisotropy, vec3 direction, float rotation, vec3 absorptionColor, float absorptionRadius, vec3 scatterColor, float scatterAnisotropy, out BSDF out1)
{
    vec3 reflectivity_color_out = vec3(0.0);
    NG_convert_float_color3(reflectivity, reflectivity_color_out);
    const float roughness_inverse_in1_tmp = 1.000000;
    float roughness_inverse_out = roughness_inverse_in1_tmp - roughness;
    const float tangent_rotate_degree_in2_tmp = -360.000000;
    float tangent_rotate_degree_out = rotation * tangent_rotate_degree_in2_tmp;
    vec3 absorption_out = absorptionColor / absorptionRadius;
    vec3 scatter_vector_out = vec3(0.0);
    NG_convert_color3_vector3(scatterColor, scatter_vector_out);
    vec3 artistic_ior_edge_color_cm_out = vec3(0.0);
    NG_acescg_to_lin_rec709_color3(vec3(0.000000, 0.000000, 0.000000), artistic_ior_edge_color_cm_out);
    const float delta_value2_tmp = 0.000000;
    float delta_out = (anisotropy >= delta_value2_tmp) ? roughness_inverse_out : roughness;
    const float tangent_rotate_degree_offset_in2_tmp = 0.000000;
    float tangent_rotate_degree_offset_out = tangent_rotate_degree_out - tangent_rotate_degree_offset_in2_tmp;
    vec3 absorption_vector_out = vec3(0.0);
    NG_convert_color3_vector3(absorption_out, absorption_vector_out);
    vec3 artistic_ior_ior = vec3(0.0);
    vec3 artistic_ior_extinction = vec3(0.0);
    mx_artistic_ior(reflectivity_color_out, artistic_ior_edge_color_cm_out, artistic_ior_ior, artistic_ior_extinction);
    float roughness_additional_out = anisotropy * delta_out;
    vec3 tangent_rotate_out = vec3(0.0);
    mx_rotate_vector3(direction, tangent_rotate_degree_offset_out, normal, tangent_rotate_out);
    const int ior_float_index_tmp = 0;
    float ior_float_out = artistic_ior_ior[ior_float_index_tmp];
    float roughness_bitangent_out = roughness + roughness_additional_out;
    vec3 tangent_rotate_normalize_out = normalize(tangent_rotate_out);
    float fresnel_mode_switch_out = 0.0;
    NG_switch_floatI(ior_float_out, IOR, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, fresnelMode, fresnel_mode_switch_out);
    const float roughness_bitangent_clamped_low_tmp = 0.000000;
    const float roughness_bitangent_clamped_high_tmp = 1.000000;
    float roughness_bitangent_clamped_out = clamp(roughness_bitangent_out, roughness_bitangent_clamped_low_tmp, roughness_bitangent_clamped_high_tmp);
    vec2 roughness_linear_out = vec2(roughness,roughness_bitangent_clamped_out);
    const float roughness_anisotropic_squared_in2_tmp = 2.000000;
    vec2 roughness_anisotropic_squared_out = pow(roughness_linear_out, vec2(roughness_anisotropic_squared_in2_tmp));
    const float roughness_anisotropic_squared_clamped_in2_tmp = 0.000001;
    vec2 roughness_anisotropic_squared_clamped_out = max(roughness_anisotropic_squared_out, roughness_anisotropic_squared_clamped_in2_tmp);
    BSDF reflection_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
    mx_dielectric_bsdf(closureData, 1.000000, reflectionTint, fresnel_mode_switch_out, roughness_anisotropic_squared_clamped_out, 0.000000, 1.500000, normal, tangent_rotate_normalize_out, 0, 0, reflection_bsdf_out);
    BSDF transmission_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
    mx_dielectric_bsdf(closureData, 1.000000, transmissionTint, fresnel_mode_switch_out, roughness_anisotropic_squared_clamped_out, 0.000000, 1.500000, normal, tangent_rotate_normalize_out, 0, 1, transmission_bsdf_out);
    BSDF interior_vdf_out = BSDF(vec3(0.0),vec3(1.0));
    mx_anisotropic_vdf(closureData, absorption_vector_out, scatter_vector_out, scatterAnisotropy, interior_vdf_out);
    BSDF transmission_layer_out = BSDF(vec3(0.0),vec3(1.0));
    mx_layer_vdf(closureData, transmission_bsdf_out, interior_vdf_out, transmission_layer_out);
    BSDF dielectric_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
    mx_layer_bsdf(closureData, reflection_bsdf_out, transmission_layer_out, dielectric_bsdf_out);
    out1 = dielectric_bsdf_out;
}


void mx_multiply_bsdf_float(ClosureData closureData, BSDF in1, float in2, out BSDF result)
{
    float weight = clamp(in2, 0.0, 1.0);
    result.response = in1.response * weight;
    result.throughput = in1.throughput * weight;
}


void mx_add_bsdf(ClosureData closureData, BSDF in1, BSDF in2, out BSDF result)
{
    result.response = in1.response + in2.response;
    result.throughput = in1.throughput + in2.throughput;
}

void NG_lama_add_bsdf(ClosureData closureData, BSDF material1, BSDF material2, float weight1, float weight2, out BSDF out1)
{
    BSDF mul1_out = BSDF(vec3(0.0),vec3(1.0));
    mx_multiply_bsdf_float(closureData, material1, weight1, mul1_out);
    BSDF mul2_out = BSDF(vec3(0.0),vec3(1.0));
    mx_multiply_bsdf_float(closureData, material2, weight2, mul2_out);
    BSDF add1_out = BSDF(vec3(0.0),vec3(1.0));
    mx_add_bsdf(closureData, mul1_out, mul2_out, add1_out);
    out1 = add1_out;
}

void main()
{
    vec3 geomprop_Nworld_out1 = normalize(vd.normalWorld);
    vec3 geomprop_Tworld_out1 = normalize(vd.tangentWorld);
    vec3 LamaDielectric_scatterColor_cm_out = vec3(0.0);
    NG_acescg_to_lin_rec709_color3(LamaDielectric_scatterColor_cm_in, LamaDielectric_scatterColor_cm_out);
    vec3 LamaConductor_tint_cm_out = vec3(0.0);
    NG_acescg_to_lin_rec709_color3(LamaConductor_tint_cm_in, LamaConductor_tint_cm_out);
    vec3 LamaConductor_reflectivity_cm_out = vec3(0.0);
    NG_acescg_to_lin_rec709_color3(LamaConductor_reflectivity_cm_in, LamaConductor_reflectivity_cm_out);
    vec3 LamaConductor_edgeColor_cm_out = vec3(0.0);
    NG_acescg_to_lin_rec709_color3(LamaConductor_edgeColor_cm_in, LamaConductor_edgeColor_cm_out);
    vec3 LamaDielectric_transmissionTint_cm_out = vec3(0.0);
    NG_acescg_to_lin_rec709_color3(LamaDielectric_transmissionTint_cm_in, LamaDielectric_transmissionTint_cm_out);
    vec3 LamaDielectric_reflectionTint_cm_out = vec3(0.0);
    NG_acescg_to_lin_rec709_color3(LamaDielectric_reflectionTint_cm_in, LamaDielectric_reflectionTint_cm_out);
    vec3 LamaDielectric_absorptionColor_cm_out = vec3(0.0);
    NG_acescg_to_lin_rec709_color3(LamaDielectric_absorptionColor_cm_in, LamaDielectric_absorptionColor_cm_out);
    surfaceshader LamaAddBSDFSurface_out = surfaceshader(vec3(0.0),vec3(0.0));
    {
        vec3 N = normalize(vd.normalWorld);
        vec3 V = normalize(u_viewPosition - vd.positionWorld);
        vec3 P = vd.positionWorld;
        vec3 L = vec3(0,0,0);;
        float occlusion = 1.0;

        float surfaceOpacity = LamaAddBSDFSurface_opacity;

        // Shadow occlusion

        // Ambient occlusion
        occlusion = 1.0;

        // Add environment contribution
        {
            ClosureData closureData = ClosureData(CLOSURE_TYPE_INDIRECT, L, V, N, P, occlusion);
            BSDF LamaConductor_out = BSDF(vec3(0.0),vec3(1.0));
            IMPL_lama_conductor(closureData, LamaConductor_tint_cm_out, LamaConductor_fresnelMode, LamaConductor_IOR, LamaConductor_extinction, LamaConductor_reflectivity_cm_out, LamaConductor_edgeColor_cm_out, LamaConductor_roughness, geomprop_Nworld_out1, LamaConductor_anisotropy, geomprop_Tworld_out1, LamaConductor_anisotropyRotation, LamaConductor_out);
            BSDF LamaDielectric_out = BSDF(vec3(0.0),vec3(1.0));
            IMPL_lama_dielectric(closureData, LamaDielectric_reflectionTint_cm_out, LamaDielectric_transmissionTint_cm_out, LamaDielectric_fresnelMode, LamaDielectric_IOR, LamaDielectric_reflectivity, LamaDielectric_roughness, geomprop_Nworld_out1, LamaDielectric_anisotropy, geomprop_Tworld_out1, LamaDielectric_rotation, LamaDielectric_absorptionColor_cm_out, LamaDielectric_absorptionRadius, LamaDielectric_scatterColor_cm_out, LamaDielectric_scatterAnisotropy, LamaDielectric_out);
            BSDF LamaAddBSDF_out = BSDF(vec3(0.0),vec3(1.0));
            NG_lama_add_bsdf(closureData, LamaConductor_out, LamaDielectric_out, LamaAddBSDF_weight1, LamaAddBSDF_weight2, LamaAddBSDF_out);

            LamaAddBSDFSurface_out.color += occlusion * LamaAddBSDF_out.response;
        }

        // Calculate the BSDF transmission for viewing direction
        ClosureData closureData = ClosureData(CLOSURE_TYPE_TRANSMISSION, L, V, N, P, occlusion);
        BSDF LamaConductor_out = BSDF(vec3(0.0),vec3(1.0));
        IMPL_lama_conductor(closureData, LamaConductor_tint_cm_out, LamaConductor_fresnelMode, LamaConductor_IOR, LamaConductor_extinction, LamaConductor_reflectivity_cm_out, LamaConductor_edgeColor_cm_out, LamaConductor_roughness, geomprop_Nworld_out1, LamaConductor_anisotropy, geomprop_Tworld_out1, LamaConductor_anisotropyRotation, LamaConductor_out);
        BSDF LamaDielectric_out = BSDF(vec3(0.0),vec3(1.0));
        IMPL_lama_dielectric(closureData, LamaDielectric_reflectionTint_cm_out, LamaDielectric_transmissionTint_cm_out, LamaDielectric_fresnelMode, LamaDielectric_IOR, LamaDielectric_reflectivity, LamaDielectric_roughness, geomprop_Nworld_out1, LamaDielectric_anisotropy, geomprop_Tworld_out1, LamaDielectric_rotation, LamaDielectric_absorptionColor_cm_out, LamaDielectric_absorptionRadius, LamaDielectric_scatterColor_cm_out, LamaDielectric_scatterAnisotropy, LamaDielectric_out);
        BSDF LamaAddBSDF_out = BSDF(vec3(0.0),vec3(1.0));
        NG_lama_add_bsdf(closureData, LamaConductor_out, LamaDielectric_out, LamaAddBSDF_weight1, LamaAddBSDF_weight2, LamaAddBSDF_out);
        LamaAddBSDFSurface_out.color += LamaAddBSDF_out.response;

        // Compute and apply surface opacity
        {
            LamaAddBSDFSurface_out.color *= surfaceOpacity;
            LamaAddBSDFSurface_out.transparency = mix(vec3(1.0), LamaAddBSDFSurface_out.transparency, surfaceOpacity);
        }
    }

    material LamaAddBSDFTest_out = LamaAddBSDFSurface_out;
    out1 = vec4(LamaAddBSDFTest_out.color, 1.0);
}

