local PATH = ...
local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local BoneInstance = require("rat-scratch-graphics").Graphics3D.BoneInstance
local Module = require("lib.rat-scratch-module")
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local ShaderPreprocessor = require("rat-scratch-graphics").ShaderPreprocessor
local Transform = require("rat-scratch-math").Transform

--- @alias RatScratch.Pipeline.AnimationPipelineShaderRole
--- | "evaluate"
--- | "copy"
--- | "blend"
--- | "compose"
--- | "apply_inverse_bind_pose"

--- @class RatScratch.Pipeline.AnimationPipeline : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Pipeline.AnimationPipeline
--- @field private skeletons table<RatScratch.Graphics.Graphics3D.Skeleton, { animations: RatScratch.Graphics.Graphics3D.Animation[] }>
--- @field private skeletonsByIndex RatScratch.Graphics.Graphics3D.Skeleton[]
--- @field private skeletonsBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Graphics.Graphics3D.Skeleton>
--- @field private skeletonBonesBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Graphics.Graphics3D.Skeleton>
--- @field private animations table<RatScratch.Graphics.Graphics3D.Animation, { skeleton: RatScratch.Graphics.Graphics3D.Skeleton }>
--- @field private animationsByIndex RatScratch.Graphics.Graphics3D.Animation[]
--- @field private animationChannelsBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Graphics.Graphics3D.Animation>
--- @field private animationChannelKeyFramesBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Graphics.Graphics3D.KeyFrames>
--- @field private animators table<RatScratch.Graphics.Graphics3D.Animator, { groups: table<RatScratch.Graphics.Graphics3D.AnimatorGroup, boolean> }>
--- @field private playbackStatesBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Graphics.Graphics3D.AnimatorGroup>
--- @field private playbackTransformsBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Graphics.Graphics3D.BoneInstance>
--- @field private playbackGroupTransformsBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Graphics.Graphics3D.AnimatorGroup>
--- @field private playbackTransformInfoBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Graphics.Graphics3D.BoneInstance>
--- @field private playbackGroupBonesBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Graphics.Graphics3D.AnimatorGroup>
--- @field private boneTransformsBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Graphics.Graphics3D.Animator>
--- @field private globalBoneMapBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Graphics.Graphics3D.Animator>
--- @field private animatorsByIndex RatScratch.Graphics.Graphics3D.Animator[]
--- @field private animatorGroupBones table<RatScratch.Graphics.Graphics3D.AnimatorGroup, { bones: RatScratch.Graphics.Graphics3D.BoneInstance[], boneToInstance: table<RatScratch.Graphics.Graphics3D.Bone, RatScratch.Graphics.Graphics3D.BoneInstance> }>
--- @field private animatorGroups table<RatScratch.Graphics.Graphics3D.AnimatorGroup, RatScratch.Graphics.Graphics3D.Animator>
--- @field private dirtyAnimatorGroups table<RatScratch.Graphics.Graphics3D.AnimatorGroup, boolean>
--- @field private dirtyAnimatorGroupsByIndex RatScratch.Graphics.Graphics3D.AnimatorGroup[]
--- @field private boneMapBuffers RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Graphics.Graphics3D.Animator>[]
--- @field private boneMapBufferCount integer
--- @field private shaders table<RatScratch.Pipeline.AnimationPipelineShaderRole, love.Shader>
local AnimationPipeline = Object()

AnimationPipeline.SKELETON_BONE_FORMAT = {
	{ location = 0, name = "parentBone", format = "uint32" },
	{ location = 1, name = "inverseBindPose", format = "floatmat4x4" },
	{ location = 2, name = "translation", format = "floatvec4" },
	{ location = 3, name = "rotation", format = "floatvec4" },
	{ location = 4, name = "scale", format = "floatvec4" },
}

AnimationPipeline.SKELETON_FORMAT = {
	{ location = 0, name = "boneIndexCount", format = "uint32vec2" },
}

AnimationPipeline.DEFAULT_SKELETONS_BUFFER_COUNT = 64
AnimationPipeline.DEFAULT_SKELETON_BONES_BUFFER_COUNT = AnimationPipeline.DEFAULT_SKELETONS_BUFFER_COUNT
	* 128

AnimationPipeline.ANIMATION_CHANNELS_FORMAT = {
	{ location = 0, name = "boneIndex", format = "uint32" },
	{ location = 1, name = "skeletonIndex", format = "uint32" },
	{
		location = 2,
		name = "translationKeyFrameIndexCount",
		format = "uint32vec2",
	},
	{
		location = 3,
		name = "rotationKeyFrameIndexCount",
		format = "uint32vec2",
	},
	{ location = 4, name = "scaleKeyFrameIndexCount", format = "uint32vec2" },
}

