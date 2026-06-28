local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local AnimationInstance =
	require("rat-scratch-graphics.Graphics3D.AnimationInstance")
local Quaternion = require("rat-scratch-math").Quaternion

--- @class RatScratch.Graphics.Graphics3D.AnimationPlaybackOptions
--- @field weight? number
--- @field speed? number
--- @field looping? boolean
--- @field time? number
--- @field paused? boolean
local AnimationOptions = {}

--- @class RatScratch.Graphics.Graphics3D.AnimationPlayback
--- @field package animation RatScratch.Graphics.Graphics3D.Animation
--- @field package animationInstance RatScratch.Graphics.Graphics3D.AnimationInstance
--- @field package groupKey string | number
--- @field package transforms love.Transform[]
--- @field package time number
--- @field package weight number
--- @field package speed number
--- @field package looping boolean
--- @field package paused boolean
--- @field package dirty boolean
--- @field package updated boolean
local AnimationPlayback = {}

--- @param skeleton RatScratch.Graphics.Graphics3D.Skeleton
--- @param animation RatScratch.Graphics.Graphics3D.Animation
--- @param groupKey string | number
--- @param options? RatScratch.Graphics.Graphics3D.AnimationPlaybackOptions
--- @return RatScratch.Graphics.Graphics3D.AnimationPlayback
function AnimationPlayback.new(skeleton, animation, groupKey, options)
	assert(
		not (options and options.weight and options.weight <= 0),
		"weight must be >= 0; got %f",
		options and options.weight
	)

	local looping
	if options and options.looping ~= nil then
		looping = not not options.looping
	else
		looping = false
	end

	local paused
	if options and options.paused ~= nil then
		paused = not not options.paused
	else
		paused = false
	end

	local transforms = {}
	for i = 1, skeleton:getBoneCount() do
		transforms[i] = love.math.newTransform()
	end

	return {
		animation = animation,
		animationInstance = AnimationInstance(skeleton),
		groupKey = groupKey,
		transforms = transforms,
		time = options and options.time or 0,
		weight = options and options.weight or 1.0,
		speed = options and options.speed or 1.0,
		looping = looping,
		paused = paused,
		dirty = true,
		updated = true,
	}
end

--- @class RatScratch.Graphics.Graphics3D.AnimatorGroup
--- @field package totalWeight number
--- @field package playbacks RatScratch.Graphics.Graphics3D.AnimationPlayback[]
--- @field package bones table<RatScratch.Graphics.Graphics3D.Bone, true>
--- @field package animationInstance RatScratch.Graphics.Graphics3D.AnimationInstance
local AnimatorGroup = {}

--- @class RatScratch.Graphics.Graphics3D.Animator : RatScratch.Common.BaseObject
--- @overload fun(model: RatScratch.Graphics.Graphics3D.SkinnedModel): RatScratch.Graphics.Graphics3D.Animator
--- @field private model RatScratch.Graphics.Graphics3D.SkinnedModel
--- @field private skeleton RatScratch.Graphics.Graphics3D.Skeleton
--- @field private playbacks RatScratch.Graphics.Graphics3D.AnimationPlayback[]
--- @field private blendedTransforms love.Transform[]
--- @field private finalTransforms love.Transform[]
--- @field private animationInstance RatScratch.Graphics.Graphics3D.AnimationInstance
--- @field private boneOverrides table<integer, love.Transform>
--- @field private groupsByKey table<number | string, RatScratch.Graphics.Graphics3D.AnimatorGroup>
--- @field private groups RatScratch.Graphics.Graphics3D.AnimatorGroup[]
local Animator = Object()

Animator.DEFAULT_GROUP = 1

