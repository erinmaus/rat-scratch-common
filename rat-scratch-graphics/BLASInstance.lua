local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-math").Vector3
local Transform = require("rat-scratch-math").Transform

--- @generic T
--- @class RatScratch.Graphics.BLASInstance<T> : RatScratch.Common.BaseObject
--- @overload fun<T>(blas: T, minBounds: RatScratch.Math.Vector3, maxBounds: RatScratch.Math.Vector3, tag?: integer): RatScratch.Graphics.BLASInstance<T>
local BLASInstance = Object()

--- @generic T
--- @param self RatScratch.Graphics.BLASInstance<T>
--- @param blas T
--- @param minBounds RatScratch.Math.Vector3
--- @param maxBounds RatScratch.Math.Vector3
--- @param tag? integer
function BLASInstance:new(blas, minBounds, maxBounds, tag)
	self.blas = blas
	self.tag = tag or 0

	self.minBounds = Vector3():from(minBounds:get())
	self.maxBounds = Vector3():from(maxBounds:get())

	self.transformedMinBounds = Vector3()
	self.transformedMaxBounds = Vector3()

	self.transform = love.math.newTransform()

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
--- @
function BLASInstance:getBLAS()
	return self.blas
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

	--- @param blas RatScratch.Graphics.AccelerationStructure
	--- @param tag? integer
	--- @return RatScratch.Graphics.BLASInstance<RatScratch.Graphics.AccelerationStructure>
	function BLASInstance.fromAccelerationStructure(blas, tag)
		local minBounds, maxBounds = blas:extractNodeBounds(1, _min, _max)
		return BLASInstance(blas, minBounds, maxBounds, tag)
	end
end

return BLASInstance
