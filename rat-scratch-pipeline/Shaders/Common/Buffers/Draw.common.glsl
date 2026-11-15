#include "@Pipeline/Common/Types/BVH.common.glsl"
#include "@Pipeline/Common/Types/Draw.common.glsl"

restrict readonly buffer rat_ObjectInstancesBuffer
{
	RatScratchPipelineObjectInstance rat_ObjectInstances[];
};

restrict readonly buffer rat_ModelInstancesBuffer
{
	RatScratchPipelineModelInstance rat_ModelInstances[];
};

restrict readonly buffer rat_MeshInstancesBuffer
{
	RatScratchPipelineMeshInstance rat_MeshInstances[];
};

restrict readonly buffer rat_ModelsBuffer
{
	RatScratchPipelineModel rat_Models[];
};

restrict readonly buffer rat_MeshesBuffer
{
	RatScratchPipelineMesh rat_Meshes[];
};

restrict readonly buffer rat_MeshClustersBuffer
{
	RatScratchPipelineMeshCluster rat_MeshClusters[];
};

restrict readonly buffer rat_MeshClusterGroupsBuffer
{
	RatScratchPipelineMeshClusterGroup rat_MeshClusterGroups[];
};

restrict readonly buffer rat_MeshClusterToMeshBuffer
{
	uint rat_MeshClusterToMesh[];
};

restrict readonly buffer rat_MeshClusterNodesBuffer
{
	RatScratchPipelineMeshClusterNode rat_MeshClusterNodes[];
};

restrict readonly buffer rat_SkinnedMeshletBoundsBuffer
{
	RatScratchPipelineSkinnedMeshletBounds rat_SkinnedMeshletBounds[];
};

restrict readonly buffer rat_CamerasBuffer
{
	RatScratchPipelineCamera rat_Cameras[];
};

uniform RatScratchPipelineScene rat_Scene;

restrict readonly buffer rat_BLASInstancesBuffer
{
	RatScratchPipelineBLASInstance rat_BLASInstances[];
};

restrict readonly buffer rat_BVHNodesBuffer
{
	RatScratchPipelineRawBVHNode rat_BVHNodes[];
};

restrict readonly buffer rat_BVHNodeObjectIndicesBuffer
{
	uint rat_BVHNodeObjectIndices[];
};