AnimationPipeline.ANIMATION_CHANNEL_KEY_FRAMES_FORMAT = {
	{ location = 0, name = "time", format = "float" },
	{ location = 1, name = "value", format = "floatvec4" },
}

AnimationPipeline.DEFAULT_ANIMATIONS_COUNT = 128
AnimationPipeline.DEFAULT_ANIMATION_CHANNELS_COUNT = AnimationPipeline.DEFAULT_ANIMATIONS_COUNT
	* 64
AnimationPipeline.DEFAULT_ANIMATION_CHANNELS_KEY_FRAMES_COUNT = AnimationPipeline.DEFAULT_ANIMATION_CHANNELS_COUNT
	* 3
	* 128

AnimationPipeline.PLAYBACK_STATES_FORMAT = {
	{ location = 0, name = "time", format = "float" },
	{ location = 1, name = "inverseWeight", format = "float" },
}

AnimationPipeline.PLAYBACK_TRANSFORMS_FORMAT = {
	{ location = 0, name = "translation", format = "floatvec4" },
	{ location = 1, name = "rotation", format = "floatvec4" },
	{ location = 2, name = "scale", format = "floatvec4" },
}

AnimationPipeline.PLAYBACK_TRANSFORM_INFO_FORMAT = {
	{ location = 0, name = "animationChannelIndex", format = "uint32" },
	{ location = 1, name = "playbackStateIndex", format = "uint32" },
	{ location = 2, name = "playbackTransformIndex", format = "uint32" },
}

AnimationPipeline.PLAYBACK_GROUP_BONES_FORMAT = {
	{
		location = 0,
		name = "playbackTransformsIndexCount",
		format = "uint32vec2",
	},
	{ location = 1, name = "boneTransformIndex", format = "uint32" },
}

AnimationPipeline.COMPOSE_GROUP_BONE_MAP_FORMAT = {
	{ location = 0, name = "skeletonIndex", format = "uint32" },
	{ location = 1, name = "boneIndex", format = "uint32" },
	{ location = 2, name = "boneTransformIndex", format = "uint32" },
}

AnimationPipeline.MESH_INSTANCE_BONE_TRANSFORMS_FORMAT = {
	{ location = 0, name = "transform", format = "floatmat4x4" },
}

AnimationPipeline.DEFAULT_ANIMATORS_COUNT = 128
AnimationPipeline.DEFAULT_PLAYBACK_STATES_COUNT = AnimationPipeline.DEFAULT_ANIMATIONS_COUNT
	* 4
AnimationPipeline.DEFAULT_PLAYBACK_TRANSFORM_INFO_COUNT = AnimationPipeline.DEFAULT_PLAYBACK_STATES_COUNT
	* 64
AnimationPipeline.DEFAULT_PLAYBACK_TRANSFORMS_COUNT =
	AnimationPipeline.DEFAULT_PLAYBACK_TRANSFORM_INFO_COUNT
AnimationPipeline.DEFAULT_PLAYBACK_GROUP_BONES_COUNT =
	AnimationPipeline.DEFAULT_PLAYBACK_TRANSFORM_INFO_COUNT
AnimationPipeline.DEFAULT_COMPOSE_TRANSFORM_BONE_MAP_COUNT =
	AnimationPipeline.DEFAULT_PLAYBACK_TRANSFORM_INFO_COUNT
AnimationPipeline.DEFAULT_MESH_INSTANCE_BONE_TRANSFORMS_COUNT = AnimationPipeline.DEFAULT_ANIMATIONS_COUNT
	* 64
AnimationPipeline.DEFAULT_BONE_MAP_TRANSFORMS_COUNT =
	AnimationPipeline.DEFAULT_MESH_INSTANCE_BONE_TRANSFORMS_COUNT

