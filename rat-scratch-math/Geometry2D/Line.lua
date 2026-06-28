local Common = require("rat-scratch-math.Common")

local Line = {}
local LineImpl = {}

--- @private
--- @param px number
--- @param py number
--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @return number
function Line.pointDistanceSquaredFromLineSegment(px, py, x1, y1, x2, y2)
	local dx = x2 - x1
	local dy = y2 - y1

	local distanceSquared = (dx * dx) + (dy * dy)
	if distanceSquared < Common.EPSILON then
		return 0
	end

	local pdx1 = px - x1
	local pdy1 = py - y1

	local dot = pdx1 * dx + pdy1 * dy

	local s = dot / distanceSquared
	local t = math.min(math.max(s, 0), 1)

	local tx = t * dx + x1
	local ty = t * dy + y1

	local rx = px - tx
	local ry = py - ty

	return (rx * rx) + (ry * ry)
end

--- @param px number
--- @param py number
--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @return number
function Line.pointDistanceFromLineSegment(px, py, x1, y1, x2, y2)
	return math.sqrt(
		Line.pointDistanceSquaredFromLineSegment(px, py, x1, y1, x2, y2)
	)
end

--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @return number, number
--- @private
function Line.getNormal(x1, y1, x2, y2)
	local dx = x2 - x1
	local dy = y2 - y1

	local distanceSquared = (dx * dx) + (dy * dy)
	if distanceSquared < Common.EPSILON then
		return 0, 0
	end

	local distance = math.sqrt(distanceSquared)
	return dx / distance, dy / distance
end

--- @param ax number
--- @param ay number
--- @param bx number
--- @param by number
--- @param cx number
--- @param cy number
--- @return number
function Line.direction(ax, ay, bx, by, cx, cy)
	local left = (ay - cy) * (bx - cx)
	local right = (ax - cx) * (by - cy)
	return left - right
end

--- @param ax number
--- @param ay number
--- @param bx number
--- @param by number
--- @param px number
--- @param py number
--- @return -1 | 0 | 1
function Line.sideOfLineSegment(ax, ay, bx, by, px, py)
	local side = Line.direction(ax, ay, bx, by, px, py)

	if side < 0 then
		return -1
	elseif side > 0 then
		return 1
	end

	return 0
end

--- @param a number
--- @param b number
--- @param c number
--- @param d number
--- @return boolean
--- @private
function LineImpl._isCollinear(a, b, c, d)
	local abl = math.min(a, b)
	local abh = math.max(a, b)

	local cdl = math.min(c, d)
	local cdh = math.max(c, d)

	if cdh < abl or abh < cdl then
		return false
	end

	return true
end

--- @param ax number
--- @param ay number
--- @param bx number
--- @param by number
--- @param cx number
--- @param cy number
--- @param dx number
--- @param dy number
--- @return boolean
function Line.isCollinear(ax, ay, bx, by, cx, cy, dx, dy)
	local acdSign = Line.sideOfLineSegment(ax, ay, cx, cy, dx, dy)
	local bcdSign = Line.sideOfLineSegment(bx, by, cx, cy, dx, dy)
	local cabSign = Line.sideOfLineSegment(cx, cy, ax, ay, bx, by)
	local dabSign = Line.sideOfLineSegment(dx, dy, ax, ay, bx, by)

	if acdSign == 0 and bcdSign == 0 and cabSign == 0 and dabSign == 0 then
		return LineImpl._isCollinear(ax, bx, cx, dx)
			and LineImpl._isCollinear(ay, by, cy, dy)
	end

	return false
end

--- @param ax number
--- @param ay number
--- @param bx number
--- @param by number
--- @param cx number
--- @param cy number
--- @param dx number
--- @param dy number
--- @return boolean, number?, number?, number?, number?
function Line.intersection(ax, ay, bx, by, cx, cy, dx, dy)
	local acdSign = Line.sideOfLineSegment(ax, ay, cx, cy, dx, dy)
	local bcdSign = Line.sideOfLineSegment(bx, by, cx, cy, dx, dy)
	local cabSign = Line.sideOfLineSegment(cx, cy, ax, ay, bx, by)
	local dabSign = Line.sideOfLineSegment(dx, dy, ax, ay, bx, by)

	if acdSign == 0 and bcdSign == 0 and cabSign == 0 and dabSign == 0 then
		return Line.isCollinear(ax, ay, bx, by, cx, cy, dx, dy)
	end

	local bax = bx - ax
	local bay = by - ay
	local dcx = dx - cx
	local dcy = dy - cy

	local baCrossDC = bax * dcy - bay * dcx
	local dcCrossBA = dcx * bay - dcy * bax
	if baCrossDC == 0 or dcCrossBA == 0 then
		return false
	end

	local acx = ax - cx
	local acy = ay - cy
	local cax = cx - ax
	local cay = cy - ay

	local dcCrossAC = dcx * acy - dcy * acx
	local baCrossCA = bax * cay - bay * cax

	local u = dcCrossAC / baCrossDC
	local v = baCrossCA / dcCrossBA

	local rx = ax + bax * u
	local ry = ay + bay * u

	if u < 0 or u > 1 or v < 0 or v > 1 then
		return false, rx, ry, u, v
	end

	return true, rx, ry, u, v
end

return Line
