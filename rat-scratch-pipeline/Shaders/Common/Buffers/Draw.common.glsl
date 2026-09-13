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

restrict readonly buffer rat_MeshletsBuffer
{
	RatScratchPipelineMeshlet rat_Meshlets[];
};

restrict readonly buffer rat_SkinnedMeshletBoundsBuffer
{
	RatScratchPipelineSkinnedMeshletBounds rat_SkinnedMeshletBounds[];
};

restrict readonly buffer rat_CamerasBuffer
{
	RatScratchPipelineCamera rat_Cameras[];
};