function AnimationPipeline:new()
	self.skeletons = {}
	self.skeletonsByIndex = {}
	self.skeletonsBuffer = PipelineBuffer(
		AnimationPipeline.SKELETON_FORMAT,
		{ shaderstorage = true },
		AnimationPipeline.DEFAULT_SKELETONS_BUFFER_COUNT
	)
	self.skeletonBonesBuffer = PipelineBuffer(
		AnimationPipeline.SKELETON_BONE_FORMAT,
		{ shaderstorage = true },
		AnimationPipeline.DEFAULT_SKELETON_BONES_BUFFER_COUNT
	)

	self.animations = {}
	self.animationsByIndex = {}
	self.animationChannelsBuffer = PipelineBuffer(
		AnimationPipeline.ANIMATION_CHANNELS_FORMAT,
		{ shaderstorage = true },
		AnimationPipeline.DEFAULT_ANIMATION_CHANNELS_COUNT
	)
	self.animationChannelKeyFramesBuffer = PipelineBuffer(
		AnimationPipeline.ANIMATION_CHANNEL_KEY_FRAMES_FORMAT,
		{ shaderstorage = true },
		AnimationPipeline.DEFAULT_ANIMATION_CHANNELS_KEY_FRAMES_COUNT
	)

	self.animators = {}
	self.animatorsByIndex = {}
	self.playbackStatesBuffer = PipelineBuffer(
		AnimationPipeline.PLAYBACK_STATES_FORMAT,
		{ shaderstorage = true },
		AnimationPipeline.DEFAULT_PLAYBACK_STATES_COUNT
	)
	self.playbackTransformsBuffer = PipelineBuffer(
		AnimationPipeline.PLAYBACK_TRANSFORMS_FORMAT,
		{ shaderstorage = true },
		AnimationPipeline.DEFAULT_PLAYBACK_TRANSFORMS_COUNT
	)
	self.playbackGroupTransformsBuffer = PipelineBuffer(
		AnimationPipeline.PLAYBACK_TRANSFORMS_FORMAT,
		{ shaderstorage = true },
		AnimationPipeline.DEFAULT_PLAYBACK_TRANSFORMS_COUNT
	)
	self.playbackTransformInfoBuffer = PipelineBuffer(
		AnimationPipeline.PLAYBACK_TRANSFORM_INFO_FORMAT,
		{ shaderstorage = true },
		AnimationPipeline.DEFAULT_PLAYBACK_TRANSFORM_INFO_COUNT
	)
	self.playbackGroupBonesBuffer = PipelineBuffer(
		AnimationPipeline.PLAYBACK_GROUP_BONES_FORMAT,
		{ shaderstorage = true },
		AnimationPipeline.DEFAULT_PLAYBACK_GROUP_BONES_COUNT
	)
	self.boneTransformsBuffer = PipelineBuffer(
		AnimationPipeline.MESH_INSTANCE_BONE_TRANSFORMS_FORMAT,
		{ shaderstorage = true },
		AnimationPipeline.DEFAULT_MESH_INSTANCE_BONE_TRANSFORMS_COUNT
	)
	self.globalBoneMapBuffer = PipelineBuffer(
		AnimationPipeline.COMPOSE_GROUP_BONE_MAP_FORMAT,
		{ shaderstorage = true },
		AnimationPipeline.DEFAULT_BONE_MAP_TRANSFORMS_COUNT
	)

	self.animatorGroupBones = {}
	self.animatorGroups = {}
	self.dirtyAnimatorGroups = {}
	self.dirtyAnimatorGroupsByIndex = {}

	self.boneMapBuffers = {}
	self.boneMapBufferCount = 0

	self.shaders = {}
end

--- @return love.graphics.GraphicsBuffer
function AnimationPipeline:getBoneTransforms()
	return self.boneTransformsBuffer:getBuffer()
end

--- @param skeleton RatScratch.Graphics.Graphics3D.Skeleton
function AnimationPipeline:addSkeleton(skeleton)
	assert(
		not self.skeletons[skeleton],
		"skeleton already exists in animation pipeline"
	)

	self.skeletons[skeleton] = { animations = {} }
	table.insert(self.skeletonsByIndex, skeleton)
	self.skeletonsBuffer:register(skeleton, 1)
	self.skeletonBonesBuffer:register(skeleton, skeleton:getBoneCount())

	self.isAnimationDataDirty = true
end

function AnimationPipeline:removeSkeleton(skeleton)
	assert(
		self.skeletons[skeleton],
		"skeleton does not exist in animation pipeline"
	)

	-- TODO
end

