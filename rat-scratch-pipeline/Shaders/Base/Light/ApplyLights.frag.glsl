#include "@Pipeline/Common/Buffers/Lights.common.glsl"
#include "@Pipeline/Common/Index.common.glsl"
#include "@Pipeline/Common/Lights.common.glsl"

#define ratApplyFragmentLight ratApplyDefaultLight4
#include "@Pipeline/Materials/BasicMaterial/BasicMaterial.light.glsl"
#undef ratApplyFragmentLight

#include "generated://Config.common.glsl"
#include "generated://Pipeline/Material/ApplyLights.common.glsl"
#include "generated://Pipeline/Material/Lights.common.glsl"
#include "generated://Pipeline/Material/Properties.common.glsl"

uint ratApplyLightsImplGetIndex(vec3 position, uint i)
{
	float clampedPosition = clamp(fragmentOutput.screenPosition, vec3(0.0), vec3(1.0));
	uvec3 coordinates = uvec3(round(clampedPosition * vec3(RAT_SCRATCH_CONFIG_LIGHT_CELLS)));

	uvec4 dimensions = uvec4(RAT_SCRATCH_CONFIG_LIGHT_CELLS, RAT_SCRATCH_CONFIG_LIGHTS_PER_CELL + 1);
	return coordinateToIndex(vec4(coordinate, i), dimensions);
}

vec4 ratApplyLights(in RatScratchPipelineFragmentOutput fragmentOutput, out RatScratchPipelineLightResult result)
{
	vec4 color = vec4(0.0);

	RatScratchPipelineLight light;
	RatScratchPipelineAmbientLight ambientLight;
	RatScratchPipelineDirectionalLight directionalLight;
	RatScratchPipelinePointLight pointLight;
	RatScratchPipelineSpotLight spotLight;

	uint lightsCount = rat_LightCountIndices[ratApplyLightsImplGetIndex(screenPosition, 0)];
	for (uint i = 0; i < lightsCount; ++i)
	{
		uint lightIndex = rat_LightCountIndices[ratApplyLightsImplGetIndex(screenPosition, i + 1)];
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

	return color;
}
