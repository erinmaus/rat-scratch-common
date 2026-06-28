local Common = require("rat-scratch-math.Common")
local Line = require("rat-scratch-math.Geometry2D.Line")
local Point = require("rat-scratch-math.Geometry2D.Point")
local FlatTable = require("rat-scratch-common").FlatTable
local assert = require("rat-scratch-common").Debug.assert

local SDF = {}
local SDFImpl = {}

--- @param px number
--- @param py number
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @return number
function SDF.distanceFromRectangle(px, py, x, y, w, h)
	local rpx, rpy = px - x, py - y

	local dx = math.abs(rpx) - w / 2
	local dy = math.abs(rpy) - h / 2

	local external = math.sqrt(math.max(dx, 0) ^ 2 + math.max(dy, 0) ^ 2)
	local internal = math.min(math.max(dx, dy), 0)

	return external + internal
end

--- @param px number
--- @param py number
--- @param x number
--- @param y number
--- @param radius number
--- @return number
function SDF.distanceFromCircle(px, py, x, y, radius)
	local distance = Point.distance(px, py, x, y)
	return distance - radius
end

do
	local wrappedPolygon = FlatTable.wrap(0, 2)

	--- @param px number
	--- @param py number
	--- @param points number[]
	--- @param length integer
	--- @param minDistanceSquared? number
	--- @param windingNumber? number
	function SDFImpl._distanceFromPolygon(
		px,
		py,
		points,
		length,
		minDistanceSquared,
		windingNumber
	)
		minDistanceSquared = minDistanceSquared or math.huge
		windingNumber = windingNumber or 0

		local polygon = wrappedPolygon:intrude(points, length)
		for i = 1, polygon:getLength() do
			local ax, ay = polygon:get(i)
			local bx, by = polygon:get(i + 1)

			if ay <= py then
				if
					by > py
					and Line.sideOfLineSegment(ax, ay, bx, by, px, py) > 0
				then
					windingNumber = windingNumber + 1
				end
			else
				if
					by <= py
					and Line.sideOfLineSegment(ax, ay, bx, by, px, py) < 0
				then
					windingNumber = windingNumber + 1
				end
			end

			local distanceSquared =
				Line.pointDistanceSquaredFromLineSegment(px, py, ax, ay, bx, by)

			if distanceSquared < minDistanceSquared then
				minDistanceSquared = distanceSquared
			end
		end

		return minDistanceSquared, windingNumber
	end

	--- @param px number
	--- @param py number
	--- @param points number[]
	--- @param length? number
	--- @return number
	function SDF.distanceFromPolygon(px, py, points, length)
		length = length or math.ceil(#points / 2)
		assert(
			length >= 3,
			"expected at least 3 points for polygon; got %d",
			length
		)

		local squaredDistance, windingNumber =
			SDFImpl._distanceFromPolygon(px, py, points, length)

		local distance = math.sqrt(squaredDistance)
		if windingNumber % 2 ~= 0 then
			distance = -distance
		end

		return distance
	end

	--- @param px number
	--- @param py number
	--- @param points number[][]
	--- @param lengths? number[]
	--- @return number
	function SDF.distanceFromPolygons(px, py, points, lengths)
		assert(#points >= 1, "expected at least one polygon, got 0")

		local squaredDistance, windingNumber
		for i, polygonPoints in ipairs(points) do
			local length = lengths and lengths[i]
			if not length then
				length = length or math.ceil(#polygonPoints / 2)
			end
			assert(
				length >= 3,
				"expected at least 3 points for polygon %d; got %d",
				i,
				length
			)

			squaredDistance, windingNumber = SDFImpl._distanceFromPolygon(
				px,
				py,
				polygonPoints,
				length,
				squaredDistance,
				windingNumber
			)
		end

		local distance = math.sqrt(squaredDistance)
		if windingNumber % 2 ~= 0 then
			distance = -distance
		end

		return distance
	end
end

SDF.Operators = {}

--- @param a number
--- @param b number
--- @param k number
--- @return number
function SDF.Operators.smin(a, b, k)
	local h = Common.saturate(0.5 + 0.5 * (a - b) / k)
	return Common.lerp(a, b, h) - k * h * (1.0 - h)
end

--- @param a number
--- @param b number
--- @return number
function SDF.Operators.union(a, b)
	return math.min(a, b)
end

--- @param a number
--- @param b number
--- @return number
function SDF.Operators.intersection(a, b)
	return math.max(a, b)
end

--- @param a number
--- @param b number
--- @return number
function SDF.Operators.difference(a, b)
	return math.max(a, -b)
end

return SDF