--- @param animation RatScratch.Graphics.Graphics3D.Animation
--- @param skeleton RatScratch.Graphics.Graphics3D.Skeleton
function AnimationPipeline:addAnimation(animation, skeleton)
	assert(
		not self.animations[animation],
		"animation already exists in animation pipeline"
	)
	assert(
		self.skeletons[skeleton],
		"skeleton does not exist in animation pipeline"
	)

	self.animations[animation] = { skeleton = skeleton }
	table.insert(self.animationsByIndex, animation)
	table.insert(self.skeletons[skeleton].animations, animation)

	self.animationChannelsBuffer:register(
		animation,
		animation:getChannelCount()
	)

	for i = 1, animation:getChannelCount() do
		local animationChannel = animation:getChannel(i)

		for j = 1, animationChannel:getKeyedPropertyCount() do
			local keyedProperty = animationChannel:getKeyedProperty(j)
			self.animationChannelKeyFramesBuffer:register(
				keyedProperty,
				keyedProperty:getFrameCount()
			)

			for k = 1, keyedProperty:getFrameCount() do
				local keyFrame = keyedProperty:getFrame(k)

				local time = keyFrame.time
				local x, y, z, w = keyFrame.value:get()
				x, y, z, w = x or 0, y or 0, z or 0, w or 1

				self.animationChannelKeyFramesBuffer:set(
					keyedProperty,
					k,
					1,
					time,
					x,
					y,
					z,
					w
				)
			end
		end
	end

	self.isAnimationDataDirty = true
end

function AnimationPipeline:removeAnimation(animation)
	assert(
		self.animations[animation],
		"animation does not exist in animation pipeline"
	)

	-- TODO
end

--- @param animator RatScratch.Graphics.Graphics3D.Animator
function AnimationPipeline:addAnimator(animator)
	assert(
		not self.animators[animator],
		"animator already exists in animation pipeline"
	)

	assert(
		self.skeletons[animator:getSkeleton()],
		"skeleton does not exist in animation pipeline"
	)

	self.animators[animator] = {}
	table.insert(self.animatorsByIndex, animator)

	self.boneTransformsBuffer:register(
		animator,
		animator:getSkeleton():getBoneCount()
	)

	self.globalBoneMapBuffer:registerOrResize(
		animator,
		animator:getSkeleton():getBoneCount()
	)

	animator:attachToAnimationPipeline(self)
	self.isAnimatorDataDirty = true
end

--- @param animator RatScratch.Graphics.Graphics3D.Animator
function AnimationPipeline:removeAnimator(animator)
	assert(
		self.animators[animator],
		"animator does not exist in animation pipeline"
	)

	animator:detachFromAnimationPipeline(self)

	-- TODO
end

--- @param animator RatScratch.Graphics.Graphics3D.Animator
--- @return integer, integer
function AnimationPipeline:getAnimatorBoneIndexCount(animator)
	assert(
		self.animators[animator],
		"animator does not exist in animation pipeline"
	)

	return self.boneTransformsBuffer:getIndexCount(animator)
end

do
	local cacheBone = {}
	local cacheTransposedInverseBindPose = love.math.newTransform()

	--- @private
	function AnimationPipeline:_refreshAnimationData()
		local boneBuffer = cacheBone
		local transposedInverseBindPose = cacheTransposedInverseBindPose

		for _, skeleton in ipairs(self.skeletonsByIndex) do
			local skeletonInfo = self.skeletons[skeleton]
			local skeletonIndex = self.skeletonsBuffer:getIndexCount(skeleton)

			local bonesIndex, bonesCount =
				self.skeletonBonesBuffer:getIndexCount(skeleton)
			self.skeletonsBuffer:set(skeleton, 1, 1, bonesIndex - 1, bonesCount)

			for i = 1, skeleton:getBoneCount() do
				local bone = skeleton:getBone(i)

				Table.clear(boneBuffer)
				Table.append(
					boneBuffer,
					bone:getParent() and (bone:getParent():getIndex() - 1) or -1
				)

				Transform.transposeTransform(
					bone:getInverseBindPoseTransform(),
					transposedInverseBindPose
				)
				Table.append(boneBuffer, transposedInverseBindPose:getMatrix())

				local translation = bone:getTranslation()
				local rotation = bone:getRotation()
				local scale = bone:getScale()

				Table.append(
					boneBuffer,
					translation.x,
					translation.y,
					translation.z,
					1
				)
				Table.append(
					boneBuffer,
					rotation.x,
					rotation.y,
					rotation.z,
					rotation.w
				)
				Table.append(boneBuffer, scale.x, scale.y, scale.z, 1)

				self.skeletonBonesBuffer:set(skeleton, i, 1, unpack(boneBuffer))
			end

			for _, animation in ipairs(skeletonInfo.animations) do
				for i = 1, animation:getChannelCount() do
					local animationChannel = animation:getChannel(i)

					local translationIndex, translationCount = 1, 0
					local rotationIndex, rotationCount = 1, 0
					local scaleIndex, scaleCount = 1, 0

					for j = 1, animationChannel:getKeyedPropertyCount() do
						local keyedProperty =
							animationChannel:getKeyedProperty(j)
						local index, count =
							self.animationChannelKeyFramesBuffer:getIndexCount(
								keyedProperty
							)
						if keyedProperty:getProperty() == "position" then
							translationIndex, translationCount = index, count
						elseif keyedProperty:getProperty() == "rotation" then
							rotationIndex, rotationCount = index, count
						elseif keyedProperty:getProperty() == "scale" then
							scaleIndex, scaleCount = index, count
						end
					end

					self.animationChannelsBuffer:set(
						animation,
						i,
						1,
						animationChannel:getBone():getIndex() - 1,
						skeletonIndex - 1,
						translationIndex - 1,
						translationCount,
						rotationIndex - 1,
						rotationCount,
						scaleIndex - 1,
						scaleCount
					)
				end
			end
		end

		self.skeletonsBuffer:flush()
		self.skeletonBonesBuffer:flush()
		self.animationChannelsBuffer:flush()
		self.animationChannelKeyFramesBuffer:flush()
	end
