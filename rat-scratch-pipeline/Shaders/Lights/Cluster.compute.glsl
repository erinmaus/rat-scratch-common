layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

#include "@Generated/Pipeline/Config.common.glsl"
#include "@/Math/Common.common.glsl"
#include "@/Math/Vector.common.glsl"
#include "@Pipeline/Common/Lights.common.glsl"
#include "@Pipeline/Common/Types/Lights.common.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Index.common.glsl"
#include "./Types.common.glsl"

restrict readonly buffer rat_LightsBuffer
{
	RatScratchPipelineLight rat_Lights[];
};

restrict buffer rat_LightCountIndicesBuffer
{
	uint rat_LightCountIndices[];
};

restrict readonly buffer rat_WorldCellsBuffer
{
	RatScratchPipelineCell rat_WorldCells[];
};

uniform uint rat_LightCount;
uniform uint rat_CameraCount;

vec4 getSpotLightMinBoundingSphere(const in RatScratchPipelineSpotLight light)
{
	const float c = max(light.cutoff, RAT_SCRATCH_EPSILON);
	float h = light.attenuation;

	if (h <= 0.0)
		return vec4(light.position, 0.0);

	float radius = h / (2.0 * c * c);
	vec3 axis = safeNormalize(light.direction);

	return vec4(light.position + radius * axis, radius);
}

bool sphereIntersectsCell(vec4 sphere, vec3 cellMin, vec3 cellMax)
{
	if (all(greaterThanEqual(sphere.xyz, cellMin)) && all(lessThanEqual(sphere.xyz, cellMax)))
	{
		return true;
	}

	vec3 closest = clamp(sphere.xyz, cellMin, cellMax);
	vec3 difference = sphere.xyz - closest;
	float distanceSquared = dot(difference, difference);
	float radiusSquared = sphere.w * sphere.w;
	return distanceSquared <= radiusSquared;
}

void tryAddLightToCell(uvec3 cellCoordinate, uint lightIndex, uint cameraIndex)
{
	uvec4 coordinate = uvec4(cellCoordinate, 0);
	uvec4 dimensions =
		uvec4(RAT_SCRATCH_PIPELINE_CONFIG_LIGHT_CELLS, RAT_SCRATCH_PIPELINE_CONFIG_MAX_LIGHTS_PER_CELL + 1);
	uint offset = dimensions.x * dimensions.y * dimensions.z * dimensions.w * cameraIndex;
	uint index = coordinateToIndex(coordinate, dimensions);

	uint previousCount = atomicAdd(rat_LightCountIndices[index + offset], 1);
	if (previousCount < RAT_SCRATCH_PIPELINE_CONFIG_MAX_LIGHTS_PER_CELL)
	{
		uvec4 lightCellCoordinate = uvec4(cellCoordinate, previousCount + 1);
		uint lightCellIndex = coordinateToIndex(lightCellCoordinate, dimensions);
		rat_LightCountIndices[lightCellIndex + offset] = lightIndex;
	}
}

void testPointLight(RatScratchPipelineLight light, vec3 cellMin, vec3 cellMax, uvec3 cellCoordinate, uint lightIndex,
					uint cameraIndex)
{
	RatScratchPipelinePointLight pointLight;
	ratGetLight(light, pointLight);

	vec4 sphere = vec4(pointLight.position, pointLight.attenuation);
	if (sphereIntersectsCell(sphere, cellMin, cellMax))
	{
		tryAddLightToCell(cellCoordinate, lightIndex, cameraIndex);
	}
}

void testSpotLight(RatScratchPipelineLight light, vec3 cellMin, vec3 cellMax, uvec3 cellCoordinate, uint lightIndex,
				   uint cameraIndex)
{
	RatScratchPipelineSpotLight spotLight;
	ratGetLight(light, spotLight);

	vec4 sphere = getSpotLightMinBoundingSphere(spotLight);
	if (sphereIntersectsCell(sphere, cellMin, cellMax))
	{
		tryAddLightToCell(cellCoordinate, lightIndex, cameraIndex);
	}
}

void computemain()
{
	uint cellIndex = gl_GlobalInvocationID.x;
	uvec3 dimensions = RAT_SCRATCH_PIPELINE_CONFIG_LIGHT_CELLS;
	uvec3 coordinate = indexToCoordinate(cellIndex, dimensions);
	if (coordinate.x >= dimensions.x || coordinate.y >= dimensions.y || coordinate.z >= dimensions.z)
	{
		return;
	}

	uint cameraIndex = gl_GlobalInvocationID.z;
	if (cameraIndex >= rat_CameraCount)
	{
		return;
	}

	uint cellOffset = dimensions.x * dimensions.y * dimensions.z * cameraIndex;
	RatScratchPipelineCell cell = rat_WorldCells[cellIndex + cellOffset];

	uint i = min(gl_GlobalInvocationID.y * RAT_SCRATCH_PIPELINE_CONFIG_MAX_LIGHTS_PER_THREAD, rat_LightCount);
	uint j = min(i + RAT_SCRATCH_PIPELINE_CONFIG_MAX_LIGHTS_PER_THREAD, rat_LightCount);

	for (uint k = i; k < j; ++k)
	{
		RatScratchPipelineLight light = rat_Lights[k];
		switch (ratGetLightType(light))
		{
		case RAT_SCRATCH_LIGHT_TYPE_AMBIENT:
		case RAT_SCRATCH_LIGHT_TYPE_DIRECTIONAL:
			// These lights are always global.
			tryAddLightToCell(coordinate, k, cameraIndex);
			break;
		case RAT_SCRATCH_LIGHT_TYPE_POINT:
			testPointLight(light, cell.worldMin, cell.worldMax, coordinate, k, cameraIndex);
			break;
		case RAT_SCRATCH_LIGHT_TYPE_SPOT:
			testSpotLight(light, cell.worldMin, cell.worldMax, coordinate, k, cameraIndex);
			break;
		}
	}
}
