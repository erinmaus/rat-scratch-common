local Object = require("rat-scratch-common").Object

--- @class RatScratch.Math.Geometry2D.impl.PointsCache : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Math.Geometry2D.impl.PointsCache
--- @field private count integer
--- @field private points number[][]
local PointsCache = Object()

function PointsCache:new()
	self.count = 0
	self.points = {}
end

function PointsCache:reset()
	self.count = 0
end

function PointsCache:get(x, y)
	local i = self.count + 1

	local point = self.points[i]
	if not point then
		point = {}
		self.points[i] = point
	end

	point[1], point[2] = x, y
	self.count = i

	return point
end

return PointsCache
