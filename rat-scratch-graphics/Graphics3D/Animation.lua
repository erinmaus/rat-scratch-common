local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-math").Vector3
local Quaternion = require("rat-scratch-math").Quaternion
local assert = require("rat-scratch-common").Debug.assert
local AnimationChannel =
	require("rat-scratch-graphics.Graphics3D.AnimationChannel")
local KeyFrames = require("rat-scratch-graphics.Graphics3D.KeyFrames")

--- @class RatScratch.Graphics.Graphics3D.Animation : RatScratch.Common.BaseObject
--- @overload fun(name?: string, channels: RatScratch.Graphics.Graphics3D.AnimationChannel[]): RatScratch.Graphics.Graphics3D.Animation
--- @field private name? string
--- @field private duration number
--- @field private channels RatScratch.Graphics.Graphics3D.AnimationChannel[]
--- @field private channelsByBone table<RatScratch.Graphics.Graphics3D.Bone, RatScratch.Graphics.Graphics3D.AnimationChannel>
local Animation = Object()

--- @param channels RatScratch.Graphics.Graphics3D.AnimationChannel[]
--- @return RatScratch.Graphics.Graphics3D.AnimationChannel[], table<RatScratch.Graphics.Graphics3D.Bone, RatScratch.Graphics.Graphics3D.AnimationChannel>, table<RatScratch.Graphics.Graphics3D.Bone, integer>, number
function Animation.validateChannels(channels)
	local outputChannels = {}
	local outputChannelsByBone = {}
	local outputBoneToChannelIndex = {}
	local duration = 0

	for i, channel in ipairs(channels) do
		assert(
			outputChannelsByBone[channel:getBone()] == nil,
			"duplicate animation channel on bone %s",
			channel:getBone()
		)
		outputChannelsByBone[channel:getBone()] = channel
		outputBoneToChannelIndex[channel:getBone()] = i

		table.insert(outputChannels, channel)
		duration = math.max(duration, channel:getDuration())
	end

	return outputChannels,
		outputChannelsByBone,
		outputBoneToChannelIndex,
		duration
end

--- @param name? string
--- @param channels RatScratch.Graphics.Graphics3D.AnimationChannel[]
function Animation:new(name, channels)
	local outputChannels, outputChannelsByBone, outputBoneToChannelIndex, duration =
		Animation.validateChannels(channels)

	self.name = name
	self.duration = duration
	self.channels = outputChannels
	self.boneToChannelIndex = outputBoneToChannelIndex
	self.channelsByBone = outputChannelsByBone
end

function Animation:getName()
	return self.name
end

function Animation:getDuration()
	return self.duration
end

function Animation:getChannelCount()
	return #self.channels
end

--- @param bone RatScratch.Graphics.Graphics3D.Bone
--- @return boolean
function Animation:hasBone(bone)
	return self.channelsByBone[bone] ~= nil
end

--- @param key number | RatScratch.Graphics.Graphics3D.Bone
--- @return RatScratch.Graphics.Graphics3D.AnimationChannel
function Animation:getChannel(key)
	if type(key) == "number" then
		assert(
			self.channels[key] ~= nil,
			"no keyed properties at index %s",
			key
		)
		return self.channels[key]
	else
		assert(
			self.channelsByBone[key] ~= nil,
			"no keyed properties associated with bone %s",
			key:getName()
		)
		return self.channelsByBone[key]
	end
end

--- @param bone RatScratch.Graphics.Graphics3D.Bone
--- @return integer
function Animation:getChannelIndex(bone)
	assert(
		self.boneToChannelIndex[bone] ~= nil,
		"no keyed properties associated with bone %s",
		bone:getName()
	)

	return self.boneToChannelIndex[bone]
end

--- @param instance RatScratch.Graphics.Graphics3D.AnimationInstance
--- @param time number
function Animation:evaluate(instance, time)
	instance:reset()

	for _, channel in ipairs(self.channels) do
		local bone = channel:getBone()
		local boneInstance = instance:getBoneInstance(bone)
		channel:computePropertiesAtTime(boneInstance, time)
	end
end

--- @param animationDefinition RatScratch.Graphics.Graphics3D.AnimationDefinition
--- @param skeleton RatScratch.Graphics.Graphics3D.Skeleton
--- @return RatScratch.Graphics.Graphics3D.Animation
function Animation.fromDefinition(animationDefinition, skeleton)
	--- @type RatScratch.Graphics.Graphics3D.AnimationChannel[]
	local channels = {}
	for _, channel in ipairs(animationDefinition.channels) do
		if skeleton:hasBoneByID(channel.boneID) then
			--- @type RatScratch.Graphics.Graphics3D.KeyFrames[]
			local keyFrames = {}

			for _, propertyDefinition in ipairs(channel.properties) do
				--- @type RatScratch.Graphics.Graphics3D.KeyFrame[]
				local keyFrameValues = {}

				for _, frameDefinition in ipairs(propertyDefinition.frames) do
					local value
					if
						propertyDefinition.property == "position"
						or propertyDefinition.property == "scale"
					then
						value = Vector3
					elseif propertyDefinition.property == "rotation" then
						value = Quaternion
					else
						assert(
							false,
							'expected "position", "scale", or "rotation" for animation %s bone %s key frames, got: %s',
							animationDefinition.name or "???",
							skeleton and skeleton:getBoneByID(channel.boneID)
								or channel.boneID,
							propertyDefinition.property
						)
					end

					--- @type RatScratch.Graphics.Graphics3D.KeyFrame
					local keyFrameValue = {
						time = frameDefinition.time,
						inTangent = frameDefinition.inTangent
							and value(unpack(frameDefinition.inTangent)),
						value = frameDefinition.value
							and value(unpack(frameDefinition.value)),
						outTangent = frameDefinition.outTangent
							and value(unpack(frameDefinition.outTangent)),
					}

					table.insert(keyFrameValues, keyFrameValue)
				end

				table.insert(
					keyFrames,
					KeyFrames(
						propertyDefinition.property,
						propertyDefinition.interpolation,
						keyFrameValues
					)
				)
			end

			table.insert(
				channels,
				AnimationChannel(
					skeleton:getBoneByID(channel.boneID),
					keyFrames
				)
			)
		end
	end

	return Animation(animationDefinition.name, channels)
end

return Animation
