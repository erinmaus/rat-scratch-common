layout(local_size_x = 64, local_size_y = 1) in;

#include "@Generated/Pipeline/Config.common.glsl"
#include "@Pipeline/Common/Types/Indirect.common.glsl"
#include "@Pipeline/Common/Buffers/Draw.common.glsl"
#include "@Pipeline/Common/Buffers/Materials.common.glsl"

restrict readonly buffer rat_DrawsBuffer
{
	RatScratchPipelineDraw rat_Draws[];
};

restrict buffer rat_OutputDrawsBuffer
{
	RatScratchPipelineDraw rat_OutputDraws[];
};

restrict buffer rat_IndirectDrawsBuffer
{
	RatScratchPipelineIndirectDraw rat_IndirectDraws[];
};

#include "./Cull.common.glsl"

uniform uint rat_DrawCount;
uniform uint rat_CameraCount;

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
	draw.cameraIndex = cameraIndex;

	RatScratchPipelineObjectInstance objectInstance = rat_ObjectInstances[draw.objectInstanceIndex];
	RatScratchPipelineModel model = rat_Models[draw.modelIndex];
	RatScratchPipelineMesh mesh = rat_Meshes[draw.meshIndex];
	RatScratchPipelineMeshClusterGroup clusterGroup = rat_MeshClusterGroups[draw.groupIndex];
	RatScratchPipelineCamera camera = rat_Cameras[cameraIndex];

	mat4 worldTransform = objectInstance.worldTransform * model.localTransform;

	if (!ratSelectGroupLOD(camera, clusterGroup, worldTransform))
	{
		// return;
	}

	uint selectedClusters[RAT_SCRATCH_PIPELINE_CONFIG_LOD_MAX_PENDING_CLUSTER_DRAWS];
	uint currentClusterCount = 0;

	uint clusterStartIndex = mesh.clusterIndexCount.x + clusterGroup.clusterIndexCount.x;
	uint clusterStopIndex = clusterStartIndex + clusterGroup.clusterIndexCount.y;
	for (uint i = clusterStartIndex; i < clusterStopIndex; ++i)
	{
		// if (ratSelectClusterLOD(camera, rat_MeshClusters[i], mesh.clusterGroupIndexCount.x, worldTransform))
		{
			selectedClusters[currentClusterCount] = i;
			++currentClusterCount;

			if (currentClusterCount >= RAT_SCRATCH_PIPELINE_CONFIG_LOD_MAX_PENDING_CLUSTER_DRAWS)
			{
				ratEmitClusterDraws(draw, cameraIndex, selectedClusters, currentClusterCount);
			}
		}
	}

	ratEmitClusterDraws(draw, cameraIndex, selectedClusters, currentClusterCount);
}
