local Common = require("rat-scratch-math.Common")
local Table = require("rat-scratch-common").Table
local Contour = require("rat-scratch-math.Geometry2D.Contour")
local Isosurface = require("rat-scratch-math.Geometry2D.Isosurface")

local DualContour = {}
local DualContourImpl = {}

do
	--- @alias RatScratch.Math.impl.DualContourCachePoints {
	---   n: integer,
	---   points: number[][],
	--- }
	--- @type RatScratch.Math.impl.DualContourCachePoints
	local cachedPoints = { n = 0, points = {} }

	function DualContourImpl.resetPointCache()
		cachedPoints.n = 0
	end

	--- @param x number
	--- @param y number
	--- @param nx number?
	--- @param ny number?
	--- @return number[]
	function DualContourImpl.newPoint(x, y, nx, ny)
		local n = cachedPoints.n + 1
		local point = cachedPoints.points[n]
		if not point then
			point = {}
			cachedPoints.points[n] = point
		end

		point[1], point[2] = x, y
		point[3], point[4] = nx or 0, ny or 0
		cachedPoints.n = n

		return point
	end

	--- @alias RatScratch.Math.impl.DualContourCacheGrid {
	---   x: number,
	---   y: number,
	---   width: integer,
	---   height: integer,
	---   inverseStep: number,
	---   cells: number[][],
	--- }
	local grid =
		{ x = 0, y = 0, width = 0, height = 0, inverseStep = 0, cells = {} }

	--- @param x1 number
	--- @param y1 number
	--- @param x2 number
	--- @param y2 number
	--- @param step number
	function DualContourImpl.resizeGrid(x1, y1, x2, y2, step)
		grid.x = x1
		grid.y = y1
		grid.inverseStep = 1 / step
		grid.width = math.ceil((x2 - x1) * grid.inverseStep) + 1
		grid.height = math.ceil((y2 - y1) * grid.inverseStep) + 1
		Table.clear(grid.cells)
	end

	function DualContourImpl.setGridCell(x, y, value)
		local g = grid
		local key = DualContourImpl.getGridKey(x, y)
		g.cells[key] = value
	end

	function DualContourImpl.getGridCell(x, y)
		local g = grid
		local key = DualContourImpl.getGridKey(x, y)
		return g.cells[key]
	end

	function DualContourImpl.getGridKey(x, y)
		local g = grid
		local i = math.floor((x - g.x) * g.inverseStep) + 1
		local j = math.floor((y - g.y) * g.inverseStep) + 1
		return Table.to2DKey(i, j, grid.width)
	end

	--- @alias RatScratch.Math.impl.DualContourEdgeCache {
	---   n: integer,
	---   edges: number[][],
	--- }
	local cachedEdges = { n = 0, edges = {} }

	function DualContourImpl.resetEdgeCache()
		cachedEdges.n = 0
	end

	function DualContourImpl.newEdge(a1, a2, b1, b2)
		local n = cachedEdges.n + 1
		local edge = cachedEdges.edges[n]
		if not edge then
			edge = {}
			cachedEdges.edges[n] = edge
		end

		edge[1], edge[2] = a1, a2
		edge[3], edge[4] = b1, b2
		cachedEdges.n = n

		return edge
	end

	function DualContourImpl.getEdges()
		return cachedEdges.n, cachedEdges.edges
	end
end

--- @param points number[][]
--- @return number[]
function DualContourImpl.solve(points)
	local xx, xy, yy = 0, 0, 0
	local bx, by = 0, 0

	for i = 1, #points do
		local p = points[i]
		local px, py, nx, ny = p[1], p[2], p[3], p[4]

		xx = xx + nx * nx
		xy = xy + nx * ny
		yy = yy + ny * ny

		local dot = px * nx + py * ny
		bx = bx + dot * nx
		by = by + dot * ny
	end

	local determinant = xx * yy - xy * xy

	if math.abs(determinant) > Common.EPSILON then
		local inverseDeterminant = 1 / determinant
		local x = (yy * bx - xy * by) * inverseDeterminant
		local y = (-xy * bx + xx * by) * inverseDeterminant
		return DualContourImpl.newPoint(x, y)
	end

	local ax, ay = points[1][1], points[1][2]
	for i = 2, #points do
		local p = points[i]
		ax = ax + p[1]
		ay = ay + p[2]
	end
	local inverseLength = 1 / #points

	return DualContourImpl.newPoint(ax * inverseLength, ay * inverseLength)
end

