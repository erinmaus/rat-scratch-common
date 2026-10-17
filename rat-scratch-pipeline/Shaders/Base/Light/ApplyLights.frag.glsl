#include "@Pipeline/Base/Light/DefaultApplyLights.frag.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Buffers/Lights.common.glsl"
#include "@Pipeline/Common/Index.common.glsl"
#include "@Pipeline/Common/Lights.common.glsl"

#include "@Generated/Pipeline/Config.common.glsl"
#include "@Generated/Pipeline/Material/Properties.common.glsl"
#include "@Generated/Pipeline/Light/Lights.common.glsl"
#include "@Generated/Pipeline/Light/ApplyLights.common.glsl"

uniform uvec2 rat_ScreenSize;

uint ratApplyLightsImplGetIndex(vec3 position, uint i, uint layer)
{
	uvec2 dimensions = uvec2(ceil(vec2(rat_ScreenSize) / vec2(RAT_SCRATCH_PIPELINE_CONFIG_LIGHT_CELL_SIZE_IN_PIXELS)));
	vec3 clampedPosition = clamp(position, vec3(0.0), vec3(1.0));
	uvec2 coordinate = uvec2(floor(clampedPosition.xy * vec2(dimensions)));
	coordinate = min(coordinate, dimensions - uvec2(1));

	uint offset = dimensions.x * dimensions.y * (RAT_SCRATCH_PIPELINE_CONFIG_MAX_LIGHTS_PER_CELL + 1) * layer;
	return coordinateToIndex(uvec3(coordinate, i),
							 uvec3(dimensions, RAT_SCRATCH_PIPELINE_CONFIG_MAX_LIGHTS_PER_CELL + 1)) +
		   offset;
}

void ratApplyLights(in RatScratchPipelineFragmentOutput fragmentOutput, inout RatScratchPipelineLightResult result)
{
	RatScratchPipelineLight light;
	RatScratchPipelineAmbientLight ambientLight;
	RatScratchPipelineDirectionalLight directionalLight;
	RatScratchPipelinePointLight pointLight;
	RatScratchPipelineSpotLight spotLight;

	uint lightsCount =
		rat_LightCountIndices[ratApplyLightsImplGetIndex(fragmentOutput.screenPosition, 0, fragmentOutput.cameraIndex)];
	lightsCount = min(lightsCount, RAT_SCRATCH_PIPELINE_CONFIG_MAX_LIGHTS_PER_CELL);

	for (uint i = 0; i < lightsCount; ++i)
	{
		uint lightIndex = rat_LightCountIndices[ratApplyLightsImplGetIndex(fragmentOutput.screenPosition, i + 1,
																		   fragmentOutput.cameraIndex)];
		light = rat_Lights[lightIndex];

		switch (ratGetLightType(light))
		{
		case RAT_SCRATCH_LIGHT_TYPE_AMBIENT:
			ratGetLight(light, ambientLight);
			ratApplyLight(fragmentOutput, ambientLight, result);
			break;
		case RAT_SCRATCH_LIGHT_TYPE_DIRECTIONAL:
			ratGetLight(light, directionalLight);
			ratApplyLight(fragmentOutput, directionalLight, result);
			break;
		case RAT_SCRATCH_LIGHT_TYPE_POINT:
			ratGetLight(light, pointLight);
			ratApplyLight(fragmentOutput, pointLight, result);
			break;
		case RAT_SCRATCH_LIGHT_TYPE_SPOT:
			ratGetLight(light, spotLight);
			ratApplyLight(fragmentOutput, spotLight, result);
			break;
		}
	}
}
