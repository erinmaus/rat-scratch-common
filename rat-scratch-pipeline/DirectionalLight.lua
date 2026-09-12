local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-math").Vector3
local Light = require("rat-scratch-pipeline.Light")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Pack = require("rat-scratch-pipeline.Utility.Pack")

--- @class RatScratch.Pipeline.DirectionalLight : RatScratch.Pipeline.Light
--- @field direction RatScratch.Math.Vector3
--- @overload fun(): RatScratch.Pipeline.DirectionalLight
local DirectionalLight = Object(Light)

function DirectionalLight:new()
	Light.new(self)

	self.direction = Vector3(0, 1, 0)
end

--- @param data number[]
--- @param offset? integer
function DirectionalLight:toData(data, offset)
	Light.toData(self, data, offset)

	BufferFormat.setValue(
		Light.LIGHT_FORMAT_INSTANCE,
		data,
		"direction",
		offset,
		Pack.encodeNormal(self.direction:get())
	)

	BufferFormat.setValue(
		Light.LIGHT_FORMAT_INSTANCE,
		data,
		"position",
		offset,
		0,
		0,
		0,
		1
	)
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
