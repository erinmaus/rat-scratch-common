local Vector3 = require("rat-scratch-math.Vector3")
local AABB = {}

--- @param minBounds RatScratch.Math.Vector3
--- @param maxBounds RatScratch.Math.Vector3
--- @param value RatScratch.Math.Vector3
--- @param resultMinBounds? RatScratch.Math.Vector3
--- @param resultMaxBounds? RatScratch.Math.Vector3
--- @return RatScratch.Math.Vector3, RatScratch.Math.Vector3
function AABB.expand(
	minBounds,
	maxBounds,
	value,
	resultMinBounds,
	resultMaxBounds
)
	resultMinBounds = resultMinBounds and resultMinBounds:from(minBounds:get())
		or minBounds
	resultMaxBounds = resultMaxBounds and resultMaxBounds:from(maxBounds:get())
		or maxBounds

	resultMinBounds:min(value, resultMinBounds)
	resultMaxBounds:max(value, resultMaxBounds)

	return resultMinBounds, resultMaxBounds
end

--- @param minBoundsA RatScratch.Math.Vector3
--- @param maxBoundsA RatScratch.Math.Vector3
--- @param minBoundsB RatScratch.Math.Vector3
--- @param maxBoundsB RatScratch.Math.Vector3
--- @param resultMinBounds? RatScratch.Math.Vector3
--- @param resultMaxBounds? RatScratch.Math.Vector3
--- @return RatScratch.Math.Vector3, RatScratch.Math.Vector3
function AABB.union(
	minBoundsA,
	maxBoundsA,
	minBoundsB,
	maxBoundsB,
	resultMinBounds,
	resultMaxBounds
)
	resultMinBounds = resultMinBounds and resultMinBounds:from(minBoundsA:get())
		or minBoundsA
	resultMaxBounds = resultMaxBounds and resultMaxBounds:from(maxBoundsA:get())
		or maxBoundsA

	AABB.expand(resultMinBounds, resultMaxBounds, minBoundsB)
	AABB.expand(resultMinBounds, resultMaxBounds, maxBoundsB)

	return resultMinBounds, resultMaxBounds
end

do
	local _size = Vector3()

	--- @param minBounds RatScratch.Math.Vector3
	--- @param maxBounds RatScratch.Math.Vector3
	function AABB.calculateSurfaceArea(minBounds, maxBounds)
		local size = maxBounds:subtract(minBounds, _size)

		local a1 = 2 * size.z * size.x
		local a2 = 2 * size.z * size.y
		local a3 = 2 * size.x * size.y

		return a1 + a2 + a3
	end
end

return AABB