--- @param model RatScratch.Graphics.Graphics3D.SkinnedModel
function Animator:new(model)
	local skeleton = model:getSkeleton()
	assert(skeleton, 'model "%s" doesn\'t have a skeleton', model:getName())

	local blendedTransforms, finalTransforms = {}, {}
	for i = 1, skeleton:getBoneCount() do
		table.insert(blendedTransforms, love.math.newTransform())
		table.insert(finalTransforms, love.math.newTransform())
	end

	self.model = model
	self.skeleton = skeleton
	self.playbacks = {}
	self.blendedTransforms = blendedTransforms
	self.finalTransforms = finalTransforms
	self.animationInstance = AnimationInstance(skeleton)
	self.boneOverrides = {}
	self.groups = {}
	self.groupsByKey = {}
end

--- @param animationKey number | string
--- @param groupKey string | number
--- @param options? RatScratch.Graphics.Graphics3D.AnimationPlaybackOptions
--- @return RatScratch.Graphics.Graphics3D.AnimationPlayback
function Animator:play(animationKey, groupKey, options)
	groupKey = groupKey or Animator.DEFAULT_GROUP

	local animation = self.model:getAnimation(animationKey)
	local playback =
		AnimationPlayback.new(self.skeleton, animation, groupKey, options)
	table.insert(self.playbacks, playback)

	local group = self.groupsByKey[groupKey]
	if not group then
		group = {
			totalWeight = playback.weight,
			animationInstance = AnimationInstance(self.skeleton),
			bones = {},
			playbacks = {},
		}

		self.groupsByKey[groupKey] = group

		table.insert(self.groups, group)
	end

	table.insert(group.playbacks, playback)

	for i = 1, self.skeleton:getBoneCount() do
		local bone = self.skeleton:getBone(i)
		if animation:hasBone(bone) then
			group.bones[bone] = (group.bones[bone] or 0) + 1
		end
	end

	-- Move group to end so when combining animations, this animation will have the highest
	for i, g in ipairs(self.groups) do
		if g == group then
			table.remove(self.groups, i)
			break
		end
	end

	table.insert(self.groups, group)

	return playback
end

--- @param playback RatScratch.Graphics.Graphics3D.AnimationPlayback
function Animator:stop(playback)
	for i, p in ipairs(self.playbacks) do
		if p == playback then
			table.remove(self.playbacks, i)
			break
		end
	end

	local group = self.groupsByKey[playback.groupKey]
	if group then
		for i, p in ipairs(group.playbacks) do
			if p == playback then
				table.remove(group, i)
				break
			end
		end

		for i = 1, self.skeleton:getBoneCount() do
			local bone = self.skeleton:getBone(i)
			if playback.animation:hasBone(bone) then
				group.bones[bone] = group.bones[bone] - 1
			end
		end

		if #group == 0 then
			self.groupsByKey[playback.groupKey] = nil

			for i, g in ipairs(self.groups) do
				if g == group then
					table.remove(self.groups, i)
					break
				end
			end
		end
	end
end

--- @param playback RatScratch.Graphics.Graphics3D.AnimationPlayback
--- @param weight number
function Animator:setWeight(playback, weight)
	assert(weight >= 0, "weight must be >= 0; got %f", weight)

	local group = self.groupsByKey[playback.groupKey]
	if group then
		group.totalWeight = group.totalWeight - playback.weight + weight
	end

	playback.weight = weight
end

--- @param playback RatScratch.Graphics.Graphics3D.AnimationPlayback
--- @param time number
function Animator:seek(playback, time)
	playback.time = time

	if playback.time ~= time then
		playback.dirty = true
	end
end

--- @param playback RatScratch.Graphics.Graphics3D.AnimationPlayback
--- @param isLooping boolean
function Animator:setIsLooping(playback, isLooping)
	playback.looping = isLooping
end

--- @param playback RatScratch.Graphics.Graphics3D.AnimationPlayback
--- @param isPaused boolean
function Animator:setIsPaused(playback, isPaused)
	playback.paused = isPaused
end

--- @param playback RatScratch.Graphics.Graphics3D.AnimationPlayback
--- @return boolean
function Animator:getIsPaused(playback)
	return playback.paused
end

--- @param playback RatScratch.Graphics.Graphics3D.AnimationPlayback
--- @return number
function Animator:getTime(playback)
	return playback.time
end

