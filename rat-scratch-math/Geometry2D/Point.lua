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
function Point.left(x, y)
	return y, -x
end

--- @param x number
--- @param y number
--- @return number, number
function Point.right(x, y)
	return -y, x
end

return Point
