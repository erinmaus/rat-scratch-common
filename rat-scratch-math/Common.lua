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

return Common
