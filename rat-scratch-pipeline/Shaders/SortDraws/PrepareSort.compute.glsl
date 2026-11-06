#pragma language glsl4

layout(local_size_x = 64) in;

#include "@Pipeline/Common/Types/Indirect.common.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "./Buffers.common.glsl"

restrict readonly buffer rat_DrawsBuffer
{
	RatScratchPipelineDraw rat_Draws[];
};

restrict readonly buffer rat_IndirectDrawsBuffer
{
	RatScratchPipelineIndirectDraw rat_IndirectDraws[];
};

shared uint rat_SharedDrawCount;

uniform float rat_DepthSign;

void computemain()
{
	if (gl_LocalInvocationID.x == 0)
	{
		rat_SharedDrawCount = rat_IndirectDraws[0].instanceCount;
	}

	barrier();

	uint drawIndex = gl_GlobalInvocationID.x;
	if (drawIndex >= rat_SharedDrawCount)
	{
		return;
	}

	RatScratchPipelineDraw draw = rat_Draws[drawIndex];

	mat4 viewTransform = rat_Cameras[draw.cameraIndex].viewTransform;
	mat4 worldTransform = rat_ObjectInstances[draw.objectInstanceIndex].worldTransform;
	mat4 localTransform = rat_Models[draw.modelIndex].localTransform;

	mat4 viewWorldLocalTransform = viewTransform * worldTransform * localTransform;
	vec4 clusterPosition =
		viewWorldLocalTransform * vec4(rat_MeshClusters[draw.clusterIndex].center, 1.0);

	float depthValue = rat_DepthSign * clusterPosition.z;
	uint depthKey = depthToDepthKey(depthValue);

	rat_SortedClusterElements[drawIndex].depthKey = depthKey;
	rat_SortedClusterElements[drawIndex].drawIndex = drawIndex;
	rat_SortedClusterElements[drawIndex].depthValue = depthValue;
}
