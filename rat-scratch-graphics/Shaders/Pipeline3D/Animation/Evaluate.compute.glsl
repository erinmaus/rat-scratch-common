layout(local_size_x = 64) in;

#include "@/Math/Common.common.glsl"
#include "@/Math/Quaternion.common.glsl"
#include "@Pipeline/Animation/Types.common.glsl"

readonly restrict buffer rat_AnimationChannelKeyFramesBuffer
{
	RatScratchAnimationChannelKeyFrame rat_AnimationChannelKeyFrames[];
};

readonly restrict buffer rat_SkeletonsBuffer
{
	RatScratchSkeleton rat_Skeletons[];
};

readonly restrict buffer rat_SkeletonBonesBuffer
{
	RatScratchSkeletonBone rat_SkeletonBones[];
};

readonly restrict buffer rat_AnimationChannelsBuffer
{
	RatScratchAnimationChannel rat_AnimationChannels[];
};

readonly restrict buffer rat_PlaybackTransformInfoBuffer
{
	RatScratchPlaybackTransformInfo rat_PlaybackTransformInfo[];
};

readonly restrict buffer rat_PlaybackStatesBuffer
{
	RatScratchPlaybackState rat_PlaybackStates[];
};

restrict buffer rat_PlaybackTransformsBuffer
{
	RatScratchPlaybackTransform rat_PlaybackTransforms[];
};

bool findKeyFrameCurrentNextIndex(uvec2 keyFramesIndexCount, float time, out uint currentKeyFrameIndex,
								  out uint nextKeyFrameIndex)
{
	if (keyFramesIndexCount.y == 0)
	{
		return false;
	}

	int start = int(keyFramesIndexCount.x);
	int stop = int(start + keyFramesIndexCount.y - 1);

	int result = int(start);
	while (start <= stop)
	{
		int midPoint = (start + stop) / 2;
		if (rat_AnimationChannelKeyFrames[midPoint].time <= time)
		{
			result = midPoint;
			start = midPoint + 1;
		}
		else
		{
			stop = midPoint - 1;
		}
	}

	currentKeyFrameIndex = uint(max(result, 0));
	nextKeyFrameIndex = min(currentKeyFrameIndex + 1, keyFramesIndexCount.x + keyFramesIndexCount.y - 1);

	return true;
}

float getKeyFrameDelta(float time, uint currentKeyFrameIndex, uint nextKeyFrameIndex)
{
	float deltaWidth = max(rat_AnimationChannelKeyFrames[nextKeyFrameIndex].time -
							   rat_AnimationChannelKeyFrames[currentKeyFrameIndex].time,
						   RAT_SCRATCH_EPSILON);
	float delta = (time - rat_AnimationChannelKeyFrames[currentKeyFrameIndex].time) / deltaWidth;
	return clamp(delta, 0.0, 1.0);
}

void getKeyFrameValues(uint currentKeyFrameIndex, uint nextKeyFrameIndex, out vec4 currentKeyFrameValue,
					   out vec4 nextKeyFrameValue)
{
	currentKeyFrameValue = rat_AnimationChannelKeyFrames[currentKeyFrameIndex].value;
	nextKeyFrameValue = rat_AnimationChannelKeyFrames[nextKeyFrameIndex].value;
}

uniform uint rat_PlaybackTransformInfoCount;

void computemain()
{
	uint index = gl_GlobalInvocationID.x;
	if (index >= rat_PlaybackTransformInfoCount)
	{
		return;
	}

	RatScratchPlaybackTransformInfo info = rat_PlaybackTransformInfo[index];
	RatScratchPlaybackState state = rat_PlaybackStates[info.playbackStateIndex];
	RatScratchAnimationChannel channel = rat_AnimationChannels[info.animationChannelIndex];
	uint globalBoneIndex = rat_Skeletons[channel.skeletonIndex].boneIndexCount.x + channel.boneIndex;
	float time = state.time;
	vec4 inverseWeight = vec4(state.inverseWeight);

	uint currentKeyFrameIndex = 0, nextKeyFrameIndex = 0;
	if (findKeyFrameCurrentNextIndex(channel.translationKeyFrameIndexCount, time, currentKeyFrameIndex,
									 nextKeyFrameIndex))
	{
		float delta = getKeyFrameDelta(time, currentKeyFrameIndex, nextKeyFrameIndex);

		vec4 fromValue = vec4(0.0), toValue = vec4(0.0);
		getKeyFrameValues(currentKeyFrameIndex, nextKeyFrameIndex, fromValue, toValue);

		rat_PlaybackTransforms[index].translation = mix(fromValue, toValue, delta) * inverseWeight;
	}
	else
	{
		rat_PlaybackTransforms[index].translation = rat_SkeletonBones[globalBoneIndex].translation * inverseWeight;
	}

	if (findKeyFrameCurrentNextIndex(channel.rotationKeyFrameIndexCount, time, currentKeyFrameIndex, nextKeyFrameIndex))
	{
		float delta = getKeyFrameDelta(time, currentKeyFrameIndex, nextKeyFrameIndex);

		vec4 fromValue = quaternionIdentity(), toValue = quaternionIdentity();
		getKeyFrameValues(currentKeyFrameIndex, nextKeyFrameIndex, fromValue, toValue);

		rat_PlaybackTransforms[index].rotation = normalize(quaternionSlerp(fromValue, toValue, delta)) * inverseWeight;
	}
	else
	{
		rat_PlaybackTransforms[index].rotation = rat_SkeletonBones[globalBoneIndex].rotation * inverseWeight;
	}

	if (findKeyFrameCurrentNextIndex(channel.scaleKeyFrameIndexCount, time, currentKeyFrameIndex, nextKeyFrameIndex))
	{
		float delta = getKeyFrameDelta(time, currentKeyFrameIndex, nextKeyFrameIndex);

		vec4 fromValue = vec4(0.0), toValue = vec4(0.0);
		getKeyFrameValues(currentKeyFrameIndex, nextKeyFrameIndex, fromValue, toValue);

		rat_PlaybackTransforms[index].scale = mix(fromValue, toValue, delta) * inverseWeight;
	}
	else
	{
		rat_PlaybackTransforms[index].scale = rat_SkeletonBones[globalBoneIndex].scale * inverseWeight;
	}
}
