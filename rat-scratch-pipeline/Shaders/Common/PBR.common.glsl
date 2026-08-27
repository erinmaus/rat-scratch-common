#include "@/Math/Common.common.glsl"
#include "@Pipeline/Types/Fragment.common.glsl"
#include "@Pipeline/Types/Lights.common.glsl"

float ratPBRImplDistributionGGX(vec3 N, vec3 H, float roughness)
{
	float a = roughness * roughness;
	float aSquared = a * a;
	float nDotH = max(dot(N, H), 0.0);
	float nDotHSquared = nDotH * nDotH;

	float numerator = aSquared;
	float denominator = (nDotHSquared * (aSquared - 1.0) + 1.0);
	denominator = RAT_SCRATCH_PI * denominator * denominator;

	return numerator / max(denominator, RAT_SCRATCH_EPSILON);
}

float ratPBRImplGeometrySchlickGGX(float nDotV, float roughness)
{
	float r = (roughness + 1.0);
	float k = (r * r) / 8.0;

	float numerator = 1.0;
	float denominator = 1.0 - k + k * nDotV;

	return numerator / denominator;
}

float ratPBRImplGeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
	float nDotV = max(dot(N, V), 0.0);
	float nDotL = max(dot(N, L), 0.0);
	float ggx2 = ratPBRImplGeometrySchlickGGX(nDotV, roughness);
	float ggx1 = ratPBRImplGeometrySchlickGGX(nDotL, roughness);

	return ggx1 * ggx2;
}

vec3 ratPBRImplFresnelSchlick(vec3 cosTheta, vec3 F0)
{
	return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

void ratApplyPBR(in RatScratchPipelineFragmentOutput fragmentOutput, vec3 L, vec3 radiance, vec3 cameraPosition,
				 inout RatScratchPipelineLightResult result)
{
	vec3 N = normalize(fragmentOutput.normal);
	vec3 V = normalize(cameraPosition - fragmentOutput.position);
	vec3 H = normalize(V + L);

	float roughness = fragmentOutput.roughness;
	float metallic = fragmentOutput.metal;
	vec3 albedo = fragmentOutput.albedo.rgb;

	vec3 F0 = mix(vec3(0.04), albedo, metallic);
	vec3 F = ratPBRImplFresnelSchlick(max(dot(H, V), 0.0), F0);
	float NDF = ratPBRImplDistributionGGX(N, H, roughness);
	float G = ratPBRImplGeometrySmith(N, V, L, roughness);

	float nDotV = max(dot(N, V), 0.0);
	vec3 specularTerm = (NDF * G * F * radiance) / (4.0 * nDotV + 0.0001);

	float nDotL = max(dot(N, L), 0.0);
	vec3 diffuseTerm = radiance * nDotL;

	result.diffuse += diffuseTerm;
	result.specular += specularTerm;
}
