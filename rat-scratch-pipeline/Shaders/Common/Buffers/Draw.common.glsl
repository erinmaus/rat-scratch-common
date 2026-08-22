#include "@Pipeline/Common/Types/Draw.common.glsl"

restrict readonly buffer rat_ObjectInstancesBuffer
{
	RatScratchPipelineObjectInstance rat_ObjectInstances[];
};

restrict readonly buffer rat_AnimationPlaybacksBuffer
{
	RatScratchPipelineAnimationPlayback rat_AnimationPlaybacks[];
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

restrict readonly buffer rat_MeshsBuffer
{
	RatScratchPipelineMesh rat_Meshs[];
};

restrict readonly buffer rat_MeshletsBuffer
{
	RatScratchPipelineMeshlet rat_Meshlets[];
};

restrict readonly buffer rat_SkinnedMeshletBoundssBuffer
{
	RatScratchPipelineSkinnedMeshletBounds rat_SkinnedMeshletBoundss[];
};

restrict readonly buffer rat_CamerasBuffer
{
	RatScratchPipelineCamera rat_Cameras[];
};
