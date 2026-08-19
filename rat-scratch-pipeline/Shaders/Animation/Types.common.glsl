struct RatScratchAnimationChannelKeyFrame
{
	float time;
	vec4 value;
};

struct RatScratchAnimationChannel
{
	uint boneIndex;
	uint skeletonIndex;
	uvec2 translationKeyFrameIndexCount;
	uvec2 rotationKeyFrameIndexCount;
	uvec2 scaleKeyFrameIndexCount;
};

struct RatScratchPlaybackTransformInfo
{
	uint animationChannelIndex;
	uint playbackStateIndex;
	uint playbackTransformIndex;
};

struct RatScratchPlaybackState
{
	float time;
	float inverseWeight;
};

struct RatScratchPlaybackTransform
{
	vec4 translation;
	vec4 rotation;
	vec4 scale;
};

struct RatScratchSkeletonBone
{
	int parentBoneIndex;
	mat4 inverseBindPose;
	vec4 translation;
	vec4 rotation;
	vec4 scale;
};

struct RatScratchSkeleton
{
	uvec2 boneIndexCount;
};

struct RatScratchPlaybackGroupBone
{
	uvec2 playbackTransformsIndexCount;
	uint boneTransformIndex;
};

struct RatScratchComposeBoneMap
{
	uint skeletonIndex;
	uint boneIndex;
	uint boneTransformIndex;
};
