local Common = require("rat-scratch-math.Common")
local Point = require("rat-scratch-math.Geometry2D.Point")
local bit = require("bit")
local Search = require("rat-scratch-common").Search
local Table = require("rat-scratch-common").Table
local Contour = require("rat-scratch-math.Geometry2D.Contour")
local Isosurface = require("rat-scratch-math.Geometry2D.Isosurface")
local SortedPointsList =
	require("rat-scratch-math.Geometry2D.impl.SortedPointsList")

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

do
	local cachedEdges = {
		{ 0, 0 },
		{ 0, 0 },
		{ 0, 0 },
		{ 0, 0 },
	}

	--- @param edge number[]
	--- @param left number
	--- @param top number
	--- @param right number
	--- @param bottom number
	--- @param topLeft number
	--- @param topRight number
	--- @param bottomLeft number
	--- @param bottomRight number
	--- @param points RatScratch.Math.Geometry2D.impl.SortedPointsList
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
		points,
		results
	)
		if #edge == 0 then
			return
		end

		local edges = cachedEdges

		local leftDelta = Isosurface.calculateDelta(topLeft, bottomLeft)
		local topDelta = Isosurface.calculateDelta(topLeft, topRight)
		local rightDelta = Isosurface.calculateDelta(topRight, bottomRight)
		local bottomDelta = Isosurface.calculateDelta(bottomLeft, bottomRight)

		edges[1][1], edges[1][2] = left, Common.lerp(top, bottom, leftDelta)
		edges[2][1], edges[2][2] = Common.lerp(left, right, topDelta), top
		edges[3][1], edges[3][2] = right, Common.lerp(top, bottom, rightDelta)
		edges[4][1], edges[4][2] = Common.lerp(left, right, bottomDelta), bottom

		for i = 1, #edge, 2 do
			local j = i + 1

			local edge1 = edges[edge[i]]
			local edge2 = edges[edge[j]]

			table.insert(results, points:add(edge1[1], edge1[2]))
			table.insert(results, points:add(edge2[1], edge2[2]))
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
	--- @param sampleFunc RatScratch.Math.IsosurfaceSampleFunc<T>
	--- @param points RatScratch.Math.Geometry2D.impl.SortedPointsList
	--- @param results number[][]
	function MarchingSquaresImpl.sample(
		x,
		y,
		step,
		image,
		sampleFunc,
		points,
		results
	)
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
			points,
			results
		)
	end
end

do
	local cachedEdges = {}
	function MarchingSquaresImpl.generateContours(segments)
		Table.clear(cachedEdges)

		for _, segment in ipairs(segments) do
			for _, value in ipairs(segment) do
				table.insert(cachedEdges, value)
			end
		end

		return Contour.fromEdges(cachedEdges)
	end
end

do
	local cachedPoints = SortedPointsList()

	--- @generic T
	--- @param x1 number
	--- @param y1 number
	--- @param x2 number
	--- @param y2 number
	--- @param step number
	--- @param image T
	--- @param sampleFunc RatScratch.Math.IsosurfaceSampleFunc<T>
	--- @return number[][]
	function MarchingSquares.generate(x1, y1, x2, y2, step, image, sampleFunc)
		cachedPoints:reset()

		local result = {}
		for x = x1, x2, step do
			for y = y1, y2, step do
				MarchingSquaresImpl.sample(
					x,
					y,
					step,
					image,
					sampleFunc,
					cachedPoints,
					result
				)
			end
		end

		return MarchingSquaresImpl.generateContours(result)
	end
end

return MarchingSquares
