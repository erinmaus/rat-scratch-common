local Common = require("rat-scratch-math.Common")
local Point = require("rat-scratch-math.Geometry2D.Point")
local bit = require("bit")
local Search = require("rat-scratch-common").Search
local Table = require("rat-scratch-common").Table

local MarchingSquares = {}

local MarchingSquaresImpl = {}

MarchingSquaresImpl.CASES = {
	{},
	{ 1, 4 },
	{ 3, 4 },
	{ 1, 3 },
	{ 2, 3 },
	{ 1, 4, 2, 3 },
	{ 2, 4 },
	{ 1, 2 },
	{ 1, 2 },
	{ 2, 4 },
	{ 1, 2, 3, 4 },
	{ 2, 3 },
	{ 1, 3 },
	{ 3, 4 },
	{ 1, 4 },
	{},
}

--- @generic T
--- @param x number
--- @param y number
--- @param image T
--- @param sampleFunc RatScratch.Math.MarchingSquaresSampleFunc<T>
function MarchingSquaresImpl.calculateGradient(x, y, image, sampleFunc)
	local dx = sampleFunc(image, x + Common.EPSILON, y)
		- sampleFunc(image, x - Common.EPSILON, y)
	local dy = sampleFunc(image, x, y + Common.EPSILON)
		- sampleFunc(image, x, y - Common.EPSILON)
	dx, dy = Point.normal(dx, dy)

	return dx, dy
end

--- @alias RatScratch.Math.MarchingSquaresSampleFunc fun<T>(image: T, x: number, y: number): number, boolean

