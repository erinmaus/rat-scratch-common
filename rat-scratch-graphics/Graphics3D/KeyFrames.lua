local Search = require("rat-scratch-common").Search
local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Vector3 = require("rat-scratch-math").Vector3
local Quaternion = require("rat-scratch-math").Quaternion
local Interpolator = require("rat-scratch-graphics.Graphics3D.Interpolator")

--- @class RatScratch.Graphics.Graphics3D.KeyFrames : RatScratch.Common.BaseObject
--- @overload fun(property: RatScratch.Graphics.Graphics3D.KeyFramePropertyType, interpolation: RatScratch.Graphics.Graphics3D.InterpolatorType, frames: RatScratch.Graphics.Graphics3D.KeyFrames[]): RatScratch.Graphics.Graphics3D.KeyFrames
--- @field private property RatScratch.Graphics.Graphics3D.KeyFramePropertyType
--- @field private interpolation RatScratch.Graphics.Graphics3D.InterpolatorType
--- @field private duration number
--- @field private frames RatScratch.Graphics.Graphics3D.KeyFrame[]
local KeyFrames = Object()

--- @alias RatScratch.Graphics.Graphics3D.KeyFramePropertyType "position" | "rotation" | "scale"
--- @alias RatScratch.Graphics.Graphics3D.KeyFrameValue RatScratch.Math.Vector3 | RatScratch.Math.Quaternion

--- @class RatScratch.Graphics.Graphics3D.KeyFrame
--- @field public time number
--- @field public inTangent RatScratch.Graphics.Graphics3D.KeyFrameValue?
--- @field public value RatScratch.Graphics.Graphics3D.KeyFrameValue
--- @field public outTangent RatScratch.Graphics.Graphics3D.KeyFrameValue?
--- @field public type? any
local KeyFrame = {}

--- @param frames RatScratch.Graphics.Graphics3D.KeyFrame[]
--- @return RatScratch.Graphics.Graphics3D.KeyFrame[], number
function KeyFrames.marshalFrames(frames)
	assert(#frames >= 1, "at least one key frame is required; got %d", #frames)

	local currentTime
	local baseType = Object.getType(frames[1].value)
	assert(baseType, "object is not ")

	local hasTangents = not not (frames[1].inTangent and frames[1].outTangent)
	assert(
		hasTangents or not (frames[1].inTangent or frames[1].outTangent),
		"key frame must have both tangents if any are present; inTangent=%s, outTangent=%s",
		tostring(frames[1].inTangent),
		tostring(frames[1].outTangent)
	)

	--- @type RatScratch.Graphics.Graphics3D.KeyFrame[]
	local result = {}

	for _, frame in ipairs(frames) do
		assert(
			not ((currentTime and frame.time <= currentTime) or frame.time < 0),
			"key frame time must advance forward; current=%s, next=%s",
			currentTime,
			frame.time
		)
		currentTime = frame.time

		local currentType = Object.getType(frame.value)
		assert(currentType, "key frame value must have type")

		assert(
			currentType == baseType,
			"key frame value type mismatch; expected %s, got %s",
			baseType._DEBUG.shortName,
			currentType._DEBUG.shortName
		)
		assert(
			not frame.inTangent or Object.getType(frame.inTangent) == baseType,
			"key frame in-tangent type mismatch; expected %s, got %s",
			baseType._DEBUG.shortName,
			frame.inTangent and Object.getType(frame.inTangent)._DEBUG.shortName
		)
		assert(
			not frame.outTangent or Object.getType(frame.outTangent) == baseType,
			"key frame out-tangent type mismatch; expected %s, got %s",
			baseType._DEBUG.shortName,
			frame.outTangent and Object.getType(frame.outTangent)._DEBUG.shortName
		)
		assert(
			not hasTangents or (frame.inTangent and frame.outTangent),
			"all key frames must have both tangents for cubic interpolation; has in tangent = %s, has out tangent = %s",
			frame.inTangent and "yes" or "no",
			frame.outTangent and "yes" or "no"
		)

		local value, inTangent, outTangent
		if baseType == Vector3 then
			value = Vector3(frame.value:get())
			inTangent = frame.inTangent and Vector3(frame.inTangent:get()) or value
			outTangent = frame.outTangent and Vector3(frame.outTangent:get()) or value
		elseif baseType == Quaternion then
			value = Quaternion(frame.value:get())
			inTangent = frame.inTangent and Quaternion(frame.inTangent:get()) or value
			outTangent = frame.outTangent and Quaternion(frame.outTangent:get()) or value
		end

		table.insert(result, {
			time = frame.time,
			type = baseType,
			inTangent = inTangent,
			outTangent = outTangent,
			value = value,
		})
	end

	return result, currentTime
end

--- @param property RatScratch.Graphics.Graphics3D.KeyFramePropertyType
--- @param interpolation RatScratch.Graphics.Graphics3D.InterpolatorType
--- @param frames RatScratch.Graphics.Graphics3D.KeyFrames[]
function KeyFrames:new(property, interpolation, frames)
	local outputFrames, duration = KeyFrames.marshalFrames(frames)

	self.property = property
	self.interpolation = interpolation
	self.frames = outputFrames
	self.duration = duration
end

function KeyFrames:getProperty()
	return self.property
end

function KeyFrames:getInterpolation()
	return self.interpolation
end

function KeyFrames:getDuration()
	return self.duration
end

--- @param index number
--- @return RatScratch.Graphics.Graphics3D.KeyFrame
function KeyFrames:getFrame(index)
	return self.frames[index]
end

function KeyFrames:getFrameCount()
	return #self.frames
end

--- @param a RatScratch.Graphics.Graphics3D.KeyFrame
--- @param time number
local function _compare(a, time)
	if a.time < time then
		return -1
	elseif a.time > time then
		return 1
	end

	return 0
end

--- @param time number
--- @return RatScratch.Graphics.Graphics3D.KeyFrame, RatScratch.Graphics.Graphics3D.KeyFrame
function KeyFrames:getFramesAtTime(time)
	if time > self.duration then
		return self.frames[#self.frames - 1] or self.frames[#self.frames], self.frames[#self.frames]
	end

	local index = Search.lessThanEqual(self.frames, time, _compare)
	if index >= 1 and index <= #self.frames then
		return self.frames[index], self.frames[index + 1] or self.frames[index]
	end

	return self.frames[1], self.frames[2] or self.frames[1]
end

--- @param time number
--- @param result RatScratch.Graphics.Graphics3D.KeyFrameValue
--- @return RatScratch.Graphics.Graphics3D.KeyFrameValue
function KeyFrames:computeValueAtTime(time, result)
	local currentFrame, nextFrame = self:getFramesAtTime(time)

	local interpolationFunc = Interpolator[self.interpolation]

	result = result or currentFrame.type.new()
	interpolationFunc(time, result, currentFrame, nextFrame)

	return result
end

return KeyFrames