end

--- @private
function AnimationPipeline:_refreshAnimatorData()
	local maxLayers = 0
	for _, skeleton in ipairs(self.skeletonsByIndex) do
		maxLayers = math.max(maxLayers, skeleton:getLayerCount())
	end

	for i = 1, maxLayers do
		local boneMap = self.boneMapBuffers[i]
		if not boneMap then
			boneMap = PipelineBuffer(
				AnimationPipeline.COMPOSE_GROUP_BONE_MAP_FORMAT,
				{ shaderstorage = true },
				AnimationPipeline.DEFAULT_MESH_INSTANCE_BONE_TRANSFORMS_COUNT
			)

			self.boneMapBuffers[i] = boneMap
		end

		for _, animator in ipairs(self.animatorsByIndex) do
			local skeleton = animator:getSkeleton()
			if
				i <= skeleton:getLayerCount()
				and skeleton:getLayerBoneCount(i) >= 1
			then
				boneMap:registerOrResize(
					animator,
					animator:getSkeleton():getLayerBoneCount(i)
				)

				local skeletonIndex =
					self.skeletonsBuffer:getIndexCount(skeleton)
				local boneTransformsIndex =
					self.boneTransformsBuffer:getIndexCount(animator)

				for j = 1, skeleton:getLayerBoneCount(i) do
					local bone = skeleton:getBoneAtLayer(i, j)
					boneMap:set(
						animator,
						j,
						1,
						skeletonIndex - 1,
						bone:getIndex() - 1,
						(boneTransformsIndex - 1) + (bone:getIndex() - 1)
					)
				end
			elseif boneMap:has(animator) then
				boneMap:unregister(animator)
			end
		end

		boneMap:compact()
		boneMap:flush()
	end

	self.boneMapBufferCount = maxLayers
end

--- @private
function AnimationPipeline:_refreshBoneTransformData()
	self.boneTransformsBuffer:compact()
	self.playbackTransformsBuffer:compact()

	for _, animator in ipairs(self.animatorsByIndex) do
		local skeleton = animator:getSkeleton()
		self.globalBoneMapBuffer:registerOrResize(
			animator,
			skeleton:getBoneCount()
		)

		local skeletonIndex = self.skeletonsBuffer:getIndexCount(skeleton)
		local boneTransformsIndex =
			self.boneTransformsBuffer:getIndexCount(animator)
		for j = 1, skeleton:getBoneCount() do
			local bone = skeleton:getBone(j)
			self.globalBoneMapBuffer:set(
				animator,
				j,
				1,
				skeletonIndex - 1,
				bone:getIndex() - 1,
				(boneTransformsIndex - 1) + (bone:getIndex() - 1)
			)
		end
	end

	self.globalBoneMapBuffer:compact()
	self.globalBoneMapBuffer:flush()
end

