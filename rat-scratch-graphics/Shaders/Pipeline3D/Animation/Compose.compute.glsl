layout(local_size_x = 64) in;

#include "@/Math/Transform.common.glsl"
#include "@/Pipeline3D/Animation/Types.common.glsl"

readonly restrict buffer rat_SkeletonsBuffer
{
	RatScratchSkeleton rat_Skeletons[];
};

readonly restrict buffer rat_SkeletonBonesBuffer
{
	RatScratchSkeletonBone rat_SkeletonBones[];
};

restrict readonly buffer rat_ComposeBoneMapBuffer
{
	RatScratchComposeBoneMap rat_ComposeBoneMap[];
};

restrict buffer rat_MeshInstanceBoneTransformsBuffer
{
	mat4 rat_MeshInstanceBoneTransforms[];
};

uniform uint rat_ComposeBoneMapCount;

void computemain()
{
	uint index = gl_GlobalInvocationID.x;
	if (index >= rat_ComposeBoneMapCount)
	{
		return;
	}

	RatScratchComposeBoneMap boneInfo = rat_ComposeBoneMap[index];
	uint baseTransformIndex = boneInfo.boneTransformIndex - boneInfo.boneIndex;
	uint boneGlobalIndex = rat_Skeletons[boneInfo.skeletonIndex].boneIndexCount.x + boneInfo.boneIndex;

	mat4 currentTransform = rat_MeshInstanceBoneTransforms[boneInfo.boneTransformIndex];

	int nextBoneIndex = rat_SkeletonBones[boneGlobalIndex].parentBoneIndex;
	if (nextBoneIndex >= 0)
	{
		uint nextIndex = baseTransformIndex + uint(nextBoneIndex);
		mat4 parentTransform = rat_MeshInstanceBoneTransforms[nextIndex];
		currentTransform = parentTransform * currentTransform;
	}

	rat_MeshInstanceBoneTransforms[boneInfo.boneTransformIndex] = currentTransform;
}
