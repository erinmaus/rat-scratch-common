void ratApplyFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput, in RatScratchAmbientLight ambientLight,
						   inout RatScratchPipelineLightResult result)
{
	// TODO: occlusion
	// float occlusion = ratSampleOcclusionTexture(light.occlusionTexture, fragmentOutput.screenPosition);
	// occlusion *= fragmentOutput.occlusion;
	float occlusion = 1.0;

	result.diffuse += ambientLight.color * vec4(vec3(ambientLight.ambience), 1.0) * vec4(vec3(occlusion), 1.0);
}

void ratApplyFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput,
						   in RatScratchDirectionalLight directionalLight, inout RatScratchPipelineLightResult result)
{
	// TODO: shadow
	// float shadow = ratSampleShadowTexture(directionalLight.shadowTexture);
	float shadow = 1.0;

	float lightDotSurface = max(dot(directionalLight.direction, fragmentOutput.normal), 0.0);
	result.diffuse += directionalLight.color * vec4(vec3(lightDotSurface), 1.0) * vec4(vec3(shadow), 1.0);
}

void ratApplyFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput,
						   in RatScratchPipelinePointLight pointLight, inout RatScratchPipelineLightResult result)
{
	// TODO: shadow
	// float shadow = ratSampleShadowTexture(pointLight.shadowTexture);
	float shadow = 1.0;

	vec3 lightSurfaceDifference = pointLight.position - position;
	float lightSurfaceDistance = length(lightSurfaceDifference);
	float attenuation = clamp(1.0 - lightSurfaceDistance / pointLight.attenuation, 0.0, 1.0);

	result.diffuse += pointLight.color * vec4(vec3(attenuation), 1.0) * vec4(vec3(shadow), 1.0);
}

void ratApplyFragmentLight(in RatScratchPipelineFragmentOutput fragmentOutput, in RatScratchPipelineSpotLight spotLight,
						   inout RatScratchPipelineLightResult result)
{
	// TODO: shadow
	// float shadow = ratSampleShadowTexture(spotLight.shadowTexture);
	float shadow = 1.0;

	vec3 lightSurfaceDifference = spotLight.position - position;
	float lightSurfaceDistance = length(lightSurfaceDifference);
	vec3 lightToSurface = lightSurfaceDirection * vec3(1.0 / max(lightSurfaceDistance, RAT_SCRATCH_EPSILON));
	float lightDotSurface = dot(lightToSurface, spotLight.direction);
	float cutoffStep = step(lightToSurface.cutoff, lightDotSurface);
	float attenuation = clamp(1.0 - lightSurfaceDistance / spotLight.attenuation, 0.0, 1.0);
	attenuation *= 1.0 - ((1.0 - lightDotSurface) / max(1.0 - spotLight.cutoff, RAT_SCRATCH_EPSILON));

	result.diffuse += spotLight.color * vec4(vec3(attenuation), 1.0) * vec4(vec3(shadow), 1.0) * vec4(cutoffStep);
}
