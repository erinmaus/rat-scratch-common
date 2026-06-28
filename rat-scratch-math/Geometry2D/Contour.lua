local PointAdjacencyCache = require "rat-scratch-math.Geometry2D.impl.PointAdjacencyCache"
local IndexedAdjacencyCache = require "rat-scratch-math.Geometry2D.impl.IndexedAdjacencyCache"

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

return Contour
