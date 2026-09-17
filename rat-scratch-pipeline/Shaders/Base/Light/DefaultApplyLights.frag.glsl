#include "@/Math/Vector.common.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/PBR.common.glsl"
#include "@Pipeline/Common/Types/Fragment.common.glsl"
#include "@Pipeline/Common/Types/Lights.common.glsl"

void ratApplyDefaultFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput,
								  in RatScratchPipelineAmbientLight ambientLight,
								  inout RatScratchPipelineLightResult result)
{
	float occlusion = 1.0; // TODO: Implement actual occlusion sampling
	vec3 ambient = ambientLight.color.rgb * ambientLight.ambience;
	result.diffuse += ambient * vec3(occlusion);
	result.fluorescence +=
		fragmentOutput.fluorescence * vec3(ambientLight.ambience * ambientLight.ultraviolet * occlusion);
}

void ratApplyDefaultFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput,
								  in RatScratchPipelineDirectionalLight directionalLight,
								  inout RatScratchPipelineLightResult result)
{
	float shadow = 1.0; // TODO: Implement actual shadow sampling
	vec3 cameraPosition = rat_Cameras[fragmentOutput.cameraIndex].inverseViewTransform[3].xyz;
	ratApplyPBR(fragmentOutput, safeNormalize(directionalLight.direction), directionalLight.color.rgb * shadow,
				cameraPosition, result);
	result.fluorescence +=
		fragmentOutput.fluorescence *
		vec3(max(dot(fragmentOutput.normal, directionalLight.direction), 0.0) * directionalLight.ultraviolet);
}

void ratApplyDefaultFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput,
								  in RatScratchPipelinePointLight pointLight,
								  inout RatScratchPipelineLightResult result)
{
	vec3 lightToSurface = fragmentOutput.position - pointLight.position;
	float lightToSurfaceDistance = length(lightToSurface);
	vec3 L = -safeNormalize(lightToSurface, lightToSurfaceDistance);
	float attenuation = clamp(1.0 - lightToSurfaceDistance / pointLight.attenuation, 0.0, 1.0);
	float shadow = 1.0; // TODO: Implement actual shadow sampling
	vec3 cameraPosition = rat_Cameras[fragmentOutput.cameraIndex].inverseViewTransform[3].xyz;
	ratApplyPBR(fragmentOutput, L, pointLight.color.rgb * attenuation * shadow, cameraPosition, result);
	result.fluorescence += fragmentOutput.fluorescence * vec3(attenuation * shadow * pointLight.ultraviolet);
}

void ratApplyDefaultFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput,
								  in RatScratchPipelineSpotLight spotLight, inout RatScratchPipelineLightResult result)
{
	vec3 lightToSurface = fragmentOutput.position - spotLight.position;
	float lightToSurfaceDistance = length(lightToSurface);
	vec3 L = -safeNormalize(lightToSurface, lightToSurfaceDistance);

	float attenuation = clamp(1.0 - lightToSurfaceDistance / spotLight.attenuation, 0.0, 1.0);
	float theta = dot(L, normalize(-spotLight.direction));
	float epsilon = spotLight.cutoff;
	float intensity = clamp((theta - epsilon) / (1.0 - epsilon), 0.0, 1.0);
	float shadow = 1.0; // TODO: Implement actual shadow sampling
	vec3 cameraPosition = rat_Cameras[fragmentOutput.cameraIndex].inverseViewTransform[3].xyz;
	ratApplyPBR(fragmentOutput, L, spotLight.color.rgb * attenuation * intensity * shadow, cameraPosition, result);
	result.fluorescence += fragmentOutput.fluorescence * vec3(attenuation * intensity * shadow * spotLight.ultraviolet);
}
