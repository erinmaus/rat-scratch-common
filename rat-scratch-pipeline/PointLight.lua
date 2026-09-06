local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-math").Vector3
local Light = require("rat-scratch-pipeline.Light")

--- @class RatScratch.Pipeline.PointLight : RatScratch.Pipeline.Light
--- @field position RatScratch.Math.Vector3
--- @overload fun(): RatScratch.Pipeline.PointLight
local PointLight = Object(Light)

function PointLight:new()
	Light.new(self)

	self.position = Vector3(0)
	self.attenuation = 0
end

function PointLight:getAttenuation()
	return self.attenuation
end

--- @param value number
function PointLight:setAttenuation(value)
	self.attenuation = value
	self:dirty()
end

--- @return RatScratch.Math.Vector3
function PointLight:getPosition()
	return self.position
end

--- @param value RatScratch.Math.Vector3
function PointLight:setPosition(value)
	self.position:from(value:get())
	self:dirty()
end

return PointLight
