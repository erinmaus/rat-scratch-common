local Object = require("rat-scratch-common").Object
local Common = require("rat-scratch-math").Common

--- @class RatScratch.Dungeon.Random : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Dungeon.Random
local Random = Object()

--- @param minEdge integer
--- @param maxEdge integer
--- @return integer
function Random:rollEdge(minEdge, maxEdge)
	return love.math.random(minEdge, maxEdge)
end

--- @param minAngle number
--- @param maxAngle number
--- @return number
function Random:rollAngle(minAngle, maxAngle)
	return Common.lerpAngles(minAngle, maxAngle, love.math.random())
end

--- @return number
function Random:rollEdgeDelta()
	return love.math.random()
end

return Random
