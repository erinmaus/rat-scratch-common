local FlatTable = require("rat-scratch-common").FlatTable
local Object = require("rat-scratch-common").Object
local Search = require("rat-scratch-common").Search
local Table = require("rat-scratch-common").Table
local Point = require("rat-scratch-math.Geometry2D.Point")
local Common      = require("rat-scratch-math.Common")

--- @class RatScratch.Math.Geometry2D.impl.IndexedAdjacencyCache : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Math.Geometry2D.impl.IndexedAdjacencyCache
--- @field private wrappedEdges RatScratch.Common.FlatTable<integer>
--- @field private wrappedVertices RatScratch.Common.FlatTable<number>
--- @field private adjacencyLists table<integer, integer[]>
--- @field private freeAdjacencyLists integer[][]
--- @field private usedAdjacencyLists integer[][]
--- @field private visited table<integer, true>
--- @field private pending integer[]
local IndexedAdjacencyCache = Object()

function IndexedAdjacencyCache:new()
	self.wrappedEdges = FlatTable.wrap(0, 2)
	self.wrappedVertices = FlatTable.wrap(0, 2)

	self.adjacencyLists = {}
	self.freeAdjacencyLists = {}
	self.usedAdjacencyLists = {}
	self.visited = {}
	self.pending = {}
end

--- @param vertices number[]
--- @param edges number[]
--- @param vertexCount? integer
--- @param edgeCount? integer
function IndexedAdjacencyCache:start(vertices, edges, vertexCount, edgeCount)
	self.wrappedEdges:intrude(edges, edgeCount or math.ceil(#edges / 2))
	self.wrappedVertices:intrude(edges, vertexCount or math.ceil(#vertices / 2))

	for i = 1, self.wrappedEdges:getLength() do
		local a, b = self.wrappedEdges:get(i)
		self:add(a, b)
	end

	self.freeAdjacencyLists, self.usedAdjacencyLists =
		self.usedAdjacencyLists, self.freeAdjacencyLists

	Table.clear(self.adjacencyLists)
	Table.clear(self.visited)
	Table.clear(self.pending)
end

do
	local emptyEdges = {}
	local emptyVertices = {}

	function IndexedAdjacencyCache:stop()
		self.wrappedEdges:intrude(emptyEdges, 0)
		self.wrappedVertices:intrude(emptyVertices, 0)
	end
end

--- @private
function IndexedAdjacencyCache:_getFreeAdjacencyList()
	local list = table.remove(self.freeAdjacencyLists)
	if not list then
		list = {}
	else
		Table.clear(list)
	end

	table.insert(self.usedAdjacencyLists, list)
	return list
end

--- @private
--- @param index integer
function IndexedAdjacencyCache:_getAdjacencyList(index)
	local list = self.adjacencyLists[index]
	if not list then
		list = self:_getFreeAdjacencyList()
		self.adjacencyLists[index] = list
	end
	return list
end

---@param a number
---@param b number
---@return -1 | 0 | 1
function IndexedAdjacencyCache.compareIndex(a, b)
	return Common.zerosign(a - b)
end

--- @private
--- @param a integer
--- @param b integer
function IndexedAdjacencyCache:_add(a, b)
	local list = self:_getAdjacencyList(a)

	local index = Search.lessThanEqual(list, b, IndexedAdjacencyCache.compareIndex)
	if not (index >= 1 and index <= #list and list[index] == b) then
		table.insert(list, index + 1, a)
	end
end

--- @param a integer
--- @param b integer
function IndexedAdjacencyCache:add(a, b)
	self:_add(a, b)
	self:_add(b, a)
end

--- @param index integer
--- @return integer[]
function IndexedAdjacencyCache:getAdjacent(index)
	return self:_getAdjacencyList(index)
end

--- @return number[][]
function IndexedAdjacencyCache:resolve()
	for index = 1, self.wrappedVertices:getLength() do
		table.insert(self.pending, index)
	end

	local contours = {}
	while #self.pending > 0 do
		local vertexIndex
		repeat
			vertexIndex = table.remove(self.pending)
		until not (vertexIndex and self.visited[vertexIndex])

		if not vertexIndex then
			break
		end

		local contour = {}
		while vertexIndex and not self.visited[vertexIndex] do
			self.visited[vertexIndex] = true

			local cx, cy = self.wrappedVertices:get(vertexIndex)
			table.insert(contour, cx)
			table.insert(contour, cy)

			local adjacentVertices = self:_getAdjacencyList(vertexIndex)

			local nextVertexIndex
			if #contour >= 4 then
				local n = math.ceil(#contour / 2)
				local previousIndex = Table.wrapIndex(-2, n)
				local i = Table.indexToStride(previousIndex, 2)
				local j = i + 1

				local px, py = contour[i], contour[j]
				local nx1, ny1 = Point.directionNormal(px, py, cx, cy)

				local maxDot = -math.huge
				for _, otherVertexIndex in ipairs(adjacentVertices) do
					if not self.visited[otherVertexIndex] then
						local ox, oy = self.wrappedVertices:get(otherVertexIndex)
						local nx2, ny2 = Point.directionNormal(cx, cy, ox, oy)

						local dot = Point.dot(nx1, ny1, nx2, ny2)
						if dot > maxDot then
							maxDot = dot
							nextVertexIndex = otherVertexIndex
						end
					end
				end
			else
				for _, otherVertexIndex in ipairs(adjacentVertices) do
					if not self.visited[otherVertexIndex] then
						nextVertexIndex = otherVertexIndex
						break
					end
				end
			end

			vertexIndex = nextVertexIndex
		end

		table.insert(contours, contour)
	end

	return contours
end

return IndexedAdjacencyCache
