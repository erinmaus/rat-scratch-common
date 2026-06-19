local Point = require("rat-scratch-math.Geometry2D.Point")
local Line = require("rat-scratch-math.Geometry2D.Line")
local Debug = require("rat-scratch-common").Debug
local Common= require("rat-scratch-math.Common")
local FlatTable = require("rat-scratch-common.FlatTable")

local Polygon = {}
local PolygonImpl = {}

do
	local wrappedPolygon = FlatTable.wrap(0, 2)
	local wrappedResultPolygon = FlatTable.wrap(0, 2)

	--- @param source number[]
	--- @param destination number[]
	--- @param length integer
	function PolygonImpl._copy(source, destination, length)
		local n = length * 2

		for i = 1, length do
			destination[i] = source[i]
		end
	end

	--- @param points number[]
	--- @param t love.Transform?
	--- @param length? integer
	--- @param result? number[]
	--- @return number[]
	function Polygon.transform(points, t, length, result)
		result = result or {}
		length = length or math.ceil(#points / 2)

		if not t then
			if result ~= points then
				PolygonImpl._copy(points, result, length)
			end

			return result
		end

		local polygon = wrappedPolygon:intrude(points, length)
		local resultPolygon = wrappedResultPolygon:intrude(result, length)

		for i = 1, polygon:getLength() do
			local x, y = polygon:get(i)
			local tx, ty = t:transformPoint(x, y)
			resultPolygon:set(i, tx, ty)
		end

		return result
	end
end

do
	local wrappedPolygon = FlatTable.wrap(0, 2)

	--- @param px number
	--- @param py number
	--- @param points number[]
	--- @param length? integer
	--- @return boolean
	function Polygon.isPointInside(px, py, points, length)
		length = length or math.ceil(#points / 2)

		local polygon = wrappedPolygon:intrude(points, length)

		local winding
		for i = 1, polygon:getLength() do
			local ax, ay = polygon:get(i)
			local bx, by = polygon:get(i + 1)

			local left = (ay - py) * (bx - px)
			local right = (ax - px) * (by - py)
			local cross = left - right

			if not (cross > -Common.EPSILON and cross < Common.EPSILON) then
				if not winding then
					winding = cross
				elseif (winding < 0) and (cross > 0) or (winding > 0) and (cross < 0) then
					return false
				end
			end
		end

		return true
	end
end

do
	local wrappedPolygon = FlatTable.wrap(0, 2)

	--- @param px number
	--- @param py number
	--- @param points number[]
	--- @param length? number
	--- @return number, number, number, integer
	function Polygon.pointDistance(px, py, points, length)
		length = length or math.ceil(#points / 2)

		local polygon = wrappedPolygon:intrude(points, length)

		local minDistance = math.huge
		local x1, y1, x2, y2 = 0, 0, 0, 0
		local index = 1

		for i = 1, polygon:getLength() do
			local ax, ay = polygon:get(i)
			local bx, by = polygon:get(i + 1)

			local distance = Line.pointDistanceSquaredFromLineSegment(px, py, ax, ay, bx, by)
			if distance < minDistance then
				minDistance = distance

				x1, y1 = ax, ay
				x2, y2 = bx, by
				index = i
			end
		end

		local nx, ny = Line.getNormal(x1, y1, x2, y2)
		local rnx, rny = Point.left(nx, ny)

		return rnx, rny, math.sqrt(minDistance), index
	end
end

do
	local wrappedPolygon = FlatTable.wrap(0, 2)

	--- @param points number[]
	--- @param length? integer
	--- @return number
	function Polygon.area(points, length)
		length = length or math.ceil(#points / 2)

		local polygon = wrappedPolygon:intrude(points, length)
		local sum = 0
		for i = 1, polygon:getLength() do
			local x1, y1 = polygon:get(i)
			local x2, y2 = polygon:get(i + 1)

			sum = sum + (x1 * y2) - (y1 * x2)
		end
		return math.abs(sum / 2)
	end
end

do
	local wrappedPolygon = FlatTable.wrap(0, 2)

	--- @param points number[]
	--- @param length? integer
	--- @return boolean
	function Polygon.isClockwise(points, length)
		length = length or math.ceil(#points / 2)

		Debug.assert(length >= 3, "polygon must have at least 3 points, got %d", length)

		local polygon = wrappedPolygon:intrude(points, length)
		local p1x, p1y = polygon:get(1)
		local p2x, p2y = polygon:get(2)
		local p3x, p3y = polygon:get(3)

		local side = Line.sideOfLineSegment(p1x, p1y, p2x, p2y, p3x, p3y)
		return side < 0
	end
end

do
	local wrappedPolygon = FlatTable.wrap(0, 2)

	--- @param points number[]
	--- @param length? integer
	--- @return boolean
	function Polygon.isCounterClockwise(points, length)
		length = length or math.ceil(#points / 2)

		Debug.assert(length >= 3, "polygon must have at least 3 points, got %d", length)

		local polygon = wrappedPolygon:intrude(points, length)
		local p1x, p1y = polygon:get(1)
		local p2x, p2y = polygon:get(2)
		local p3x, p3y = polygon:get(3)

		local side = Line.sideOfLineSegment(p1x, p1y, p2x, p2y, p3x, p3y)
		return side > 0
	end
end

do
	local wrappedPolygon = FlatTable.wrap(0, 2)

	--- @param points number[]
	--- @param length? integer
	--- @return boolean
	function Polygon.isConcave(points, length)
		length = length or math.ceil(#points / 2)

		Debug.assert(length >= 3, "polygon must have at least 3 points, got %d", length)

		local polygon = wrappedPolygon:intrude(points, length)
		local side
		for i = 1, polygon:getLength() do
			local x1, y1 = polygon:get(i)
			local x2, y2 = polygon:get(i + 1)
			local x3, y3 = polygon:get(i + 2)

			local s = Line.sideOfLineSegment(x1, y1, x2, y2, x3, y3)
			side = side or s
			if s ~= side then
				return true
			end
		end

		return false
	end
end

--- @param points number[]
--- @param length? integer
--- @return boolean
function Polygon.isConvex(points, length)
	return not Polygon.isConcave(points, length)
end

do
	local wrappedPolygon = FlatTable.wrap(0, 2)

	--- @param points number[]
	--- @param length? integer
	function Polygon.reverseOrder(points, length)
		length = length or math.ceil(#points / 2)

		Debug.assert(length >= 3, "polygon must have at least 3 points, got %d", length)

		local polygon = wrappedPolygon:intrude(points, length)
		local length = polygon:getLength()
		local i = length
		local j = 1

		while i > j do
			local pix, piy = polygon:get(i)
			local pjx, pjy = polygon:get(j)

			polygon:set(i, pjx, pjy)
			polygon:set(j, pix, piy)

			i = i - 1
			j = j + 1
		end
	end
end

return Polygon
