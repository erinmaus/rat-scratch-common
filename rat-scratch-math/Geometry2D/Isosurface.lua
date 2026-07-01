local Common = require("rat-scratch-math.Common")
local Point = require("rat-scratch-math.Geometry2D.Point")

--- @alias RatScratch.Math.IsosurfaceSampleFunc fun<T, U>(image: T, x: number, y: number): number, boolean, U?

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

--- @generic T
--- @param contours number[][]
--- @param image T
--- @param sampleFunc RatScratch.Math.IsosurfaceSampleFunc<T>
function Isosurface.sampleUserdata(contours, image, sampleFunc)
	local contoursUserdata = {}

	for _, contour in ipairs(contours) do
		local contourUserdata = {}
		for i = 1, #contour, 2 do
			local x, y = contour[i], contour[i + 1]

			local _, _, userdata = sampleFunc(image, x, y)
			table.insert(contourUserdata, userdata)
		end

		table.insert(contoursUserdata, contourUserdata)
	end

	return contoursUserdata
end

return Isosurface
