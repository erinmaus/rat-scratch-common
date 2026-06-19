local Polygon = require("rat-scratch-math.Geometry2D.Polygon")
local FlatTable = require("rat-scratch-common").FlatTable
local Table     = require("rat-scratch-common").Table

local Minkowski = {}
local MinkowskiImpl = {}

do
	local cachePolygon = {}
	local wrappedPolygon = FlatTable.wrap(0, 2)
	local wrappedResultPolygon = FlatTable.wrap(0, 2)

	--- @private
	--- @param result number[]
	--- @param t love.Transform?
	--- @param points number[]
	--- @param length? integer 
	--- @param sign 1 | -1
	function MinkowskiImpl._reorderPoints(result, t, points, length, sign)
		length = length or math.ceil(#points / 2)

		Polygon.transform(points, t, length, cachePolygon)
		local polygon = wrappedPolygon:intrude(cachePolygon, length)

		for i = 1, polygon:getLength() do
			local x, y = polygon:get(i)
			polygon:set(i, x * sign, y * sign)
		end

		local position = 1
		local currentX, currentY = polygon:get(1)

		for i = position + 1, polygon:getLength() do
			local x, y = polygon:get(i)
			if y < currentY or (y == currentY and x < currentX) then
				position = i
				currentX = x
				currentY = y
			end
		end

		local resultPolygon = wrappedResultPolygon:intrude(result, length)
		for k = 1, polygon:getLength() do
			local i = position + k - 1
			resultPolygon:set(k, polygon:get(i))
		end
	end
end

do
	local pointsSum = {}
	local pointsLength = 0
	local aPoints = FlatTable.wrap(0, 2)
	local bPoints = FlatTable.wrap(0, 2)

	--- @private
	--- @param pa number[]
	--- @param pb number[]
	--- @param al? integer
	--- @param bl? integer
	--- @return boolean, table?, integer?
	function MinkowskiImpl._sum(pa, pb, al, bl)
		al = al or math.ceil(#pa / 2)
		bl = bl or math.ceil(#pb / 2)

		local aPointer = 1
		local bPointer = 1

		local a = aPoints:intrude(pa, al)
		local b = bPoints:intrude(pb, bl)

		local an = a:getLength()
		local bn = b:getLength()

		local result = pointsSum
		local k = 1
		while aPointer <= an or bPointer <= bn do
			local ax, ay = a:get(aPointer)
			local bx, by = b:get(bPointer)

			local i = Table.indexToStride(k, 2)
			result[i], result[i + 1] = ax + bx, ay + by
			k = k + 1

			local nax, nay = a:get(aPointer + 1)
			local nbx, nby = b:get(bPointer + 1)
			
			local adx, ady = nax - ax, nay - ay
			local bdx, bdy = nbx - bx, nby - by
			local cross = adx * bdy - ady * bdx

			local success = false
			if cross >= 0 and aPointer <= an then
				aPointer = aPointer + 1
				success = true
			end

			if cross <= 0 and bPointer <= bn then
				bPointer = bPointer + 1
				success = true
			end

			if not success then
				return false
			end
		end

		pointsLength = k - 1
		return true, pointsSum, pointsLength
	end

	--- @param result? number[]
	--- @return number[], integer
	function Minkowski.getLastDebugMinkowskiPolygon(result)
		local result = result or {}

		local n = pointsLength * 2
		for i = 1, n do
			result[i] = pointsSum[i]
		end

		return result, pointsLength
	end
end

do
	local polygonA = {}
	local polygonB = {}

	--- @param a number[]
	--- @param b number[]
	--- @param at love.Transform | nil
	--- @param bt love.Transform | nil
	--- @param al integer?
	--- @param bl integer?
	--- @return boolean, number, number, number
	function Minkowski.difference(a, b, at, bt, al, bl)
		local ra = polygonA
		local rb = polygonB

		MinkowskiImpl._reorderPoints(ra, at, a, al, 1)
		MinkowskiImpl._reorderPoints(rb, bt, b, bl, -1)

		local success, result, length = MinkowskiImpl._sum(ra, rb, al, bl)
		if not (success and result and length) then
			return false, 0, 0, 0
		end

		local isInside = Polygon.isPointInside(0, 0, result, length)
		local nx, ny, distance = Polygon.pointDistance(0, 0, result, length)

		if isInside then
			distance = -distance
		end

		return isInside, nx, ny, distance
	end

	--- @param a number[]
	--- @param b number[]
	--- @param at love.Transform | nil
	--- @param bt love.Transform | nil
	--- @param al integer?
	--- @param bl integer?
	--- @return boolean, number, number, number
	function Minkowski.sum(a, b, at, bt, al, bl)
		local ra = polygonA
		local rb = polygonB

		MinkowskiImpl._reorderPoints(ra, at, a, al, 1)
		MinkowskiImpl._reorderPoints(rb, bt, b, bl, 1)

		local success, result, length = MinkowskiImpl._sum(ra, rb, al, bl)
		if not (success and result and length) then
			return false, 0, 0, 0
		end

		local isInside = Polygon.isPointInside(0, 0, result, length)
		local nx, ny, distance = Polygon.pointDistance(0, 0, result, length)

		if isInside then
			distance = -distance
		end

		return isInside, nx, ny, distance
	end
end

return Minkowski
