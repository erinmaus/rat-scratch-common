local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local Point = require("rat-scratch-math.Geometry2D.Point")
local PointsCache = require("rat-scratch-math.Geometry2D.impl.PointsCache")
local SortedPointsList =
	require("rat-scratch-math.Geometry2D.impl.SortedPointsList")

--- @alias RatScratch.Math.Geometry2D.impl.PositionAdjacencyList table<number[], RatScratch.Math.Geometry2D.impl.SortedPointsList>

--- @class RatScratch.Math.Geometry2D.impl.PointAdjacencyCache : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Math.Geometry2D.impl.PointAdjacencyCache
--- @field private points RatScratch.Math.Geometry2D.impl.PointsCache
--- @field private vertices RatScratch.Math.Geometry2D.impl.SortedPointsList
--- @field private adjacencyLists table<number[], RatScratch.Math.Geometry2D.impl.SortedPointsList>
--- @field private freeAdjacencyLists RatScratch.Math.Geometry2D.impl.SortedPointsList[]
--- @field private usedAdjacencyLists RatScratch.Math.Geometry2D.impl.SortedPointsList[]
--- @field private visited table<number[], true>
--- @field private pending number[][]
local PointAdjacencyCache = Object()

function PointAdjacencyCache:new()
	self.points = PointsCache()
	self.vertices = SortedPointsList()
	self.adjacencyLists = {}
	self.freeAdjacencyLists = {}
	self.usedAdjacencyLists = {}
	self.visited = {}
	self.pending = {}
end

function PointAdjacencyCache:reset()
	self.freeAdjacencyLists, self.usedAdjacencyLists =
		self.usedAdjacencyLists, self.freeAdjacencyLists

	self.points:reset()
	self.vertices:reset()

	Table.clear(self.adjacencyLists)
	Table.clear(self.visited)
	Table.clear(self.pending)
end

--- @private
function PointAdjacencyCache:_getFreeAdjacencyList()
	local list = table.remove(self.freeAdjacencyLists)
	if not list then
		list = SortedPointsList()
	else
		list:reset()
	end

	table.insert(self.usedAdjacencyLists, list)
	return list
end

--- @private
--- @param point number[]
function PointAdjacencyCache:_getAdjacencyList(point)
	local list = self.adjacencyLists[point]
	if not list then
		list = self:_getFreeAdjacencyList()
		self.adjacencyLists[point] = list
	end
	return list
end

function PointAdjacencyCache:_add(a, b)
	local list = self:_getAdjacencyList(a)
	list:add(b)
end

do
	--- @param x1 number
	--- @param y1 number
	--- @param x2 number
	--- @param y2 number
	function PointAdjacencyCache:add(x1, y1, x2, y2)
		local a = self.vertices:add(self.points:get(x1, y1))
		local b = self.vertices:add(self.points:get(x2, y2))

		self:_add(a, b)
		self:_add(b, a)
	end
end

do
	local point = {}

	--- @param x number
	--- @param y number
	--- @return RatScratch.Math.Geometry2D.impl.SortedPointsList
	function PointAdjacencyCache:getAdjacent(x, y)
		local p = point
		p[1], p[2] = x, y

		local cachedPoint = self.vertices:get(p)
		return self:_getAdjacencyList(cachedPoint)
	end
end

--- @return number[][]
function PointAdjacencyCache:getVertices()
	return self.vertices:getPoints()
end

--- @return number[][]
function PointAdjacencyCache:resolve()
	for _, point in ipairs(self.vertices:getPoints()) do
		table.insert(self.pending, point)
	end
	table.sort(self.pending, SortedPointsList.less)

	local contours = {}
	while #self.pending > 0 do
		local vertex
		repeat
			vertex = table.remove(self.pending, 1)
		until not (vertex and self.visited[vertex])

		if not vertex then
			break
		end

		local contour = {}
		while vertex and not self.visited[vertex] do
			self.visited[vertex] = true

			table.insert(contour, vertex[1])
			table.insert(contour, vertex[2])

			local list = self:_getAdjacencyList(vertex)
			local adjacentVertices = list:getPoints()

			local nextVertex
			if #contour >= 4 then
				local n = math.ceil(#contour / 2)
				local previousIndex = Table.wrapIndex(-2, n)
				local i = Table.indexToStride(previousIndex, 2)
				local j = i + 1

				local px, py = contour[i], contour[j]
				local cx, cy = vertex[1], vertex[2]

				local nx1, ny1 = Point.directionNormal(px, py, cx, cy)

				local maxDot = -math.huge
				for _, otherVertex in ipairs(adjacentVertices) do
					if not self.visited[otherVertex] then
						local nx2, ny2 = Point.directionNormal(
							cx,
							cy,
							otherVertex[1],
							otherVertex[2]
						)

						local dot = Point.dot(nx1, ny1, nx2, ny2)
						if dot > maxDot then
							maxDot = dot
							nextVertex = otherVertex
						end
					end
				end
			else
				for _, otherVertex in ipairs(adjacentVertices) do
					if not self.visited[otherVertex] then
						nextVertex = otherVertex
						break
					end
				end
			end

			vertex = nextVertex
		end

		table.insert(contours, contour)
	end

	return contours
end

return PointAdjacencyCache
