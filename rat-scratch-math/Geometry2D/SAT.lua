local Table = require("rat-scratch-common").Table
local FlatTable = require("rat-scratch-common").FlatTable
local Common = require("rat-scratch-math.Common")
local Point = require("rat-scratch-math.Geometry2D.Point")
local Polygon = require("rat-scratch-math.Geometry2D.Polygon")

local SAT = {}
local SATImpl = {}

--- @private
--- @param polygon RatScratch.Common.FlatTable<number>
--- @param ax number
--- @param ay number
--- @return number, number
function SATImpl._projectPolygonToAxis(polygon, ax, ay)
	local min, max

	for i = 1, polygon:getLength() do
		local x1, y1 = polygon:get(i)
		local dot = Point.dot(x1, y1, ax, ay)

		min = math.min(min or dot, dot)
		max = math.max(max or dot, dot)
	end

	return min, max
end

--- @private
--- @param minA number
--- @param maxA number
--- @param minB number
--- @param maxB number
--- @return number
function SATImpl._intervalDistance(minA, maxA, minB, maxB)
	if minA < minB then
		return minB - maxA
	end

	return minA - maxB
end

--- @private
--- @param polygonA RatScratch.Common.FlatTable<number>
--- @param polygonB RatScratch.Common.FlatTable<number>
--- @return boolean, number, number, number, integer
function SATImpl._projectPolygon(polygonA, polygonB)
	local positiveMinDistance, pnx, pny, pi
	local negativeMinDistance, nnx, nny, ni

	local collision = true

	for i1 = 1, polygonA:getLength() do
		local x1, y1 = polygonA:get(i1)
		local x2, y2 = polygonA:get(i1 + 1)

		local nx, ny = Point.normal(x2 - x1, y2 - y1)
		local ax, ay = Point.right(nx, ny)

		local minA, maxA = SATImpl._projectPolygonToAxis(polygonA, ax, ay)
		local minB, maxB = SATImpl._projectPolygonToAxis(polygonB, ax, ay)

		local depth = SATImpl._intervalDistance(minA, maxA, minB, maxB)
		collision = collision and depth < 0

		if
			depth >= 0
			and (not positiveMinDistance or depth < positiveMinDistance)
		then
			positiveMinDistance = depth
			pnx, pny = ax, ay
			pi = i1
		elseif
			depth <= 0
			and (not negativeMinDistance or depth > negativeMinDistance)
		then
			negativeMinDistance = depth
			nnx, nny = ax, ay
			ni = i1
		end
	end

	local minDistance, cnx, cny, index
	if negativeMinDistance then
		minDistance = negativeMinDistance
		cnx, cny = nnx, nny
		index = ni
	elseif positiveMinDistance then
		minDistance = positiveMinDistance
		cnx, cny = pnx, pny
		index = pi
	end

	return collision, math.abs(minDistance), cnx, cny, index
end

do
	local wrappedPolygonA = FlatTable.wrap(0, 2)
	local wrappedPolygonB = FlatTable.wrap(0, 2)

	--- @private
	--- @param a number[]
	--- @param b number[]
	--- @param al integer
	--- @param bl integer
	--- @return boolean, number, number, number, table, integer, integer
	function SATImpl._projectPolygons(a, b, al, bl)
		local polygonA = wrappedPolygonA:intrude(a, al)
		local polygonB = wrappedPolygonB:intrude(b, bl)

		local collisionA, minA, anx, any, indexA =
			SATImpl._projectPolygon(polygonA, polygonB)
		local collisionB, minB, bnx, bny, indexB =
			SATImpl._projectPolygon(polygonB, polygonA)
		local collision = collisionA and collisionB

		if collisionA ~= collisionB then
			if collisionA then
				return collision, minA, anx, any, a, indexA, indexB
			elseif collisionB then
				return collision, minB, bnx, bny, b, indexB, indexA
			end
		end

		if minA < minB then
			return collision, minA, anx, any, a, indexA, indexB
		end

		return collision, minB, bnx, bny, b, indexB, indexA
	end
end

do
	local transformedPolygonA = {}
	local transformedPolygonB = {}

	--- @param a number[]
	--- @param b number[]
	--- @param at love.Transform | nil
	--- @param bt love.Transform | nil
	--- @param al? integer
	--- @param bl? integer
	--- @param meta? table
	--- @return boolean, number, number, number, table?
	function SAT.project(a, b, at, bt, al, bl, meta)
		al = al or math.ceil(#a / 2)
		bl = bl or math.ceil(#b / 2)

		local ra = transformedPolygonA
		local rb = transformedPolygonB

		Polygon.transform(a, at, al, ra)
		Polygon.transform(b, bt, bl, rb)

		local collision, distance, nx, ny, polygon, edgeA, edgeB =
			SATImpl._projectPolygons(ra, rb, al, bl)
		if collision then
			distance = -distance
		end

		local acx, acy = Polygon.center(ra, al)
		local bcx, bcy = Polygon.center(rb, bl)

		local sign = Common.sign(Point.dot(nx, ny, acx - bcx, acy - bcy))
		if sign <= 0 then
			nx, ny = -nx, -ny
		end

		if meta then
			Table.clear(meta)
			meta.polygon = polygon == ra and a or b
			meta.edge = edgeA
			meta.otherEdge = edgeB
		end

		return collision, nx, ny, distance, meta
	end
end

return SAT
