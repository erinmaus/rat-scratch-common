local Common = require "rat-scratch-math.Common"
local Point  = require "rat-scratch-math.Geometry2D.Point"

--- @alias RatScratch.Math.IsosurfaceSampleFunc fun<T>(image: T, x: number, y: number): number, boolean

local Isosurface = {}

--- @param a number
--- @param b number
--- @return boolean
function Isosurface.didCross(a, b)
	return Common.sign(a) ~= Common.sign(b)
end

--- @param a number
--- @param b number
--- @return number
function Isosurface.calculateDelta(a, b)
	if Common.equal(a, b) then
		return 0.5
	else
		return Common.saturate(-a / (b - a))
	end
end

--- @generic T
--- @param x number
--- @param y number
--- @param image T
--- @param sampleFunc RatScratch.Math.IsosurfaceSampleFunc<T>
function Isosurface.calculateGradient(x, y, image, sampleFunc)
	local dx = sampleFunc(image, x + Common.EPSILON, y)
		- sampleFunc(image, x - Common.EPSILON, y)
	local dy = sampleFunc(image, x, y + Common.EPSILON)
		- sampleFunc(image, x, y - Common.EPSILON)
	dx, dy = Point.normal(dx, dy)

	return dx, dy
end

return Isosurface
