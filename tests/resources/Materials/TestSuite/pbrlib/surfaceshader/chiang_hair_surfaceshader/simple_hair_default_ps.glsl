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
uniform float SR_default_melaninConcentration = 0.500000;
uniform float SR_default_melaninRedness = 0.500000;
uniform float SR_default_melaninMix = 1.000000;
uniform vec3 SR_default_baseColor = vec3(1.000000, 1.000000, 1.000000);
uniform float SR_default_longitudinalRoughness = 0.100000;
uniform float SR_default_azimuthalRoughness = 0.100000;
uniform float SR_default_cuticleAngle = 0.500000;
uniform vec3 SR_default_tint_R = vec3(1.000000, 1.000000, 1.000000);
uniform vec3 SR_default_tint_TT = vec3(1.000000, 1.000000, 1.000000);
uniform vec3 SR_default_tint_TRT = vec3(1.000000, 1.000000, 1.000000);
uniform float SR_default_ior = 1.550000;

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

// https://eugenedeon.com/pdfs/egsrhair.pdf
void mx_deon_hair_absorption_from_melanin(
    float melanin_concentration,
    float melanin_redness,
    // constants converted to color via exp(-c). the defaults are lin_rec709 colors, they may be
    // transformed to scene-linear rendering color space.
    vec3 eumelanin_color,    // default: (0.657704, 0.498077, 0.254106) == exp(-(0.419, 0.697, 1.37))
    vec3 pheomelanin_color,  // default: (0.829443, 0.670320, 0.349937) == exp(-(0.187, 0.4, 1.05))
    out vec3 absorption)
{
    float melanin = -log(max(1.0 - melanin_concentration, 0.0001));
    float eumelanin = melanin * (1.0 - melanin_redness);
    float pheomelanin = melanin * melanin_redness;
    absorption = max(
        eumelanin * -log(eumelanin_color) + pheomelanin * -log(pheomelanin_color), 
        vec3(0.0)
    );
}

// https://media.disneyanimation.com/uploads/production/publication_asset/152/asset/eurographics2016Fur_Smaller.pdf
void mx_chiang_hair_absorption_from_color(vec3 color, float betaN, out vec3 absorption)
{
    float b2 = betaN* betaN;
    float b4 = b2 * b2;
    float b_fac = 
        5.969 - 
        (0.215 * betaN) + 
        (2.532 * b2) -
        (10.73 * b2 * betaN) + 
        (5.574 * b4) +
        (0.245 * b4 * betaN);
    vec3 sigma = log(min(max(color, 0.001), vec3(1.0))) / b_fac;
    absorption = sigma * sigma;
}

void mx_chiang_hair_roughness(
    float longitudinal,
    float azimuthal,
    float scale_TT,   // empirical roughness scale from Marschner et al. (2003).
    float scale_TRT,  // default: scale_TT = 0.5, scale_TRT = 2.0
    out vec2 roughness_R,
    out vec2 roughness_TT,
    out vec2 roughness_TRT
)
{
    float lr = clamp(longitudinal, 0.001, 1.0);
    float ar = clamp(azimuthal, 0.001, 1.0);

    // longitudinal variance
    float v = 0.726 * lr + 0.812 * lr * lr + 3.7 * pow(lr, 20.0);
    v = v * v;

    float s = 0.265 * ar + 1.194 * ar * ar + 5.372 * pow(ar, 22.0);

    roughness_R = vec2(v, s);
    roughness_TT = vec2(v * scale_TT * scale_TT, s);
    roughness_TRT = vec2(v * scale_TRT * scale_TRT, s);
}

float mx_hair_transform_sin_cos(float x)
{
    return sqrt(max(1.0 - x * x, 0.0));
}

float mx_hair_I0(float x)
{
    float v = 1.0;
    float n = 1.0;
    float d = 1.0;
    float f = 1.0;
    float x2 = x * x;
    for (int i = 0; i < 9 ; ++i)
    {
        d *= 4.0 * (f * f);
        n *= x2;
        v += n / d;
        f += 1.0;
    }
    return v;
}

float mx_hair_log_I0(float x)
{
    if (x > 12.0)
        return x + 0.5 * (-log(2.0 * M_PI) + log(1.0 / x) + 1.0 / (8.0 * x));
    else
        return log(mx_hair_I0(x));
}

float mx_hair_logistic(float x, float s)
{
    if (x > 0.0)
        x = -x;
    float f = exp(x / s);
    return f / (s * (1.0 + f) * (1.0 + f));
}

float mx_hair_logistic_cdf(float x, float s)
{
    return 1.0 / (1.0 + exp(-x / s));
}

