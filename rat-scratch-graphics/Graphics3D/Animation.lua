local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert

--- @class RatScratch.Graphics.Graphics3D.Animation : RatScratch.Common.BaseObject
--- @overload fun(name?: string, channels: RatScratch.Graphics.Graphics3D.AnimationChannel[]): RatScratch.Graphics.Graphics3D.Animation
--- @field private name? string
--- @field private duration number
--- @field private channels RatScratch.Graphics.Graphics3D.AnimationChannel[]
--- @field private channelsByBone table<RatScratch.Graphics.Graphics3D.Bone, RatScratch.Graphics.Graphics3D.AnimationChannel>
local Animation = Object()

--- @param channels RatScratch.Graphics.Graphics3D.AnimationChannel[]
--- @return RatScratch.Graphics.Graphics3D.AnimationChannel[], table<RatScratch.Graphics.Graphics3D.Bone, RatScratch.Graphics.Graphics3D.AnimationChannel>, number
function Animation.validateChannels(channels)
	local outputChannels = {}
	local outputChannelsByBone = {}
	local duration = 0

	for _, channel in ipairs(channels) do
		assert(
			outputChannelsByBone[channel:getBone()] == nil,
			"duplicate animation channel on bone %s",
			channel:getBone()
		)
		outputChannelsByBone[channel:getBone()] = channel

		table.insert(outputChannels, channel)
		duration = math.max(duration, channel:getDuration())
	end

	return outputChannels, outputChannelsByBone, duration
end

--- @param name? string
--- @param channels RatScratch.Graphics.Graphics3D.AnimationChannel[]
function Animation:new(name, channels)
	local outputChannels, outputChannelsByBone, duration =
		Animation.validateChannels(channels)

	self.name = name
	self.duration = duration
	self.channels = outputChannels
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

return Animation
