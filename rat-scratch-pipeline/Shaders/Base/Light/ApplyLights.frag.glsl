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

	coordinate = uvec3(screenCoordinate, 0);
	dimensions = uvec3(screenDimensions, countPerCell + 1);
}

void ratApplyLightsImplGetLightDimensionsCoordinate(vec3 position, out uvec3 coordinate, out uvec3 dimensions)
{
	ratApplyLightsImplGetDimensionsCoordinate(position, RAT_SCRATCH_PIPELINE_CONFIG_LIGHT_CELL_SIZE_IN_PIXELS,
											  RAT_SCRATCH_PIPELINE_CONFIG_MAX_LIGHTS_PER_CELL + 1, coordinate,
											  dimensions);
}

void ratApplyLightsImplGetProbeDimensionsCoordinate(vec3 position, out uvec3 coordinate, out uvec3 dimensions)
{
	ratApplyLightsImplGetDimensionsCoordinate(
		position, RAT_SCRATCH_PIPELINE_CONFIG_REFLECTION_PROBE_CELL_SIZE_IN_PIXELS,
		RAT_SCRATCH_PIPELINE_CONFIG_MAX_REFLECTION_PROBES_PER_CELL + 1, coordinate, dimensions);
}

uint ratApplyLightsImplGetIndex(uvec3 coordinate, uvec3 dimensions, uint layer)
{
	uint offset = dimensions.x * dimensions.y * dimensions.z * layer;
	return coordinateToIndex(coordinate, dimensions) + offset;
}

void ratApplyEnvironmentProbes(in RatScratchPipelineFragmentOutput fragmentOutput,
							   inout RatScratchPipelineLightResult result)
{
	uvec3 probeCoordinate, probeDimensions;
	ratApplyLightsImplGetProbeDimensionsCoordinate(fragmentOutput.screenPosition, probeCoordinate, probeDimensions);

	vec3 cameraPosition = ratGetCameraPosition(fragmentOutput.cameraIndex);

	vec3 N = fragmentOutput.normal;
	vec3 V = normalize(cameraPosition - fragmentOutput.position);
	vec3 R = reflect(V, N);

	uint probeCount = rat_ReflectionProbeCountIndices[ratApplyLightsImplGetIndex(
		uvec3(probeCoordinate.xy, 0), probeDimensions, fragmentOutput.cameraIndex)];
	probeCount = min(probeCount, RAT_SCRATCH_PIPELINE_CONFIG_MAX_REFLECTION_PROBES_PER_CELL);

	vec3 radiance = vec3(0.0);
	vec3 irradiance = vec3(0.0);
	float weight = 0.0;
	for (uint i = 0; i < probeCount; ++i)
	{
		uint probeIndex = rat_ReflectionProbeCountIndices[ratApplyLightsImplGetIndex(
			uvec3(probeCoordinate.xy, i + 1), probeDimensions, fragmentOutput.cameraIndex)];
		RatScratchPipelineReflectionProbe probe = rat_ReflectionProbes[probeIndex];

		float distanceFromProbe = length(fragmentOutput.position - probe.position);
		float threshold = probe.radius.y - probe.radius.x;
		float distanceFromThreshold = distanceFromProbe - probe.radius.x;

		if (distanceFromThreshold > 0.0 && threshold <= 0.0)
		{
			continue;
		}

		float w = 1.0;//1.0 - clamp(distanceFromThreshold / threshold, 0.0, 1.0);

		weight += w;
		radiance += vec3(w) * ratSampleReflectionProbe(probe, fragmentOutput.position, fragmentOutput.roughness, R).rgb;
		irradiance += vec3(w) * ratSampleGlobalIlluminationProbe(probe, fragmentOutput.position, N).rgb;

		break;
	}

	if (weight <= 0.0)
	{
		return;
	}

	radiance /= weight;
	irradiance /= weight;

	float nDotV = max(dot(V, N), 0.0);
	vec3 F = ratPBRFresnelSchlick(nDotV, mix(vec3(0.04), fragmentOutput.albedo.rgb, vec3(fragmentOutput.metal)));

	//result.specular += F * radiance * vec3(result.occlusion);
	result.diffuse = irradiance * vec3(result.occlusion);
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

	uint lightsCount = rat_LightCountIndices[ratApplyLightsImplGetIndex(uvec3(lightCoordinate.xy, 0), lightDimensions,
																		fragmentOutput.cameraIndex)];
	lightsCount = min(lightsCount, RAT_SCRATCH_PIPELINE_CONFIG_MAX_LIGHTS_PER_CELL);

	result.diffuse = vec3(lightsCount);
	if (true)
	{
		return;
	}

	for (uint i = 0; i < lightsCount; ++i)
	{
		uint lightIndex = rat_LightCountIndices[ratApplyLightsImplGetIndex(
			uvec3(lightCoordinate.xy, i + 1), lightDimensions, fragmentOutput.cameraIndex)];
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
		ratApplyEnvironmentProbes(fragmentOutput, result);
	}
}