float mx_hair_trimmed_logistic(float x, float s, float a, float b)
{
    // the constant can be found in Chiang et al. (2016) Appendix A, eq. (12)
    s *= 0.626657;  // sqrt(M_PI/8)
    return mx_hair_logistic(x, s) / (mx_hair_logistic_cdf(b, s) - mx_hair_logistic_cdf(a, s));
}

float mx_hair_phi(int p, float gammaO, float gammaT)
{
    float fP = float(p);
    return 2.0 * fP * gammaT - 2.0 * gammaO + fP * M_PI;
}

float mx_hair_longitudinal_scattering(  // Mp
    float sinThetaI,
    float cosThetaI,
    float sinThetaO,
    float cosThetaO,
    float v
)
{
    float inv_v = 1.0 / v;
    float a = cosThetaO * cosThetaI * inv_v;
    float b = sinThetaO * sinThetaI * inv_v;
    if (v < 0.1)
        return exp(mx_hair_log_I0(a) - b - inv_v + 0.6931 + log(0.5 * inv_v));
    else
        return ((exp(-b) * mx_hair_I0(a)) / (2.0 * v * sinh(inv_v)));
}

float mx_hair_azimuthal_scattering(  // Np
    float phi,
    int p,
    float s,
    float gammaO,
    float gammaT
)
{
    if (p >= 3)
        return float(0.5 / M_PI);

    float dphi = phi - mx_hair_phi(p, gammaO, gammaT);
    if (isinf(dphi))
        return float(0.5 / M_PI);

    while (dphi > M_PI)    dphi -= (2.0 * M_PI);
    while (dphi < (-M_PI)) dphi += (2.0 * M_PI);

    return mx_hair_trimmed_logistic(dphi, s, -M_PI, M_PI);
}

void mx_hair_alpha_angles(
    float alpha,
    float sinThetaI,
    float cosThetaI,
    out vec2 angles[4]
)
{
    // 0:R, 1:TT, 2:TRT, 3:TRRT+
    for (int i = 0; i <= 3; ++i)
    {
        if (alpha == 0.0 || i == 3)
            angles[i] = vec2(sinThetaI, cosThetaI);
        else
        {
            float m = 2.0 - float(i) * 3.0;
            float sa = sin(m * alpha);
            float ca = cos(m * alpha);
            angles[i].x = sinThetaI * ca + cosThetaI * sa;
            angles[i].y = cosThetaI * ca - sinThetaI * sa;
        }
    }
}

void mx_hair_attenuation(float f, vec3 T, out vec3 Ap[4])  // Ap
{
    // 0:R, 1:TT, 2:TRT, 3:TRRT+
    Ap[0] = vec3(f);
    Ap[1] = (1.0 - f) * (1.0 - f) * T;
    Ap[2] = Ap[1] * T * f;
    Ap[3] = Ap[2] * T * f / (vec3(1.0) - T * f);
}

