local Common = require("rat-scratch-math.Common")
local Point = {}

--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @return number
function Point.distance(x1, y1, x2, y2)
	local dx = x1 - x2
	local dy = y1 - y2

	return math.sqrt(dx * dx + dy * dy)
end

--- @param x number
--- @param y number
--- @return number
function Point.length(x, y)
	local lengthSquared = x * x + y * y
	if lengthSquared == 0 then
		return 0
	end

	return math.sqrt(lengthSquared)
end

--- @param x number
--- @param y number
--- @return number, number
function Point.normal(x, y)
	local length = Point.length(x, y)
	if length == 0 then
		return 0, 0
	end

	local d = 1 / length
	return x * d, y * d
end

function Point.direction(fromX, fromY, toX, toY)
	return toX - fromX, toY - fromY
end

function Point.directionNormal(fromX, fromY, toX, toY)
	return Point.normal(Point.direction(fromX, fromY, toX, toY))
end

--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @return number
function Point.dot(x1, y1, x2, y2)
	return x1 * x2 + y1 * y2
end

--- @param ax number
--- @param ay number
--- @param bx number
--- @param by number
--- @return number
function Point.cross(ax, ay, bx, by)
	return ax * by - ay * bx
end

--- @param x number
--- @param y number
--- @return number, number
function Point.right(x, y)
	return y, -x
end

--- @param x number
--- @param y number
--- @return number, number
function Point.left(x, y)
	return -y, x
end

--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @return -1 | 0 | 1
function Point.compare(x1, y1, x2, y2, E)
	local s = y1 - y2
	if Common.equal(s, 0, E) then
		local t = x1 - x2
		if Common.equal(t, 0, E) then
			return 0
		end

		return Common.sign(t)
	end

	return Common.sign(s)
end

--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @return boolean
function Point.less(x1, y1, x2, y2)
	return Point.compare(x1, y1, x2, y2) < 0
end

return Point
