layout(local_size_x = 64) in;

#include "@/Math/Transform.common.glsl"
#include "@/Pipeline3D/Animation/Types.common.glsl"

readonly restrict buffer rat_PlaybackGroupBonesBuffer
{
	RatScratchPlaybackGroupBone rat_PlaybackGroupBones[];
};

writeonly restrict buffer rat_MeshInstanceBoneTransformsBuffer
{
	mat4 rat_MeshInstanceBoneTransforms[];
};

restrict buffer rat_PlaybackTransformsBuffer
{
	RatScratchPlaybackTransform rat_PlaybackTransforms[];
};

uniform uint rat_PlaybackGroupCount;

void computemain()
{
	uint index = gl_GlobalInvocationID.x;
	if (index >= rat_PlaybackGroupCount)
	{
		return;
	}

	RatScratchPlaybackGroupBone boneGroup = rat_PlaybackGroupBones[index];

	vec4 translation = vec4(0.0), rotation = vec4(0.0), scale = vec4(0.0);
	for (uint i = 0; i < boneGroup.playbackTransformsIndexCount.y; ++i)
	{
		translation += rat_PlaybackTransforms[boneGroup.playbackTransformsIndexCount.x + i].translation;
		rotation += rat_PlaybackTransforms[boneGroup.playbackTransformsIndexCount.x + i].rotation;
		scale += rat_PlaybackTransforms[boneGroup.playbackTransformsIndexCount.x + i].scale;
	}

	rotation = normalize(rotation);

	rat_MeshInstanceBoneTransforms[boneGroup.boneTransformIndex] =
		transformCompose(translation.xyz, rotation, scale.xyz);
}
