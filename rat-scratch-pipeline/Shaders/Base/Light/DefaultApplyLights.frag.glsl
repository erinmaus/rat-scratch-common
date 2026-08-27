#include "@Pipeline/Common/PBR.common.glsl"
#include "@Pipeline/Common/Types/Fragment.common.glsl"
#include "@Pipeline/Common/Types/Lights.common.glsl"

void ratApplyDefaultFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput,
								  in RatScratchAmbientLight ambientLight, inout RatScratchPipelineLightResult result)
{
	float occlusion = 1.0; // TODO: Implement actual occlusion sampling
	vec3 ambient = ambientLight.color.rgb * ambientLight.ambience;
	result.diffuse += vec4(ambient * occlusion, 1.0);
}

void ratApplyDefaultFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput,
								  in RatScratchDirectionalLight directionalLight,
								  inout RatScratchPipelineLightResult result)
{
	float shadow = 1.0; // TODO: Implement actual shadow sampling
	ratApplyPBR(fragmentOutput, normalize(-directionalLight.direction), directionalLight.color.rgb * shadow, result);
}

void ratApplyDefaultFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput,
								  in RatScratchPipelinePointLight pointLight,
								  inout RatScratchPipelineLightResult result)
{
	vec3 lightToSurface = pointLight.position - fragmentOutput.position;
	float lightToSurfaceDistance = length(lightToSurface);
	vec3 L = safeNormalize(lightToSurface, lightToSurfaceDistance);
	float attenuation = clamp(1.0 - lightToSurfaceDistance / pointLight.attenuation, 0.0, 1.0);
	float shadow = 1.0; // TODO: Implement actual shadow sampling

	ratApplyPBR(fragmentOutput, L, pointLight.color.rgb * attenuation * shadow, result);
}

void ratApplyDefaultFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput,
								  in RatScratchPipelineSpotLight spotLight, inout RatScratchPipelineLightResult result)
{
	vec3 lightToSurface = spotLight.position - fragmentOutput.position;
	float lightToSurfaceDistance = length(lightToSurface);
	vec3 L = normalize(lightToSurface, lightToSurfaceDistance);

	float attenuation = clamp(1.0 - lightToSurfaceDistance / spotLight.attenuation, 0.0, 1.0);
	float theta = dot(L, normalize(-spotLight.direction));
	float epsilon = spotLight.cutoff;
	float intensity = clamp((theta - epsilon) / (1.0 - epsilon), 0.0, 1.0);
	float shadow = 1.0; // TODO: Implement actual shadow sampling

	ratApplyPBR(fragmentOutput, L, spotLight.color.rgb * attenuation * intensity * shadow, result);
}