--- @param playback RatScratch.Graphics.Graphics3D.AnimationPlayback
--- @return number
function Animator:getWeight(playback)
	return playback.weight
end

--- @param playback RatScratch.Graphics.Graphics3D.AnimationPlayback
--- @return number
function Animator:getSpeed(playback)
	return playback.speed
end

--- @param playback RatScratch.Graphics.Graphics3D.AnimationPlayback
--- @return boolean
function Animator:getIsLooping(playback)
	return playback.looping
end

--- @alias RatScratch.Graphics.Graphics3D.AnimatorBoneKey number | string | RatScratch.Graphics.Graphics3D.Bone

--- @private
--- @param boneKey RatScratch.Graphics.Graphics3D.AnimatorBoneKey ID, name, or bone
function Animator:_getBone(boneKey)
	if type(boneKey) == "number" then
		return self.skeleton:getBoneByID(boneKey)
	elseif type(boneKey) == "string" then
		return self.skeleton:getBone(boneKey)
	end

	return boneKey
end

do
	local workingTransform = love.math.newTransform()

	--- @private
	--- @param playback RatScratch.Graphics.Graphics3D.AnimationPlayback
	function Animator:_buildPlaybackTransforms(playback)
		for i = 1, #playback.transforms do
			local bone = self.skeleton:getBone(i)
			local parent = bone:getParent()

			playback.transforms[i]:reset()

			if parent then
				local parentIndex = self.skeleton:getBoneIndex(parent)
				playback.transforms[i]:apply(playback.transforms[parentIndex])
			end

			playback.animationInstance
				:getBoneInstance(bone)
				:composeTransform(playback.transforms[i])
		end

		for i = 1, #playback.transforms do
			local bone = self.skeleton:getBone(i)
			playback.transforms[i]:apply(bone:getInverseBindPoseTransform())
		end
	end
end

--- @param playback RatScratch.Graphics.Graphics3D.AnimationPlayback
--- @param boneKey RatScratch.Graphics.Graphics3D.AnimatorBoneKey ID, name, or bone
--- @param result? love.Transform
--- @return love.Transform
function Animator:getAnimationTransform(playback, boneKey, result)
	if playback.updated then
		self:_buildPlaybackTransforms(playback)
		playback.updated = false
	end

	local bone = self:_getBone(boneKey)
	local index = self.skeleton:getBoneIndex(bone)
	local transform = playback.transforms[index]

	local result = result or love.math.newTransform()
	result:setMatrix(transform:getMatrix())

	return result
end

--- @private
--- @param deltaTime number
function Animator:_updateTime(deltaTime)
	for i = #self.playbacks, 1, -1 do
		local playback = self.playbacks[i]
		if not playback.paused then
			local time = playback.time + deltaTime * playback.speed
			if
				time < 0
				or time > playback.animation:getDuration()
					and not playback.looping
			then
				self:stop(playback)
			else
				local newTime = time % playback.animation:getDuration()
				playback.dirty = newTime ~= playback.time
				playback.time = newTime
			end
		end
	end
end

--- @private
function Animator:_evaluateAnimations()
	for _, playback in ipairs(self.playbacks) do
		if playback.dirty then
			playback.animation:evaluate(
				playback.animationInstance,
				playback.time
			)
			playback.dirty = false
			playback.updated = true
		end
	end
end

--- @private
function Animator:_blendAnimations()
	for _, group in ipairs(self.groups) do
		group.animationInstance:zero()

		if group.totalWeight > 0 then
			for _, playback in ipairs(group.playbacks) do
				local relativeWeight = playback.weight / group.totalWeight
				if relativeWeight > 0 then
					playback.animationInstance:blend(
						relativeWeight,
						group.animationInstance,
						playback.animation
					)
				end
			end
		end

		for i = 1, self.skeleton:getBoneCount() do
			local bone = self.skeleton:getBone(i)
			local boneInstance = group.animationInstance:getBoneInstance(bone)
			boneInstance:getRotation():normalize(boneInstance:getRotation())
		end
	end
end

