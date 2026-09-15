local Object = require("rat-scratch-common").Object
local Light = require("rat-scratch-pipeline.Light")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat

--- @class RatScratch.Pipeline.AmbientLight : RatScratch.Pipeline.Light
--- @field private ambience number
--- @overload fun(): RatScratch.Pipeline.AmbientLight
local AmbientLight = Object(Light)

function AmbientLight:new()
	Light.new(self)

	self.ambience = 1
end

--- @param data number[]
--- @param offset? integer
function AmbientLight:toData(data, offset)
	Light.toData(self, data, offset)

	BufferFormat.setValue(
		Light.LIGHT_FORMAT_INSTANCE,
		data,
		"position",
		offset,
		0,
		0,
		0,
		-1
	)

	BufferFormat.setValue(
		Light.LIGHT_FORMAT_INSTANCE,
		data,
		"attenuation",
		offset,
		self.ambience,
		0
	)
end

function AmbientLight:getAmbience()
	return self.ambience
end

function AmbientLight:setAmbience(value)
	self.ambience = value
	self:dirty()
end

return AmbientLight
