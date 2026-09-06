local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-math").Vector3
local Light = require("rat-scratch-pipeline.Light")

--- @class RatScratch.Pipeline.DirectionalLight : RatScratch.Pipeline.Light
--- @field direction RatScratch.Math.Vector3
--- @overload fun(): RatScratch.Pipeline.DirectionalLight
local DirectionalLight = Object(Light)

function DirectionalLight:new()
	Light.new(self)

	self.direction = Vector3(0, 1, 0)
end

--- @return RatScratch.Math.Vector3
function DirectionalLight:getDirection()
	return self.direction
end

--- @param value RatScratch.Math.Vector3
function DirectionalLight:setDirection(value)
	self.direction:from(value:get()):normalize(self.direction)
	self:dirty()
end

return DirectionalLight
