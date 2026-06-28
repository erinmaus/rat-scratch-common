local Common = require("rat-scratch-math.Common")
local IndexedAdjacencyCache =
	require("rat-scratch-math.Geometry2D.impl.IndexedAdjacencyCache")
local Point = require("rat-scratch-math.Geometry2D.Point")
local PointAdjacencyCache =
	require("rat-scratch-math.Geometry2D.impl.PointAdjacencyCache")
local Table = require("rat-scratch-common.Table")
local FlatTable = require("rat-scratch-common").FlatTable

local Contour = {}

do
	local pointAdjacencyCache = PointAdjacencyCache()

	--- @param edges number[]
	--- @param count? integer
	--- @return number[][]
	function Contour.fromEdges(edges, count)
		count = #edges

		local cache = pointAdjacencyCache
		cache:reset()

		for i = 1, count, 4 do
			cache:add(edges[i], edges[i + 1], edges[i + 2], edges[i + 3])
		end

		return cache:resolve()
	end
end

do
	local indexedAdjacencyCache = IndexedAdjacencyCache()

	--- @param vertices number[]
	--- @param edges integer[]
	--- @param vertexCount? integer
	--- @param edgeCount? integer
	--- @return number[][]
	function Contour.fromIndexedEdges(vertices, edges, vertexCount, edgeCount)
		local cache = indexedAdjacencyCache

		cache:start(vertices, edges, vertexCount, edgeCount)
		local result = cache:resolve()
		cache:stop()

		return result
	end
end

do
	local wrappedPolygon = FlatTable.wrap(0, 2)

	--- @param points number[]
	--- @param length? integer
	--- @param epsilon? number
	--- @param result? number[]
	--- @return number[]
	function Contour.simplify(points, length, epsilon, result)
		result = result or {}
		length = length or math.ceil(#points / 2)
		epsilon = epsilon or Common.EPSILON

		local polygon = wrappedPolygon:intrude(points, length)

		local start
		local cnx, cny
		do
			local x1, y1 = polygon:get(1)
			local x2, y2 = polygon:get(2)
			local nx, ny = Point.directionNormal(x1, y1, x2, y2)

			for k = 1, polygon:getLength() do
				local j = -k
				local i = j - 1

				local x3, y3 = polygon:get(i)
				local x4, y4 = polygon:get(i)
				local onx, ony = Point.direction(x3, y3, x4, y4)

				if Point.dot(nx, ny, onx, ony) >= (1 - epsilon) then
					start = Table.wrapIndex(i, 2)
				end
			end

			cnx, cny = nx, ny
			start = start or 1
		end

		do
			local x, y = polygon:get(start)

			table.insert(result, x)
			table.insert(result, y)
		end

		for k = 1, polygon:getLength() do
			local j = start + k
			local i = j - 1

			local x1, y1 = polygon:get(i)
			local x2, y2 = polygon:get(j)
			local nx, ny = Point.directionNormal(x1, y1, x2, y2)
			local dot = Point.dot(cnx, cny, nx, ny)

			if dot < (1 - epsilon) then
				cnx, cny = nx, ny
				table.insert(result, x1)
				table.insert(result, y1)
			end
		end

		return result
	end
end

return Contour