do
	local cachedEdges = {
		{ 0, 0 },
		{ 0, 0 },
		{ 0, 0 },
		{ 0, 0 },
	}

	local function _cachePoint(points, point)
		local index = Search.lessThanEqual(
			points,
			point,
			MarchingSquaresImpl.comparePoint
		)

		local p = points[index]
		if not (p and MarchingSquaresImpl.comparePoint(p, point) == 0) then
			p = { point[1], point[2], id = #points + 1 }
			table.insert(points, index + 1, p)
		end

		return p
	end

	local function _calculateDelta(a, b)
		if Common.equal(a, b) then
			return 0.5
		else
			return Common.saturate(-a / (b - a))
		end
	end

	--- @generic T
	--- @param edge number[]
	--- @param left number
	--- @param top number
	--- @param right number
	--- @param bottom number
	--- @param topLeft number
	--- @param topRight number
	--- @param bottomLeft number
	--- @param bottomRight number
	--- @param points number[][]
	--- @param image T
	--- @param sampleFunc RatScratch.Math.MarchingSquaresSampleFunc<T>
	--- @param results number[][]
	function MarchingSquaresImpl.generateSegments(
		edge,
		left,
		top,
		right,
		bottom,
		topLeft,
		topRight,
		bottomLeft,
		bottomRight,
		image,
		sampleFunc,
		points,
		results
	)
		if #edge == 0 then
			return
		end

		local edges = cachedEdges

		local leftDelta = _calculateDelta(topLeft, bottomLeft)
		local topDelta = _calculateDelta(topLeft, topRight)
		local rightDelta = _calculateDelta(topRight, bottomRight)
		local bottomDelta = _calculateDelta(bottomLeft, bottomRight)

		edges[1][1], edges[1][2] = left, Common.lerp(top, bottom, leftDelta)
		edges[2][1], edges[2][2] = Common.lerp(left, right, topDelta), top
		edges[3][1], edges[3][2] = right, Common.lerp(top, bottom, rightDelta)
		edges[4][1], edges[4][2] = Common.lerp(left, right, bottomDelta), bottom

		for i = 1, #edge, 2 do
			local j = i + 1

			local edge1 = edges[edge[i]]
			local edge2 = edges[edge[j]]

			local swap = false
			do
				local nx, ny = Point.directionNormal(edge1[1], edge1[2], edge2[1], edge2[2])

				local mx, my = Common.lerp(edge1[1], edge2[1], 0.5), Common.lerp(edge1[2], edge2[2], 0.5)
				local tx, ty = MarchingSquaresImpl.calculateGradient(mx, my, image, sampleFunc)
				tx, ty = Point.left(tx, ty)

				local dot = Point.dot(nx, ny, tx, ty)
				if Common.equal(dot, 0, Common.EPSILON) then
					if MarchingSquaresImpl.lessPoint(edge2, edge1) then
						swap = true
					end
				elseif dot > 0 then
					swap = true
				end
			end

			if swap then
				edge1, edge2 = edge2, edge1
			end

			table.insert(results, _cachePoint(points, edge1))
			table.insert(results, _cachePoint(points, edge2))
		end
	end
end

do
	--- @param boolean boolean
	local function _tonumber(boolean)
		return boolean and 1 or 0
	end

	--- @generic T
	--- @param x number
	--- @param y number
	--- @param step number
	--- @param image T
	--- @param sampleFunc RatScratch.Math.MarchingSquaresSampleFunc<T>
	--- @param points number[][]
	--- @param results number[][]
	function MarchingSquaresImpl.sample(x, y, step, image, sampleFunc, points, results)
		local left = x
		local right = x + step
		local top = y
		local bottom = y + step

		local topLeftValue, topLeft = sampleFunc(image, left, top)
		local topRightValue, topRight = sampleFunc(image, right, top)
		local bottomLeftValue, bottomLeft = sampleFunc(image, left, bottom)
		local bottomRightValue, bottomRight = sampleFunc(image, right, bottom)

		local a = bit.lshift(_tonumber(topLeft), 3)
		local b = bit.lshift(_tonumber(topRight), 2)
		local c = bit.lshift(_tonumber(bottomRight), 1)
		local d = _tonumber(bottomLeft)

		local index = bit.bor(a, b, c, d) + 1
		local case = MarchingSquaresImpl.CASES[index]

		MarchingSquaresImpl.generateSegments(
			case,
			left,
			top,
			right,
			bottom,
			topLeftValue,
			topRightValue,
			bottomLeftValue,
			bottomRightValue,
			image,
			sampleFunc,
			points,
			results
		)
	end
end

--- @param a number[]
--- @param b number[]
function MarchingSquaresImpl.comparePoint(a, b)
	local s = a[1] - b[1]
	if math.abs(s) < Common.EPSILON then
		local t = a[2] - b[2]
		if math.abs(t) < Common.EPSILON then
			return 0
		else
			return Common.sign(t)
		end
	end

	return Common.sign(s)
end

--- @param a number[]
--- @param b number[]
function MarchingSquaresImpl.lessPoint(a, b)
	return MarchingSquaresImpl.comparePoint(a, b) < 0
end

do
	--- @alias RatScratch.Math.impl.MarchingSquaresAdjacencyList {
	---   destination: number[][],
	--- }

	--- @type table<number[], RatScratch.Math.impl.MarchingSquaresAdjacencyList>
	local adjacency = {}

	--- @type RatScratch.Math.impl.MarchingSquaresAdjacencyList
	local adjacencyFreeList = {}

	--- @type RatScratch.Math.impl.MarchingSquaresAdjacencyList
	local adjacencyUsedList = {}

	--- @type table<number[], true>
	local visited = {}

	local function _getFreeAdjacencyList()
		local list = table.remove(adjacencyFreeList)
		if not list then
			list = { destination = {} }
			table.insert(adjacencyUsedList, list)
		else
			Table.clear(list.destination)
		end

		return list
	end

	local function _getAdjacencyList(point)
		local list = adjacency[point]
		if not list then
			list = _getFreeAdjacencyList()
			adjacency[point] = list
		end

		return list
	end

	local function _addPointToList(list, otherPoint)
		local index = Search.lessThanEqual(
			list,
			otherPoint,
			MarchingSquaresImpl.comparePoint
		)

		if
			not (
				index >= 1
				and index <= #list
				and MarchingSquaresImpl.comparePoint(
						otherPoint,
						list[index]
					)
					== 0
			)
		then
			table.insert(list, index + 1, otherPoint)
		end
	end

	local function _addAdjacencyListDestination(point, otherPoint)
		local list = _getAdjacencyList(point)
		_addPointToList(list.destination, otherPoint)
	end

	local function _prepareAdjacencyList()
		adjacencyFreeList, adjacencyUsedList =
			adjacencyUsedList, adjacencyFreeList
		Table.clear(adjacency)
		Table.clear(visited)
	end

	local function _generateAdjacencyList(segments)
		_prepareAdjacencyList()

		for i = 1, #segments, 2 do
			local point1 = segments[i]
			local point2 = segments[i + 1]

			_addAdjacencyListDestination(point1, point2)
		end
	end

	--- @param segments number[][]
	--- @return number[][]
	function MarchingSquaresImpl.generateContours(segments)
		if true then
			local contour = {}

			for _, segment in ipairs(segments) do
				table.insert(contour, segment[1])
				table.insert(contour, segment[2])
				table.insert(contour, segment[3])
				table.insert(contour, segment[4])
			end

			return { contour }
		end
		_generateAdjacencyList(segments)

		local contours = {}
		while next(adjacency) do
			local point = next(adjacency)

			local contour = {}
			while point and not visited[point] do
				table.insert(contour, point[1])
				table.insert(contour, point[2])

				local list = adjacency[point]
				visited[point] = true
				adjacency[point] = nil

				if #list.destination >= 2 and #contour >= 4 then
					local n = math.ceil(#contour / 2)
					local previousIndex = Table.wrapIndex(-2, n)
					local i = Table.indexToStride(previousIndex, 2)
					local j = i + 1

					local px, py = contour[i], contour[j]
					local cx, cy = point[1], point[2]

					local nx1, ny1 = Point.directionNormal(px, py, cx, cy)

					local maxDot = -math.huge
					for _, otherPoint in ipairs(list.destination) do
						local nx2, ny2 = Point.directionNormal(cx, cy, otherPoint[1], otherPoint[2])

						local dot = Point.dot(nx1, ny1, nx2, ny2)
						if dot > maxDot then
							maxDot = dot
							point = otherPoint
						end
					end
				else
					if #list.destination == 0 then
						point = nil
					end

					for _, otherPoint in ipairs(list.destination) do
						if not visited[otherPoint] then
							point = otherPoint
							break
						end
					end
				end
			end

			table.insert(contours, contour)
		end

		return contours
	end
end

do
	local cachedPoints = {}

	--- @generic T
	--- @param x1 number
	--- @param y1 number
	--- @param x2 number
	--- @param y2 number
	--- @param step number
	--- @param image T
	--- @param sampleFunc RatScratch.Math.MarchingSquaresSampleFunc<T>
	--- @return number[][]
	function MarchingSquares.generate(x1, y1, x2, y2, step, image, sampleFunc)
		local points = cachedPoints
		Table.clear(points)

		local result = {}
		for x = x1, x2, step do
			for y = y1, y2, step do
				MarchingSquaresImpl.sample(
					x,
					y,
					step,
					image,
					sampleFunc,
					points,
					result
				)
			end
		end

		return MarchingSquaresImpl.generateContours(result)
	end
end

return MarchingSquares
