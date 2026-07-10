local Object = require("rat-scratch-common").Object
local Common = require("rat-scratch-math").Common
local Random = require("rat-scratch-dungeon.Random")

--- @class RatScratch.Dungeon.LOVERandom : RatScratch.Dungeon.Random
--- @overload fun(low?: integer, high?: integer): RatScratch.Dungeon.LOVERandom
local LOVERandom = Object(Random)

function LOVERandom:new(low, high)
	if low and high then
		self.rng = love.math.newRandomGenerator(low, high)
	elseif low then
		self.rng = love.math.newRandomGenerator(low)
	else
		self.rng = love.math.newRandomGenerator()
	end
end

--- @param minEdge integer
--- @param maxEdge integer
--- @return integer
function LOVERandom:rollEdge(minEdge, maxEdge)
	return self.rng:random(minEdge, maxEdge)
end

--- @param minAngle number
--- @param maxAngle number
--- @return number
function LOVERandom:rollAngle(minAngle, maxAngle)
	return Common.lerpAngles(minAngle, maxAngle, self.rng:random())
end

--- @return number
function LOVERandom:rollEdgeDelta()
	return self.rng:random()
end

return LOVERandom
