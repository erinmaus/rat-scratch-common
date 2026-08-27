#include "@Pipeline/Common/Textures/Sample.common.glsl"

void ratApplyFragmentMaterial(in RatScratchPipelineFragmentInput fragmentInput,
							  out RatScratchPipelineFragmentOutput fragmentOutput)
{
	RatScratchBasicMaterialProperties materialProperties;
	ratGetBasicMaterialProperties(fragmentInput.materialInstance, materialProperties);

	vec4 albedo = ratSampleTexture(materialProperties.albedoTexture, fragmentInput.textureCoordinate);
	fragmentOutput.albedo = albedo * materialProperties.albedoFactor;

	float occlusion = ratSampleOcclusionTexture(materialProperties.occlusionTexture, fragmentInput.textureCoordinate);
	fragmentOutput.occlusion = 1.0 + materialProperties.occlusionStrength * (occlusion - 1.0);

	vec3 normalTextureSample =
		ratSampleNormalTexture(materialProperties.normalTexture, fragmentInput.textureCoordinate);

	vec3 t = vec3(normalTextureSample.x * materialProperties.normalScale) * fragmentInput.tangent;
	vec3 b = vec3(normalTextureSample.y * materialProperties.normalScale) * fragmentInput.bitangent;
	vec3 n = vec3(normalTextureSample.z) * fragmentInput.normal;
	fragmentOutput.normal = normalize(t + b + n);

	vec2 metallicRoughness =
		ratSampleLinearTexture(materialProperties.metallicRoughnessTexture, fragmentInput.textureCoordinate).gb;

	fragmentOutput.metal = metallicRoughness.x * materialProperties.metallicFactor;
	fragmentOutput.roughness = metallicRoughness.y * materialProperties.roughnessFactor;

	vec3 emissive = ratSampleTexture(materialProperties.emissiveTexture, fragmentInput.textureCoordinate).rgb;
	fragmentOutput.emissive = emissive * materialProperties.emissiveFactor;
}
