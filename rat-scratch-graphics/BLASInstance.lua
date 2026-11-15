local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-math").Vector3
local Transform = require("rat-scratch-math").Transform
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")

--- @generic T
--- @class RatScratch.Graphics.BLASInstance<T> : RatScratch.Common.BaseObject
--- @overload fun<T>(instance: T, minBounds: RatScratch.Math.Vector3, maxBounds: RatScratch.Math.Vector3, tag?: integer): RatScratch.Graphics.BLASInstance<T>
local BLASInstance = Object()

BLASInstance.FORMAT = {
	{ location = 0, name = "tag", format = "uint32" },
	{ location = 1, name = "rootNodeOffset", format = "uint32" },
	{ location = 2, name = "indexOffset", format = "uint32" },
	{ location = 3, name = "transform", format = "floatmat4x4" },
}

BLASInstance.FORMAT_INSTANCE = BufferFormat.get(BLASInstance.FORMAT)

--- @generic T
--- @param self RatScratch.Graphics.BLASInstance<T>
--- @param instance T
--- @param minBounds RatScratch.Math.Vector3
--- @param maxBounds RatScratch.Math.Vector3
--- @param tag? integer
function BLASInstance:new(instance, minBounds, maxBounds, tag)
	self.instance = instance
	self.tag = tag or 0

	self.minBounds = Vector3():from(minBounds:get())
	self.maxBounds = Vector3():from(maxBounds:get())

	self.transformedMinBounds = Vector3()
	self.transformedMaxBounds = Vector3()

	self.transform = love.math.newTransform()

	self.transformedMinBounds:from(self.minBounds:get())
	self.transformedMaxBounds:from(self.maxBounds:get())
end

--- @generic T
--- @param self RatScratch.Graphics.BLASInstance<T>
--- @param instance T
--- @param minBounds RatScratch.Math.Vector3
--- @param maxBounds RatScratch.Math.Vector3
--- @param tag? integer
function BLASInstance:init(instance, minBounds, maxBounds, tag)
	self.instance = instance
	self.tag = tag or 0

	self.minBounds:from(minBounds:get())
	self.maxBounds:from(maxBounds:get())

	self.transform:reset()
	self.transformedMinBounds:from(self.minBounds:get())
	self.transformedMaxBounds:from(self.maxBounds:get())
end

function BLASInstance:getBounds()
	return self.transformedMinBounds, self.transformedMaxBounds
end

function BLASInstance:getTag()
	return self.tag
end

--- @generic T
--- @param self RatScratch.Graphics.BLASInstance<T>
--- @return T
function BLASInstance:getInstance()
	return self.instance
end

function BLASInstance:setTransform(transform)
	self.transform:setMatrix(transform:getMatrix())

	Transform.transformBounds(
		self.transform,
		self.minBounds,
		self.maxBounds,
		self.transformedMinBounds,
		self.transformedMaxBounds
	)
end

function BLASInstance:getTransform()
	return self.transform
end

do
	local _min, _max = Vector3(), Vector3()

	--- @param instance RatScratch.Graphics.AccelerationStructure
	--- @param tag? integer
	--- @return RatScratch.Graphics.BLASInstance<RatScratch.Graphics.AccelerationStructure>
	function BLASInstance.fromAccelerationStructure(instance, tag)
		local minBounds, maxBounds = instance:extractNodeBounds(1, _min, _max)
		return BLASInstance(instance, minBounds, maxBounds, tag)
	end
end

return BLASInstance
