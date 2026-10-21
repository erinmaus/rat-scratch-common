#include "@Pipeline/Base/Light/DefaultApplyLights.frag.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Buffers/Lights.common.glsl"
#include "@Pipeline/Common/Buffers/ReflectionProbe.common.glsl"
#include "@Pipeline/Common/Index.common.glsl"
#include "@Pipeline/Common/Lights.common.glsl"
#include "@Pipeline/Common/Camera.common.glsl"
#include "@Pipeline/Common/PBR.common.glsl"

#include "@Generated/Pipeline/Config.common.glsl"
#include "@Generated/Pipeline/Material/Properties.common.glsl"
#include "@Generated/Pipeline/Light/Lights.common.glsl"
#include "@Generated/Pipeline/Light/ApplyLights.common.glsl"

#include "@Pipeline/Common/Textures/Reflection.common.glsl"

uniform uvec2 rat_ScreenSize;

void ratApplyLightsImplGetDimensionsCoordinate(vec3 position, uvec2 cellSizeInPixels, uint countPerCell,
											   out uvec3 coordinate, out uvec3 dimensions)
{
	uvec2 screenDimensions = uvec2(ceil(vec2(rat_ScreenSize) / vec2(cellSizeInPixels)));
	vec3 clampedPosition = clamp(position, vec3(0.0), vec3(1.0));
	uvec2 screenCoordinate = uvec2(floor(clampedPosition.xy * vec2(screenDimensions)));
	screenCoordinate = min(screenCoordinate, screenDimensions - uvec2(1));

	coordinate = uvec3(0, screenCoordinate);
	dimensions = uvec3(countPerCell + 1, screenDimensions);
}

void ratApplyLightsImplGetLightDimensionsCoordinate(vec3 position, out uvec3 coordinate, out uvec3 dimensions)
{
	ratApplyLightsImplGetDimensionsCoordinate(position, RAT_SCRATCH_PIPELINE_CONFIG_LIGHT_CELL_SIZE_IN_PIXELS,
											  RAT_SCRATCH_PIPELINE_CONFIG_MAX_LIGHTS_PER_CELL, coordinate, dimensions);
}

void ratApplyLightsImplGetProbeDimensionsCoordinate(vec3 position, out uvec3 coordinate, out uvec3 dimensions)
{
	ratApplyLightsImplGetDimensionsCoordinate(
		position, RAT_SCRATCH_PIPELINE_CONFIG_REFLECTION_PROBE_CELL_SIZE_IN_PIXELS,
		RAT_SCRATCH_PIPELINE_CONFIG_MAX_REFLECTION_PROBES_PER_CELL, coordinate, dimensions);
}

uint ratApplyLightsImplGetIndex(uvec3 coordinate, uvec3 dimensions, uint layer)
{
	uint offset = dimensions.x * dimensions.y * dimensions.z * layer;
	return coordinateToIndex(coordinate, dimensions) + offset;
}

bool ratApplyLightsImplCalculateWeightGetMinDistance(vec3 position, vec3 boundsMin, vec3 boundsMax,
													 out float distanceFromBounds)
{
	if (any(lessThan(position, boundsMin)) || any(greaterThan(position, boundsMax)))
	{
		distanceFromBounds = 0.0;
		return false;
	}

	vec3 distanceToMin = position - boundsMin;
	vec3 distanceToMax = boundsMax - position;

	vec3 distances = min(distanceToMin, distanceToMax);
	distanceFromBounds = min(min(distances.x, distances.y), distances.z);

	return true;
}

float ratApplyLightsImplCalculateWeight(RatScratchPipelineReflectionProbe probe, vec3 position)
{
	vec3 probeMin = probe.position + probe.boundsMin;
	vec3 probeMax = probe.position + probe.boundsMax;
	vec3 probeFalloffMin = probe.position + probe.falloffBoundsMin;
	vec3 probeFalloffMax = probe.position + probe.falloffBoundsMax;

	float minDistance;
	if (!ratApplyLightsImplCalculateWeightGetMinDistance(position, probeMin, probeMax, minDistance))
	{
		return 0.0;
	}

	float falloffDistance;
	if (!ratApplyLightsImplCalculateWeightGetMinDistance(position, probeFalloffMin, probeFalloffMax, falloffDistance))
	{
		return 0.0;
	}

	return smoothstep(0.0, falloffDistance, minDistance);
}

