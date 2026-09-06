local Object = require("rat-scratch-common").Object
local Light = require("rat-scratch-pipeline.Light")

--- @class RatScratch.Pipeline.AmbientLight : RatScratch.Pipeline.Light
--- @field private ambience number
--- @overload fun(): RatScratch.Pipeline.AmbientLight
local AmbientLight = Object(Light)

function AmbientLight:new()
	Light.new(self)

	self.ambience = 1
end

function AmbientLight:getAmbience()
	return self.ambience
end

function AmbientLight:setAmbience(value)
	self.ambience = value
	self:dirty()
end

return AmbientLight