--- @private
--- @param group RatScratch.Graphics.Graphics3D.AnimatorGroup
function AnimationPipeline:_refreshAnimatorGroup(group)
	local animator = self.animatorGroups[group]
	local bones = self.animatorGroupBones[group].bones
	for i = 1, group.boneCount do
		local bone = bones[i]
		local index, count = self.playbackTransformsBuffer:getIndexCount(bone)
		local animatorRootBoneIndex =
			self.boneTransformsBuffer:getIndexCount(animator)

		self.playbackGroupBonesBuffer:set(
			group,
			i,
			1,
			index - 1,
			count,
			(animatorRootBoneIndex - 1) + (bone:getBone():getIndex() - 1)
		)

		for j, playback in ipairs(group.playbacks) do
			local channelIndex, channelCount =
				self.animationChannelsBuffer:getIndexCount(playback.animation)
			local playbackStateIndex =
				self.playbackStatesBuffer:getIndexCount(group)
			local playbackTransformIndex =
				self.playbackGroupTransformsBuffer:getIndexCount(group)

			self.playbackTransformInfoBuffer:set(
				bone,
				j,
				1,
				(channelIndex - 1)
					+ (playback.animation:getChannelIndex(bone:getBone()) - 1),
				(playbackStateIndex - 1) + (j - 1),
				(playbackTransformIndex - 1) + (i - 1)
			)
		end
	end
end

--- @private
function AnimationPipeline:_refreshAnimatorGroupData()
	for _, group in ipairs(self.dirtyAnimatorGroupsByIndex) do
		self:_refreshAnimatorGroup(group)
	end

	self.playbackGroupBonesBuffer:compact()
	self.playbackGroupBonesBuffer:flush()
	self.playbackGroupTransformsBuffer:flush()

	self.playbackTransformInfoBuffer:compact()
	self.playbackTransformInfoBuffer:flush()
end

function AnimationPipeline:flush()
	if self.isAnimationDataDirty then
		self:_refreshAnimationData()
		self.isAnimationDataDirty = false
	end

	if self.isAnimatorDataDirty then
		self:_refreshBoneTransformData()
		self:_refreshAnimatorData()
		self.isAnimatorDataDirty = false
	end

	if self.isPlaybackStateDirty then
		self.playbackStatesBuffer:flush()
		self.isPlaybackStateDirty = false
	end

	local isAnimatorGroupsDirtyDirty = #self.dirtyAnimatorGroupsByIndex >= 1
	if isAnimatorGroupsDirtyDirty then
		self:_refreshAnimatorGroupData()
		Table.clear(self.dirtyAnimatorGroups)
		Table.clear(self.dirtyAnimatorGroupsByIndex)
	end
end

--- @param a RatScratch.Graphics.Graphics3D.BoneInstance
--- @param b RatScratch.Graphics.Graphics3D.BoneInstance
--- @return boolean
local function _lessBone(a, b)
	return a:getBone():getIndex() < b:getBone():getIndex()
end

