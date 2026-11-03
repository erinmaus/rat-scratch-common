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

do
	local _inverseDirection = Vector3()

	--- @param minBounds RatScratch.Math.Vector3
	--- @param maxBounds RatScratch.Math.Vector3
	--- @param origin RatScratch.Math.Vector3
	--- @param direction RatScratch.Math.Vector3
	--- @return boolean, number
	function AABB.raycast(minBounds, maxBounds, origin, direction)
		local inverseDirection =
			Vector3.ONE:divide(direction, _inverseDirection)
		local tMin, tMax

		local tx1 = (minBounds.x - origin.x) * inverseDirection.x
		local tx2 = (maxBounds.x - origin.x) * inverseDirection.x

		tMin = math.min(tx1, tx2)
		tMax = math.max(tx1, tx2)

		local ty1 = (minBounds.y - origin.y) * inverseDirection.y
		local ty2 = (maxBounds.y - origin.y) * inverseDirection.y

		tMin = math.max(tMin, math.min(ty1, ty2, tMax))
		tMax = math.min(tMax, math.max(ty1, ty2, tMin))

		local tz1 = (minBounds.z - origin.z) * inverseDirection.z
		local tz2 = (maxBounds.z - origin.z) * inverseDirection.z

		tMin = math.max(tMin, math.min(tz1, tz2, tMax))
		tMax = math.min(tMax, math.max(tz1, tz2, tMin))

		if tMax > tMin and tMin >= 0 then
			return true, tMin
		else
			return false, math.huge
		end
	end
end

return AABB