vec3 mx_chiang_hair_bsdf_impl(
    vec3 L,
    vec3 V,
    vec3 tint_R,
    vec3 tint_TT,
    vec3 tint_TRT,
    float ior,
    vec2 roughness_R,
    vec2 roughness_TT,
    vec2 roughness_TRT,
    float cuticle_angle,
    vec3 absorption_coefficient,
    vec3 N,
    vec3 X
)
{
    N = mx_forward_facing_normal(N, V);
    X = normalize(X - dot(X, N) * N);
    vec3 Y = cross(N, X);

    float sinThetaO = dot(V, X);
    float sinThetaI = dot(L, X);
    float cosThetaO = mx_hair_transform_sin_cos(sinThetaO);
    float cosThetaI = mx_hair_transform_sin_cos(sinThetaI);

    float y1 = dot(L, N);
    float x1 = dot(L, Y);
    float y2 = dot(V, N);
    float x2 = dot(V, Y);
    float phi = mx_atan(y1 * x2 - y2 * x1, x1 * x2 + y1 * y2);

    vec3 k1_p = normalize(V - X * dot(V, X));
    float cosGammaO = dot(N, k1_p);
    float sinGammaO = mx_hair_transform_sin_cos(cosGammaO);
    if (dot(k1_p, Y) > 0.0)
        sinGammaO = -sinGammaO;
    float gammaO = asin(sinGammaO);

    float sinThetaT = sinThetaO / ior;
    float cosThetaT = mx_hair_transform_sin_cos(sinThetaT);
    float etaP = sqrt(max(ior * ior - sinThetaO * sinThetaO, 0.0)) / max(cosThetaO, 1e-8);
    float sinGammaT = max(min(sinGammaO / etaP, 1.0), -1.0);
    float cosGammaT = sqrt(1.0 - sinGammaT * sinGammaT);
    float gammaT = asin(sinGammaT);

    // attenuation
    vec3 Ap[4];
    float fresnel = mx_fresnel_dielectric(cosThetaO * cosGammaO, ior);
    vec3 T = exp(-absorption_coefficient * (2.0 * cosGammaT / cosThetaT));
    mx_hair_attenuation(fresnel, T, Ap);

    // parameters for each lobe
    vec2 angles[4];
    float alpha = cuticle_angle * M_PI - (M_PI / 2.0);  // remap [0, 1] to [-PI/2, PI/2]
    mx_hair_alpha_angles(alpha, sinThetaI, cosThetaI, angles);

    vec3 tint[4];
    tint[0] = tint_R;
    tint[1] = tint_TT;
    tint[2] = tint_TRT;
    tint[3] = tint_TRT;

    roughness_R = clamp(roughness_R, 0.001, 1.0);
    roughness_TT = clamp(roughness_TT, 0.001, 1.0);
    roughness_TRT = clamp(roughness_TRT, 0.001, 1.0);

    vec2 vs[4];
    vs[0] = roughness_R;
    vs[1] = roughness_TT;
    vs[2] = roughness_TRT;
    vs[3] = roughness_TRT;

    // R, TT, TRT, TRRT+
    vec3 F = vec3(0.0);
    for (int i = 0; i <= 3; ++i)
    {
        tint[i] = max(tint[i], vec3(0.0));
        float Mp = mx_hair_longitudinal_scattering(angles[i].x, angles[i].y, sinThetaO, cosThetaO, vs[i].x);
        float Np = (i == 3) ?  (1.0 / 2.0 * M_PI) : mx_hair_azimuthal_scattering(phi, i, vs[i].y, gammaO, gammaT);
        F += Mp * Np * tint[i] * Ap[i];
    }

    return F;
}

void mx_chiang_hair_bsdf_reflection(
    vec3 L,
    vec3 V,
    vec3 P,
    float occlusion,
    vec3 tint_R,
    vec3 tint_TT,
    vec3 tint_TRT,
    float ior,
    vec2 roughness_R,
    vec2 roughness_TT,
    vec2 roughness_TRT,
    float cuticle_angle,
    vec3 absorption_coefficient,
    vec3 N,
    vec3 X,
    inout BSDF bsdf
)
{
    vec3 F = mx_chiang_hair_bsdf_impl(
        L,
        V,
        tint_R,
        tint_TT,
        tint_TRT,
        ior,
        roughness_R,
        roughness_TT,
        roughness_TRT,
        cuticle_angle,
        absorption_coefficient,
        N,
        X
    );

    bsdf.throughput = vec3(0.0);
    bsdf.response = F * occlusion * M_PI_INV;
}

void mx_chiang_hair_bsdf_indirect(
    vec3 V,
    vec3 tint_R,
    vec3 tint_TT,
    vec3 tint_TRT,
    float ior,
    vec2 roughness_R,
    vec2 roughness_TT,
    vec2 roughness_TRT,
    float cuticle_angle,
    vec3 absorption_coefficient,
    vec3 N,
    vec3 X,
    inout BSDF bsdf
)
{
    // this indirect lighting is *very* rough approximation

    N = mx_forward_facing_normal(N, V);

    float NdotV = clamp(dot(N, V), M_FLOAT_EPS, 1.0);

    FresnelData fd = mx_init_fresnel_dielectric(ior, 0.0, 1.0);
    vec3 F = mx_compute_fresnel(NdotV, fd);

    vec2 roughness = (roughness_R + roughness_TT + roughness_TRT) / vec2(3.0);  // ?
    vec2 safeAlpha = clamp(roughness, M_FLOAT_EPS, 1.0);
    float avgAlpha = mx_average_alpha(safeAlpha);

    // use ggx because the environment map for FIS is preintegrated with ggx
    float F0 = mx_ior_to_f0(ior);
    vec3 comp = mx_ggx_energy_compensation(NdotV, avgAlpha, F);
    vec3 dirAlbedo = mx_ggx_dir_albedo(NdotV, avgAlpha, F0, 1.0) * comp;

    vec3 Li = mx_environment_radiance(N, V, X, safeAlpha, 0, fd);
    vec3 tint = (tint_R + tint_TT + tint_TRT) / vec3(3.0);  // ?

    bsdf.throughput = vec3(0.0);
    bsdf.response = Li * comp * tint;
}