--- @param animator RatScratch.Graphics.Graphics3D.Animator
--- @param group RatScratch.Graphics.Graphics3D.AnimatorGroup
function AnimationPipeline:updateAnimatorGroup(animator, group)
	if group.boneCount == 0 then
		self:clearAnimatorGroup(animator, group)
		return
	end

	local bonesInfo = self.animatorGroupBones[group]
	if not bonesInfo then
		bonesInfo = { boneToInstance = {}, bones = {} }

		for bone in pairs(group.bones) do
			local instance = BoneInstance(bone)
			table.insert(bonesInfo.bones, instance)
		end

		table.sort(bonesInfo.bones, _lessBone)
		for i, bone in ipairs(bonesInfo.bones) do
			bonesInfo.boneToInstance[bone:getBone()] = bone
		end

		assert(
			#bonesInfo.bones == group.boneCount,
			"expected %d bones, got %d bones",
			group.boneCount,
			#bonesInfo.bones
		)

		self.animatorGroupBones[group] = bonesInfo
	end

	for _, bone in ipairs(bonesInfo.bones) do
		self.playbackTransformInfoBuffer:registerOrResize(
			bone,
			#group.playbacks
		)

		self.playbackTransformsBuffer:registerOrResize(bone, #group.playbacks)
	end

	self.playbackGroupBonesBuffer:registerOrResize(group, group.boneCount)
	self.playbackGroupTransformsBuffer:registerOrResize(group, group.boneCount)
	self.playbackStatesBuffer:registerOrResize(group, #group.playbacks)

	self.dirtyAnimatorGroups[group] = true
	table.insert(self.dirtyAnimatorGroupsByIndex, group)
	self.animatorGroups[group] = animator
end

--- @param animator RatScratch.Graphics.Graphics3D.Animator
--- @param group RatScratch.Graphics.Graphics3D.AnimatorGroup
--- @param playback RatScratch.Graphics.Graphics3D.AnimatorPlayback
function AnimationPipeline:updateAnimatorGroupPlayback(
	animator,
	group,
	playback
)
	local index
	for i, otherPlayback in ipairs(group.playbacks) do
		if otherPlayback == playback then
			index = i
			break
		end
	end

	if index then
		local relativeWeight = playback.weight / group.totalWeight
		local inverseRelativeWeight = 1 / relativeWeight

		self.playbackStatesBuffer:set(
			group,
			index,
			1,
			playback.time,
			inverseRelativeWeight
		)

		self.isPlaybackStateDirty = true
	end
end

--- @param animator RatScratch.Graphics.Graphics3D.Animator
--- @param group RatScratch.Graphics.Graphics3D.AnimatorGroup
--- @param playback RatScratch.Graphics.Graphics3D.AnimatorPlayback
function AnimationPipeline:clearAnimatorGroupPlayback(animator, group, playback)
	-- TODO
end

--- @param animator RatScratch.Graphics.Graphics3D.Animator
--- @param group RatScratch.Graphics.Graphics3D.AnimatorGroup
function AnimationPipeline:clearAnimatorGroup(animator, group)
	local bones = self.animatorGroupBones[group].bones
	for i = 1, #bones do
		local bone = bones[i]
		if self.playbackTransformInfoBuffer:has(bone) then
			self.playbackTransformInfoBuffer:unregister(bone)
		end

		if self.playbackTransformsBuffer:has(bone) then
			self.playbackTransformsBuffer:unregister(bone)
		end
	end

	if self.playbackGroupBonesBuffer:has(group) then
		self.playbackGroupBonesBuffer:unregister(group)
	end

	if self.playbackGroupTransformsBuffer:has(group) then
		self.playbackGroupTransformsBuffer:unregister(group)
	end

	if self.playbackStatesBuffer:has(group) then
		self.playbackStatesBuffer:unregister(group)
	end

	local bones = self.animatorGroupBones[group].bones
	for _, bone in ipairs(bones) do
		if self.playbackTransformInfoBuffer:has(bone) then
			self.playbackTransformInfoBuffer:unregister(bone)
		end

		if self.playbackTransformsBuffer:has(bone) then
			self.playbackTransformsBuffer:unregister(bone)
		end
	end

	self.dirtyAnimatorGroups[group] = nil
	Table.remove(self.dirtyAnimatorGroupsByIndex, group)

	self.animatorGroups[group] = nil
end

--- @param role RatScratch.Pipeline.AnimationPipelineShaderRole
--- @param shader love.Shader
function AnimationPipeline:setShader(role, shader)
	self.shaders[role] = shader or nil
end

--- @type RatScratch.Graphics.ShaderPreprocessOptions
local shaderOptions = {}

AnimationPipeline.DEFAULT_SHADERS = {
	{
		role = "evaluate",
		filename = "@Pipeline/Animation/Evaluate.compute.glsl",
	},
	{ role = "copy", filename = "@Pipeline/Animation/Copy.compute.glsl" },
	{ role = "blend", filename = "@Pipeline/Animation/Blend.compute.glsl" },
	{
		role = "compose",
		filename = "@Pipeline/Animation/Compose.compute.glsl",
	},
	{
		role = "apply_inverse_bind_pose",
		filename = "@Pipeline/Animation/ApplyInverseBindPose.compute.glsl",
	},
}

function AnimationPipeline:loadDefaultShaders()
	if not shaderOptions.rootPath then
		shaderOptions.rootPath = ("%s/Shaders"):format(
			Module.getSelfPath("rat-scratch-graphics")
		)
		shaderOptions.rootPaths = {
			Pipeline = ("%s/Shaders"):format(Module.getSelfPath(PATH)),
		}
	end

	for _, shader in ipairs(self.DEFAULT_SHADERS) do
		self:setShader(
			shader.role,
			ShaderPreprocessor.newComputeShader(shader.filename, shaderOptions)
		)
	end
end

--- @private
function AnimationPipeline:_evaluateAnimations()
	local shader = self.shaders.evaluate

	shader:send(
		"rat_AnimationChannelKeyFramesBuffer",
		self.animationChannelKeyFramesBuffer:getBuffer()
	)
	shader:send(
		"rat_AnimationChannelsBuffer",
		self.animationChannelsBuffer:getBuffer()
	)
	shader:send(
		"rat_PlaybackTransformInfoBuffer",
		self.playbackTransformInfoBuffer:getBuffer()
	)
	shader:send("rat_SkeletonBonesBuffer", self.skeletonBonesBuffer:getBuffer())
	shader:send("rat_SkeletonsBuffer", self.skeletonsBuffer:getBuffer())
	shader:send(
		"rat_PlaybackStatesBuffer",
		self.playbackStatesBuffer:getBuffer()
	)
	shader:send(
		"rat_PlaybackTransformInfoCount",
		self.playbackTransformInfoBuffer:getCount()
	)
	shader:send(
		"rat_PlaybackTransformsBuffer",
		self.playbackTransformsBuffer:getBuffer()
	)

	local x = shader:getLocalThreadgroupSize()
	love.graphics.dispatchThreadgroups(
		shader,
		math.max(math.ceil(self.playbackTransformInfoBuffer:getCount() / x), 1)
	)
end

--- @private
function AnimationPipeline:_copyAnimations()
	local shader = self.shaders.copy
	shader:send(
		"rat_ComposeBoneMapBuffer",
		self.globalBoneMapBuffer:getBuffer()
	)
	shader:send("rat_SkeletonBonesBuffer", self.skeletonBonesBuffer:getBuffer())
	shader:send("rat_SkeletonsBuffer", self.skeletonsBuffer:getBuffer())
	shader:send(
		"rat_MeshInstanceBoneTransformsBuffer",
		self.boneTransformsBuffer:getBuffer()
	)
	shader:send("rat_ComposeBoneMapCount", self.globalBoneMapBuffer:getCount())

	local x = shader:getLocalThreadgroupSize()
	love.graphics.dispatchThreadgroups(
		shader,
		math.max(math.ceil(self.globalBoneMapBuffer:getCount() / x), 1)
	)
end

--- @private
function AnimationPipeline:_blendAnimations()
	local shader = self.shaders.blend
	shader:send(
		"rat_PlaybackGroupBonesBuffer",
		self.playbackGroupBonesBuffer:getBuffer()
	)
	shader:send(
		"rat_MeshInstanceBoneTransformsBuffer",
		self.boneTransformsBuffer:getBuffer()
	)
	shader:send(
		"rat_PlaybackTransformsBuffer",
		self.playbackTransformsBuffer:getBuffer()
	)
	shader:send(
		"rat_PlaybackGroupCount",
		self.playbackGroupBonesBuffer:getCount()
	)

	local x = shader:getLocalThreadgroupSize()
	love.graphics.dispatchThreadgroups(
		shader,
		math.max(math.ceil(self.playbackGroupBonesBuffer:getCount() / x), 1)
	)
end

--- @private
function AnimationPipeline:_composeAnimations()
	local shader = self.shaders.compose

	shader:send("rat_SkeletonBonesBuffer", self.skeletonBonesBuffer:getBuffer())
	shader:send("rat_SkeletonsBuffer", self.skeletonsBuffer:getBuffer())
	shader:send(
		"rat_MeshInstanceBoneTransformsBuffer",
		self.boneTransformsBuffer:getBuffer()
	)

	local x = shader:getLocalThreadgroupSize()
	for i = 1, self.boneMapBufferCount do
		shader:send(
			"rat_ComposeBoneMapBuffer",
			self.boneMapBuffers[i]:getBuffer()
		)
		shader:send(
			"rat_ComposeBoneMapCount",
			self.boneMapBuffers[i]:getCount()
		)

		love.graphics.dispatchThreadgroups(
			shader,
			math.max(math.ceil(self.boneMapBuffers[i]:getCount() / x), 1)
		)
	end
end

--- @private
function AnimationPipeline:_finalizeAnimations()
	local shader = self.shaders.apply_inverse_bind_pose

	shader:send("rat_SkeletonBonesBuffer", self.skeletonBonesBuffer:getBuffer())
	shader:send("rat_SkeletonsBuffer", self.skeletonsBuffer:getBuffer())
	shader:send(
		"rat_ComposeBoneMapBuffer",
		self.globalBoneMapBuffer:getBuffer()
	)
	shader:send(
		"rat_MeshInstanceBoneTransformsBuffer",
		self.boneTransformsBuffer:getBuffer()
	)
	shader:send("rat_ComposeBoneMapCount", self.globalBoneMapBuffer:getCount())

	local x = shader:getLocalThreadgroupSize()
	love.graphics.dispatchThreadgroups(
		shader,
		math.max(math.ceil(self.globalBoneMapBuffer:getCount() / x), 1)
	)
end

function AnimationPipeline:update()
	self:flush()

	self:_evaluateAnimations()
	self:_copyAnimations()
	self:_blendAnimations()
	self:_composeAnimations()
	self:_finalizeAnimations()
end

return AnimationPipeline