void ratApplyLightsImplEnvironmentProbes(in RatScratchPipelineFragmentOutput fragmentOutput,
										 inout RatScratchPipelineLightResult result)
{
	uvec3 probeCoordinate, probeDimensions;
	ratApplyLightsImplGetProbeDimensionsCoordinate(fragmentOutput.screenPosition, probeCoordinate, probeDimensions);

	vec3 cameraPosition = ratGetCameraPosition(fragmentOutput.cameraIndex);

	vec3 N = fragmentOutput.normal;
	vec3 V = normalize(cameraPosition - fragmentOutput.position);
	vec3 R = -reflect(V, N);

	uint probeCount = rat_ReflectionProbeCountIndices[ratApplyLightsImplGetIndex(
		uvec3(0, probeCoordinate.yz), probeDimensions, fragmentOutput.cameraIndex)];
	probeCount = min(probeCount, RAT_SCRATCH_PIPELINE_CONFIG_MAX_REFLECTION_PROBES_PER_CELL);

	if (probeCount == 0)
	{
		result.diffuse *= vec3(1.0, 0.0, 0.0);
	}

	vec3 radiance = vec3(0.0);
	vec3 irradiance = vec3(0.0);
	float weight = 0.0;
	for (uint i = 0; i < probeCount; ++i)
	{
		uint probeIndex = rat_ReflectionProbeCountIndices[ratApplyLightsImplGetIndex(
			uvec3(i + 1, probeCoordinate.yz), probeDimensions, fragmentOutput.cameraIndex)];
		RatScratchPipelineReflectionProbe probe = rat_ReflectionProbes[probeIndex];

		float w = ratApplyLightsImplCalculateWeight(probe, fragmentOutput.position);
		if (w > 0.0)
		{
			weight += w;
			radiance +=
				vec3(w) * ratSampleReflectionProbe(probe, fragmentOutput.position, fragmentOutput.roughness, R).rgb;
			irradiance += vec3(w) * ratSampleGlobalIlluminationProbe(probe, fragmentOutput.position, N).rgb;
		}
	}

	if (weight <= 0.0)
	{
		return;
	}

	radiance /= weight;
	irradiance /= weight;

	// ratApplyIBL(fragmentOutput, radiance, irradiance, cameraPosition, result);
	result.diffuse = radiance;
}

void ratApplyLights(in RatScratchPipelineFragmentOutput fragmentOutput, inout RatScratchPipelineLightResult result)
{
	RatScratchPipelineLight light;
	RatScratchPipelineAmbientLight ambientLight;
	RatScratchPipelineDirectionalLight directionalLight;
	RatScratchPipelinePointLight pointLight;
	RatScratchPipelineSpotLight spotLight;

	uvec3 lightCoordinate, lightDimensions;
	ratApplyLightsImplGetLightDimensionsCoordinate(fragmentOutput.screenPosition, lightCoordinate, lightDimensions);

	uint lightsCount = rat_LightCountIndices[ratApplyLightsImplGetIndex(uvec3(0, lightCoordinate.yz), lightDimensions,
																		fragmentOutput.cameraIndex)];
	lightsCount = min(lightsCount, RAT_SCRATCH_PIPELINE_CONFIG_MAX_LIGHTS_PER_CELL);

	for (uint i = 0; i < lightsCount; ++i)
	{
		uint lightIndex = rat_LightCountIndices[ratApplyLightsImplGetIndex(
			uvec3(i + 1, lightCoordinate.yz), lightDimensions, fragmentOutput.cameraIndex)];
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

	if (rat_ReflectionProbeCount > 0)
	{
		ratApplyLightsImplEnvironmentProbes(fragmentOutput, result);
	}
}