void mx_chiang_hair_bsdf(
    ClosureData closureData,
    vec3 tint_R,
    vec3 tint_TT,
    vec3 tint_TRT,
    float ior,
    vec2 roughness_R,
    vec2 roughness_TT,
    vec2 roughness_TRT,
    float cuticle_angle,
    vec3 absorption_coefficient,
    vec3 N,
    vec3 X,
    inout BSDF bsdf
)
{
    if (closureData.closureType == CLOSURE_TYPE_REFLECTION)
    {
        mx_chiang_hair_bsdf_reflection(closureData.L, closureData.V, closureData.P, closureData.occlusion, tint_R, tint_TT, tint_TRT, ior, roughness_R, roughness_TT, roughness_TRT, cuticle_angle, absorption_coefficient, N, X, bsdf);
    }
    else if (closureData.closureType == CLOSURE_TYPE_INDIRECT)
    {
        mx_chiang_hair_bsdf_indirect(closureData.V, tint_R, tint_TT, tint_TRT, ior, roughness_R, roughness_TT, roughness_TRT, cuticle_angle, absorption_coefficient, N, X, bsdf);
    }
}

void NG_simple_hair_shader(float melaninConcentration, float melaninRedness, float melaninMix, vec3 baseColor, float longitudinalRoughness, float azimuthalRoughness, float cuticleAngle, vec3 tint_R, vec3 tint_TT, vec3 tint_TRT, float ior, out surfaceshader out1)
{
    vec3 geomprop_Nworld_out1 = normalize(vd.normalWorld);
    vec3 geomprop_Tworld_out1 = normalize(vd.tangentWorld);
    vec2 spec_roughness_roughness_R = vec2(0.0);
    vec2 spec_roughness_roughness_TT = vec2(0.0);
    vec2 spec_roughness_roughness_TRT = vec2(0.0);
    mx_chiang_hair_roughness(longitudinalRoughness, azimuthalRoughness, 0.500000, 2.000000, spec_roughness_roughness_R, spec_roughness_roughness_TT, spec_roughness_roughness_TRT);
    vec3 absorption_from_melanin_absorption = vec3(0.0);
    mx_deon_hair_absorption_from_melanin(melaninConcentration, melaninRedness, vec3(0.657704, 0.498077, 0.254107), vec3(0.829444, 0.670320, 0.349938), absorption_from_melanin_absorption);
    vec3 absorption_from_color_absorption = vec3(0.0);
    mx_chiang_hair_absorption_from_color(baseColor, 0.200000, absorption_from_color_absorption);
    vec3 mix_melanin_basecolor_out = mix(absorption_from_color_absorption, absorption_from_melanin_absorption, melaninMix);
    surfaceshader surface_shader_out = surfaceshader(vec3(0.0),vec3(0.0));
    {
        vec3 N = normalize(vd.normalWorld);
        vec3 V = normalize(u_viewPosition - vd.positionWorld);
        vec3 P = vd.positionWorld;
        vec3 L = vec3(0,0,0);;
        float occlusion = 1.0;

        float surfaceOpacity = 1.000000;

        // Shadow occlusion

        // Ambient occlusion
        occlusion = 1.0;

        // Add environment contribution
        {
            ClosureData closureData = ClosureData(CLOSURE_TYPE_INDIRECT, L, V, N, P, occlusion);
            BSDF chiang_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
            mx_chiang_hair_bsdf(closureData, tint_R, tint_TT, tint_TRT, 1.550000, spec_roughness_roughness_R, spec_roughness_roughness_TT, spec_roughness_roughness_TRT, cuticleAngle, mix_melanin_basecolor_out, geomprop_Nworld_out1, geomprop_Tworld_out1, chiang_bsdf_out);

            surface_shader_out.color += occlusion * chiang_bsdf_out.response;
        }

        // Calculate the BSDF transmission for viewing direction
        BSDF chiang_bsdf_out = BSDF(vec3(0.0),vec3(1.0));
        surface_shader_out.color += chiang_bsdf_out.response;

        // Compute and apply surface opacity
        {
            surface_shader_out.color *= surfaceOpacity;
            surface_shader_out.transparency = mix(vec3(1.0), surface_shader_out.transparency, surfaceOpacity);
        }
    }

    out1 = surface_shader_out;
}

void main()
{
    surfaceshader SR_default_out = surfaceshader(vec3(0.0),vec3(0.0));
    NG_simple_hair_shader(SR_default_melaninConcentration, SR_default_melaninRedness, SR_default_melaninMix, SR_default_baseColor, SR_default_longitudinalRoughness, SR_default_azimuthalRoughness, SR_default_cuticleAngle, SR_default_tint_R, SR_default_tint_TT, SR_default_tint_TRT, SR_default_ior, SR_default_out);
    material simple_hair_default_out = SR_default_out;
    out1 = vec4(simple_hair_default_out.color, 1.0);
}

