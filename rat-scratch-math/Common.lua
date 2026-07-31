local bit = require("bit")

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

--- @param value number
function Common.wrapAngle(value)
	return value % (math.pi * 2)
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
--- @param E number?
--- @return 1 | -1
function Common.sign(value, E)
	E = E or Common.EPSILON

	if Common.lessThan(value, 0, E) then
		return -1
	end

	return 1
end

--- @param value number
--- @param E number?
--- @return 1 | 0 | -1
function Common.zerosign(value, E)
	E = E or Common.EPSILON
	if Common.equal(value, 0, E) then
		return 0
	end

	if value < 0 then
		return -1
	end

	return 1
end

function Common.lessThan(a, b, E)
	E = E or Common.EPSILON
	return a + E < b
end

function Common.lessThanEqual(a, b, E)
	E = E or Common.EPSILON
	return Common.lessThan(a, b, E) or Common.equal(a, b, E)
end

function Common.greaterThan(a, b, E)
	E = E or Common.EPSILON
	return a - E > b
end

function Common.greaterThanEqual(a, b, E)
	E = E or Common.EPSILON
	return Common.greaterThan(a, b, E) or Common.equal(a, b, E)
end

--- @param a number
--- @param b number
--- @param E? number
--- @return boolean
function Common.equal(a, b, E)
	E = E or Common.EPSILON
	return math.abs(a - b) < E
end

--- @param value number
--- @return integer
function Common.round(value)
	return math.floor(value + 0.5)
end

--- @param value integer
--- @return integer
function Common.nextPowerOfTwo(value)
	value = math.floor(value)

	if value <= 1 then
		return 1
	end

	value = value - 1
	value = bit.bor(
		value,
		bit.rshift(value, 1),
		bit.rshift(value, 2),
		bit.rshift(value, 4),
		bit.rshift(value, 8),
		bit.rshift(value, 16)
	)
	return value + 1
end

return Common
