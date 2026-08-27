#include "@Pipeline/Base/Light/DefaultApplyLights.frag.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Buffers/Lights.common.glsl"
#include "@Pipeline/Common/Index.common.glsl"
#include "@Pipeline/Common/Lights.common.glsl"

// #include "@Generated/Config.common.glsl"
#include "@Generated/Pipeline/Light/ApplyLights.common.glsl"
#include "@Generated/Pipeline/Light/Lights.common.glsl"
#include "@Generated/Pipeline/Material/Properties.common.glsl"

const uvec3 RAT_SCRATCH_CONFIG_LIGHT_CELLS = uvec3(16, 16, 16);
const uint RAT_SCRATCH_CONFIG_LIGHTS_PER_CELL = 32;

uint ratApplyLightsImplGetIndex(vec3 position, uint i)
{
	vec3 clampedPosition = clamp(position, vec3(0.0), vec3(1.0));
	uvec3 coordinate = uvec3(round(clampedPosition * vec3(RAT_SCRATCH_CONFIG_LIGHT_CELLS)));

	uvec4 dimensions = uvec4(RAT_SCRATCH_CONFIG_LIGHT_CELLS, RAT_SCRATCH_CONFIG_LIGHTS_PER_CELL + 1);
	return coordinateToIndex(uvec4(coordinate, i), dimensions);
}

vec4 ratApplyLights(in RatScratchPipelineFragmentOutput fragmentOutput, out RatScratchPipelineLightResult result)
{
	vec4 color = vec4(0.0);

	RatScratchPipelineLight light;
	RatScratchPipelineAmbientLight ambientLight;
	RatScratchPipelineDirectionalLight directionalLight;
	RatScratchPipelinePointLight pointLight;
	RatScratchPipelineSpotLight spotLight;

	uint lightsCount = rat_LightCountIndices[ratApplyLightsImplGetIndex(fragmentOutput.screenPosition, 0)];
	for (uint i = 0; i < lightsCount; ++i)
	{
		uint lightIndex = rat_LightCountIndices[ratApplyLightsImplGetIndex(fragmentOutput.screenPosition, i + 1)];
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
