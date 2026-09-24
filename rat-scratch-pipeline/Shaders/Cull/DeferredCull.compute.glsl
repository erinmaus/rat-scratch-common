layout(local_size_x = 64, local_size_y = 1) in;

#include "@Pipeline/Common/Types/Indirect.common.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Buffers/Materials.common.glsl"
#include "@Pipeline/Common/Buffers/Planes.common.glsl"

restrict readonly buffer rat_DrawsBuffer
{
	RatScratchPipelineDraw rat_Draws[];
};

restrict buffer rat_DepthDrawsBuffer
{
	RatScratchPipelineDraw rat_DepthDraws[];
};

restrict buffer rat_DepthDiscardDrawsBuffer
{
	RatScratchPipelineDraw rat_DepthDiscardDraws[];
};

const RAT_SCRATCH_PIPELINE_INDIRECT_DEPTH_DISCARD_INDEX = 0;
const RAT_SCRATCH_PIPELINE_INDIRECT_DEPTH_INDEX = 1;

restrict buffer rat_IndirectDrawsBuffer
{
	RatScratchPipelineIndirectDraw rat_IndirectDraws[];
};

uniform uint rat_DrawCount;
uniform uint rat_CameraCount;

void transformSphere(mat4 worldTransform, inout vec3 position, inout float radius)
{
	position = (worldTransform * vec4(position, 1.0)).xyz;

	vec3 c0 = worldTransform[0].xyz;
	vec3 c1 = worldTransform[1].xyz;
	vec3 c2 = worldTransform[2].xyz;

	radius *= sqrt(dot(c0, c0) + dot(c1, c1) + dot(c2, c2));
}

void computemain()
{
	uint drawIndex = gl_GlobalInvocationID.x;
	if (drawIndex >= rat_DrawCount)
	{
		return;
	}

	uint cameraIndex = gl_GlobalInvocationID.y;
	if (cameraIndex >= rat_CameraCount)
	{
		return;
	}

	RatScratchPipelineDraw draw = rat_Draws[drawIndex];
	RatScratchPipelineObjectInstance objectInstance = rat_ObjectInstances[draw.objectInstanceIndex];
	RatScratchPipelineModelInstance modelInstance = rat_ModelInstances[draw.meshInstanceIndex];
	RatScratchPipelineMeshInstance meshInstance = rat_MeshInstances[draw.meshInstanceIndex];
	RatScratchPipelineMaterialInstance materialInstance = rat_MaterialInstances[meshInstance.materialInstanceIndex];
	RatScratchPipelineMeshlet meshlet = rat_Meshlets[draw.meshletIndex];
	RatScratchPipelineCameraPlanes cameraPlanes = rat_CameraPlanes[cameraIndex];

	vec3 meshletBoundsPosition = meshlet.staticCenterRadius.xyz;
	float meshletBoundsRadius = meshlet.staticCenterRadius.w;

	transformSphere(objectInstance.worldTransform * modelInstance.localTransform, meshletBoundsPosition,
					meshletBoundsRadius);

	bool isInsideFrustum = true;
	for (uint i = 0; i < RAT_SCRATCH_PIPELINE_CAMERA_PLANE_COUNT; ++i)
	{
		float distanceFromPlane = dot(cameraPlanes.planes[i].xyz, meshletBoundsPosition) + cameraPlanes.planes[i].w;
		if (distanceFromPlane < -meshletBoundsRadius)
		{
			isInsideFrustum = false;
			break;
		}
	}

	if (!isInsideFrustum)
	{
		return;
	}

	draw.cameraIndex = cameraIndex;
	if (materialInstance.hasAlphaDiscard)
	{
		uint index = atomicAdd(rat_IndirectDraws[RAT_SCRATCH_PIPELINE_INDIRECT_DEPTH_DISCARD_INDEX].instanceCount, 1);
		rat_DepthDiscardDraws[index] = draw;
	}
	else
	{
		uint index = atomicAdd(rat_IndirectDraws[RAT_SCRATCH_PIPELINE_INDIRECT_DEPTH_INDEX].instanceCount, 1);
		rat_DepthDraws[index] = draw;
	}
}
