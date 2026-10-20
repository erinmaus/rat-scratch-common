layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

#include "@Generated/Pipeline/Config.common.glsl"
#include "@/Math/Common.common.glsl"
#include "@/Math/Vector.common.glsl"
#include "@Pipeline/Common/Types/ReflectionProbe.common.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Index.common.glsl"
#include "@Pipeline/Common/Cluster.common.glsl"

restrict readonly buffer rat_ReflectionProbesBuffer
{
	RatScratchPipelineReflectionProbe rat_ReflectionProbes[];
};

restrict buffer rat_ReflectionProbeCountIndicesBuffer
{
	uint rat_ReflectionProbeCountIndices[];
};

restrict readonly buffer rat_ActiveCamerasBuffer
{
	uint rat_ActiveCameras[];
};

uniform uint rat_ReflectionProbeCount;
uniform uint rat_ActiveCameraCount;
uniform uvec2 rat_ScreenSize;

bool boundsInsideCell(RatScratchPipelineCamera camera, vec3 boundsMin, vec3 boundsMax, vec2 cellMin, vec2 cellMax)
{
	vec4[RAT_SCRATCH_PIPELINE_CAMERA_PLANE_COUNT] planes;
	getCameraPlanes(camera, planes, cellMin, cellMax);

	return boundsInsideFrustum(planes, boundsMin, boundsMax);
}

void tryAddReflectinProbeToCell(uvec2 cellCoordinate, uint probeIndex, uint cameraIndex)
{
	uvec3 coordinate = uvec3(cellCoordinate, 0);
	uvec3 dimensions =
		uvec3(uvec2(ceil(vec2(rat_ScreenSize) / vec2(RAT_SCRATCH_PIPELINE_CONFIG_LIGHT_CELL_SIZE_IN_PIXELS))),
			  RAT_SCRATCH_PIPELINE_CONFIG_MAX_REFLECTION_PROBES_PER_CELL + 1);
	uint offset = dimensions.x * dimensions.y * dimensions.z * cameraIndex;
	uint index = coordinateToIndex(coordinate, dimensions);

	uint previousCount = atomicAdd(rat_ReflectionProbeCountIndices[index + offset], 1);
	if (previousCount < RAT_SCRATCH_PIPELINE_CONFIG_MAX_REFLECTION_PROBES_PER_CELL)
	{
		uvec3 probeCellCoordinate = uvec3(cellCoordinate, previousCount + 1);
		uint probeCellIndex = coordinateToIndex(probeCellCoordinate, dimensions);
		rat_ReflectionProbeCountIndices[probeCellIndex + offset] = probeIndex;
	}
}

void testReflectionProbe(RatScratchPipelineCamera camera, vec2 cellMin, vec2 cellMax, uvec2 cellCoordinate,
						 uint probeIndex, uint cameraIndex)
{
	RatScratchPipelineReflectionProbe reflectionProbe = rat_ReflectionProbes[probeIndex];
	vec3 boundsMin = reflectionProbe.positionDistance.xyz - vec3(reflectionProbe.positionDistance.w);
	vec3 boundsMax = reflectionProbe.positionDistance.xyz + vec3(reflectionProbe.positionDistance.w);

	if (boundsInsideCell(camera, boundsMin, boundsMax, cellMin, cellMax))
	{
		tryAddReflectinProbeToCell(cellCoordinate, probeIndex, cameraIndex);
	}
}

void computemain()
{
	uint cellIndex = gl_GlobalInvocationID.x;
	uvec2 dimensions = uvec2(ceil(vec2(rat_ScreenSize) / vec2(RAT_SCRATCH_PIPELINE_CONFIG_LIGHT_CELL_SIZE_IN_PIXELS)));
	uvec2 coordinate = indexToCoordinate(cellIndex, dimensions);
	if (coordinate.x >= dimensions.x || coordinate.y >= dimensions.y)
	{
		return;
	}

	uint activeCameraIndex = gl_GlobalInvocationID.z;
	if (activeCameraIndex >= rat_ActiveCameraCount)
	{
		return;
	}

	uint cameraIndex = rat_ActiveCameras[activeCameraIndex];
	RatScratchPipelineCamera camera = rat_Cameras[cameraIndex];

	uint i = min(gl_GlobalInvocationID.y * RAT_SCRATCH_PIPELINE_CONFIG_MAX_REFLECTION_PROBES_PER_THREAD,
				 rat_ReflectionProbeCount);
	uint j = min(i + RAT_SCRATCH_PIPELINE_CONFIG_MAX_REFLECTION_PROBES_PER_THREAD, rat_ReflectionProbeCount);

	vec2 cellMin, cellMax;
	getCellPlaneMinMax(coordinate, dimensions, cellMin, cellMax);

	for (uint k = i; k < j; ++k)
	{
		testReflectionProbe(camera, cellMin, cellMax, coordinate, k, cameraIndex);
	}
}