--- @private
function Animator:_combineAnimations()
	self.animationInstance:reset()

	for _, group in ipairs(self.groups) do
		for i = 1, self.skeleton:getBoneCount() do
			local bone = self.skeleton:getBone(i)
			if group.bones[bone] and group.bones[bone] > 0 then
				local inputBoneInstance =
					group.animationInstance:getBoneInstance(bone)
				local outputBoneInstance =
					self.animationInstance:getBoneInstance(bone)

				outputBoneInstance:setTranslation(
					inputBoneInstance:getTranslation()
				)
				outputBoneInstance:setRotation(inputBoneInstance:getRotation())
				outputBoneInstance:setScale(inputBoneInstance:getScale())
			end
		end
	end
end

--- @private
function Animator:_composeTransforms()
	for i = 1, self.skeleton:getBoneCount() do
		local bone = self.skeleton:getBone(i)
		local parent = bone:getParent()

		self.blendedTransforms[i]:reset()

		if parent then
			local parentIndex = self.skeleton:getBoneIndex(parent)
			self.blendedTransforms[i]:apply(self.blendedTransforms[parentIndex])

			if self.boneOverrides[i] then
				self.finalTransforms[i]:setMatrix(
					self.blendedTransforms[parentIndex]:getMatrix()
				)
			end
		end

		local boneInstance = self.animationInstance:getBoneInstance(bone)
		boneInstance:composeTransform(self.blendedTransforms[i])

		if self.boneOverrides[i] then
			self.finalTransforms[i]:apply(self.boneOverrides[i])
		else
			self.finalTransforms[i]:setMatrix(
				self.blendedTransforms[i]:getMatrix()
			)
		end
	end

	for i = 1, self.skeleton:getBoneCount() do
		local bone = self.skeleton:getBone(i)

		self.finalTransforms[i]:apply(bone:getInverseBindPoseTransform())
	end
end

--- @param deltaTime number
function Animator:update(deltaTime)
	self:_updateTime(deltaTime)
	self:_evaluateAnimations()
	self:_blendAnimations()
	self:_combineAnimations()
	self:_composeTransforms()
end

--- @param boneKey RatScratch.Graphics.Graphics3D.AnimatorBoneKey ID, name, or bone
--- @param transform love.Transform
function Animator:setBoneOverride(boneKey, transform)
	local bone = self:_getBone(boneKey)
	local index = self.skeleton:getBoneIndex(bone)

	self.boneOverrides[index] = transform
end

--- @param boneKey RatScratch.Graphics.Graphics3D.AnimatorBoneKey ID, name, or bone
function Animator:unsetBoneOverride(boneKey)
	local bone = self:_getBone(boneKey)
	local index = self.skeleton:getBoneIndex(bone)

	self.boneOverrides[index] = nil
end

--- @param boneKey RatScratch.Graphics.Graphics3D.AnimatorBoneKey ID, name, or bone
--- @return love.Transform | nil
function Animator:getBoneOverride(boneKey)
	local bone = self:_getBone(boneKey)
	local index = self.skeleton:getBoneIndex(bone)

	return self.boneOverrides[index]
end

--- @param boneKey RatScratch.Graphics.Graphics3D.AnimatorBoneKey ID, name, or bone
--- @param result love.Transform
--- @return love.Transform
function Animator:getBlendedBoneTransform(boneKey, result)
	local bone = self:_getBone(boneKey)
	local index = self.skeleton:getBoneIndex(bone)

	result = result or love.math.newTransform()

	result:setMatrix(self.blendedTransforms[index]:getMatrix())
	result:apply(bone:getInverseBindPoseTransform())

	return result
end

--- @param boneKey RatScratch.Graphics.Graphics3D.AnimatorBoneKey ID, name, or bone
--- @param result love.Transform
--- @return love.Transform
function Animator:getBoneTransform(boneKey, result)
	local bone = self:_getBone(boneKey)
	local index = self.skeleton:getBoneIndex(bone)

	result = result or love.math.newTransform()
	result:setMatrix(self.finalTransforms[index]:getMatrix())

	return result
end

return Animator
