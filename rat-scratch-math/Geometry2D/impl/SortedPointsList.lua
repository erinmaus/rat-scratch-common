local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Search = require("rat-scratch-common").Search
local Table = require("rat-scratch-common").Table
local Point = require("rat-scratch-math.Geometry2D.Point")
local PointsCache = require("rat-scratch-math.Geometry2D.impl.PointsCache")

--- @class RatScratch.Math.Geometry2D.impl.SortedPointsList : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Math.Geometry2D.impl.SortedPointsList
--- @field private points number[][]
--- @field private cache RatScratch.Math.Geometry2D.impl.PointsCache
local SortedPointsList = Object()

function SortedPointsList:new()
	self.points = {}
	self.cache = PointsCache()
end

--- @param a number[]
--- @param b number[]
--- @return boolean
function SortedPointsList.less(a, b)
	return Point.less(a[1], a[2], b[1], b[2])
end

--- @param a number[]
--- @param b number[]
--- @return -1 | 0 |1
function SortedPointsList.compare(a, b)
	return Point.compare(a[1], a[2], b[1], b[2])
end

--- @param point number[]
--- @return number[]
function SortedPointsList:get(point)
	local index = Search.first(self.points, point, SortedPointsList.compare)
	assert(
		index and index >= 1 and index <= #self.points,
		"point (%f, %f) not is point cache",
		point[1],
		point[2]
	)

	return self.points[index]
end

--- @overload fun(self: RatScratch.Math.Geometry2D.impl.SortedPointsList, x: number, y: number)
--- @overload fun(self: RatScratch.Math.Geometry2D.impl.SortedPointsList, point: number[])
function SortedPointsList:add(a, b)
	local point
	if a and b then
		point = self.cache:get(a, b)
	else
		--- @cast a number[]
		point = a
	end

	local index =
		Search.lessThanEqual(self.points, point, SortedPointsList.compare)

	if
		index <= 0
		or index > #self.points
		or SortedPointsList.compare(point, self.points[index]) ~= 0
	then
		table.insert(self.points, index + 1, point)
		return self.points[index + 1]
	end

	return self.points[index]
end

function SortedPointsList:reset()
	Table.clear(self.points)
	self.cache:reset()
end

function SortedPointsList:getPoints()
	return self.points
end

return SortedPointsList
