layout(local_size_x = 64, local_size_y = 1) in;

#include "@Generated/Pipeline/Config.common.glsl"
#include "@/Math/Common.common.glsl"
#include "@/Math/Vector.common.glsl"
#include "@Pipeline/Common/Lights.common.glsl"
#include "@Pipeline/Common/Types/Lights.common.glsl"
#include "@Pipeline/Common/Buffers/Lights.common.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Index.common.glsl"
#include "./Types.common.glsl"

restrict buffer rat_WorldCellsBuffer
{
	RatScratchPipelineCell rat_WorldCells[];
};

uniform uint rat_LightCount;
uniform uint rat_CameraCount;

void screenSpaceToNDC(inout vec3 value)
{
	value *= vec3(2.0);
	value -= vec3(1.0);
}

void ndcToWorldSpace(in RatScratchPipelineCamera camera, inout vec3 value)
{
	vec4 position = vec4(value, 1.0);
	vec4 worldPosition = camera.inverseProjectionViewTransform * position;
	worldPosition /= worldPosition.w;

	value = worldPosition.xyz;
}

void unprojectScreenCellToWorldAABB(in vec3 cellMin, in vec3 cellMax, in RatScratchPipelineCamera camera,
									out vec3 worldMin, out vec3 worldMax)
{
	screenSpaceToNDC(cellMin);
	screenSpaceToNDC(cellMax);

	vec3[] corners = vec3[](vec3(cellMin.x, cellMin.y, cellMin.z), vec3(cellMax.x, cellMin.y, cellMin.z),
							vec3(cellMin.x, cellMax.y, cellMin.z), vec3(cellMax.x, cellMax.y, cellMin.z),
							vec3(cellMin.x, cellMin.y, cellMax.z), vec3(cellMax.x, cellMin.y, cellMax.z),
							vec3(cellMin.x, cellMax.y, cellMax.z), vec3(cellMax.x, cellMax.y, cellMax.z));

	worldMin = corners[0];
	ndcToWorldSpace(camera, worldMin);
	worldMax = corners[0];
	ndcToWorldSpace(camera, worldMax);

	for (int i = 1; i < 8; ++i)
	{
		vec3 corner = corners[i];
		ndcToWorldSpace(camera, corner);

		worldMin = min(worldMin, corner);
		worldMax = max(worldMax, corner);
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

	uint cameraIndex = gl_GlobalInvocationID.y;
	if (cameraIndex >= rat_CameraCount)
	{
		return;
	}

	vec3 cellMin = vec3(coordinate) / vec3(RAT_SCRATCH_PIPELINE_CONFIG_LIGHT_CELLS);
	vec3 cellMax = cellMin + vec3(1.0) / vec3(RAT_SCRATCH_PIPELINE_CONFIG_LIGHT_CELLS);

	RatScratchPipelineCell cell;
	unprojectScreenCellToWorldAABB(cellMin, cellMax, rat_Cameras[cameraIndex], cell.worldMin, cell.worldMax);

	uint offset = dimensions.x * dimensions.y * dimensions.z * cameraIndex;
	rat_WorldCells[cellIndex + offset] = cell;
}
