local Common = {}

Common.EPSILON = 0.0001

--- @param from number
--- @param to number
--- @param delta number
--- @return number
function Common.lerp(from, to, delta)
	return from * (1 - delta) + to * delta
end

--- @param from number
--- @param to number
--- @param delta number
--- @return number
function Common.lerpAngles(from, to, delta)
	local difference = (to - from) % (math.pi * 2)
	local distance = (2 * difference) % (math.pi * 2) - difference

	return from + distance * delta
end

--- @param value number
--- @param min number
--- @param max number
--- @return number
function Common.clamp(value, min, max)
	min, max = math.min(min, max), math.max(min, max)
	return math.min(math.max(value, min), max)
end

--- @param value number
--- @return number
function Common.saturate(value)
	return Common.clamp(value, 0, 1)
end

--- @param left number
--- @param right number
--- @return number
function Common.subtractAngles(left, right)
	local difference = left - right
	return (difference + math.pi) % (math.pi * 2) - math.pi
end

--- @param x number
--- @param y number
--- @param angle number
--- @param ox number?
--- @param oy number?
--- @return number, number
function Common.rotate(x, y, angle, ox, oy)
	ox = ox or 0
	oy = oy or 0

	local rx = ox + (x - ox) * math.cos(angle) - (y - oy) * math.sin(angle)
	local ry = oy + (x - ox) * math.sin(angle) + (y - oy) * math.cos(angle)

	return rx, ry
end

--- @param value number
--- @return 1 | -1
function Common.sign(value)
	if value < 0 then
		return -1
	end

	return 1
end

--- @param value number
--- @return 1 | 0 | -1
function Common.zerosign(value)
	if value < 0 then
		return -1
	elseif value > 0 then
		return 1
	end

	return 0
end

--- @param a number
--- @param b number
--- @param E? number
--- @return boolean
function Common.equal(a, b, E)
	E = E or Common.EPSILON

	return math.abs(a - b) < E
end

return Common