do
	local cachedPoints = {}

	--- @generic T
	--- @param x number
	--- @param y number
	--- @param step number
	--- @param image T
	--- @param sampleFunc RatScratch.Math.IsosurfaceSampleFunc<T>
	function DualContourImpl.sample(x, y, step, image, sampleFunc)
		local points = cachedPoints
		Table.clear(points)

		local left = x
		local right = x + step
		local top = y
		local bottom = y + step

		local topLeftValue = sampleFunc(image, left, top)
		local topRightValue = sampleFunc(image, right, top)
		local bottomLeftValue = sampleFunc(image, left, bottom)
		local bottomRightValue = sampleFunc(image, right, bottom)

		if Isosurface.didCross(topLeftValue, topRightValue) then
			local delta = Isosurface.calculateDelta(topLeftValue, topRightValue)
			local px = Common.lerp(left, right, delta)
			local py = top
			local nx, ny =
				Isosurface.calculateGradient(px, py, image, sampleFunc)
			table.insert(points, DualContourImpl.newPoint(px, py, nx, ny))
		end

		if Isosurface.didCross(bottomLeftValue, bottomRightValue) then
			local delta =
				Isosurface.calculateDelta(bottomLeftValue, bottomRightValue)
			local px = Common.lerp(left, right, delta)
			local py = bottom
			local nx, ny =
				Isosurface.calculateGradient(px, py, image, sampleFunc)
			table.insert(points, DualContourImpl.newPoint(px, py, nx, ny))
		end

		if Isosurface.didCross(topLeftValue, bottomLeftValue) then
			local delta =
				Isosurface.calculateDelta(topLeftValue, bottomLeftValue)
			local px = left
			local py = Common.lerp(top, bottom, delta)
			local nx, ny =
				Isosurface.calculateGradient(px, py, image, sampleFunc)
			table.insert(points, DualContourImpl.newPoint(px, py, nx, ny))
		end

		if Isosurface.didCross(topRightValue, bottomRightValue) then
			local delta =
				Isosurface.calculateDelta(topRightValue, bottomRightValue)
			local px = right
			local py = Common.lerp(top, bottom, delta)
			local nx, ny =
				Isosurface.calculateGradient(px, py, image, sampleFunc)
			table.insert(points, DualContourImpl.newPoint(px, py, nx, ny))
		end

		if #points >= 1 then
			local result = DualContourImpl.solve(points)
			DualContourImpl.setGridCell(x, y, result)
		end
	end

	--- @generic T
	--- @param x1 number
	--- @param y1 number
	--- @param x2 number
	--- @param y2 number
	--- @param step number
	--- @param image T
	--- @param sampleFunc RatScratch.Math.IsosurfaceSampleFunc<T>
	function DualContourImpl.generateSamples(
		x1,
		y1,
		x2,
		y2,
		step,
		image,
		sampleFunc
	)
		for x = x1, x2, step do
			for y = y1, y2, step do
				DualContourImpl.sample(x, y, step, image, sampleFunc)
			end
		end
	end
end

--- @generic T
--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @param step number
--- @param image T
--- @param sampleFunc RatScratch.Math.IsosurfaceSampleFunc<T>
function DualContourImpl.generateEdges(x1, y1, x2, y2, step, image, sampleFunc)
	for x = x1 + step, x2, step do
		for y = y1, y2, step do
			local top = sampleFunc(image, x, y)
			local bottom = sampleFunc(image, x, y + step)

			if Isosurface.didCross(top, bottom) then
				DualContourImpl.newEdge(x - step, y, x, y)
			end
		end
	end

	for x = x1, x2, step do
		for y = y1 + step, y2, step do
			local left = sampleFunc(image, x, y)
			local right = sampleFunc(image, x + step, y)

			if Isosurface.didCross(left, right) then
				DualContourImpl.newEdge(x, y - step, x, y)
			end
		end
	end
end

do
	local cachedEdges = {}

	function DualContourImpl.generateContours()
		Table.clear(cachedEdges)

		local n, inputEdges = DualContourImpl.getEdges()
		for i = 1, n do
			local edge = inputEdges[i]

			local cell1 = DualContourImpl.getGridCell(edge[1], edge[2])
			local cell2 = DualContourImpl.getGridCell(edge[3], edge[4])

			table.insert(cachedEdges, cell1[1])
			table.insert(cachedEdges, cell1[2])
			table.insert(cachedEdges, cell2[1])
			table.insert(cachedEdges, cell2[2])
		end

		return Contour.fromEdges(cachedEdges)
	end
end

--- @generic T
--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @param step number
--- @param image T
--- @param sampleFunc RatScratch.Math.IsosurfaceSampleFunc<T>
--- @return number[][]
function DualContour.generate(x1, y1, x2, y2, step, image, sampleFunc)
	DualContourImpl.resizeGrid(x1, y1, x2, y2, step)
	DualContourImpl.resetPointCache()
	DualContourImpl.resetEdgeCache()

	DualContourImpl.generateSamples(x1, y1, x2, y2, step, image, sampleFunc)
	DualContourImpl.generateEdges(x1, y1, x2, y2, step, image, sampleFunc)

	return DualContourImpl.generateContours()
end

return DualContour
