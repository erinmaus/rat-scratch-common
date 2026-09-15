local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-math").Vector3
local Common = require("rat-scratch-math").Common
local Light = require("rat-scratch-pipeline.Light")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Pack = require("rat-scratch-pipeline.Utility.Pack")

--- @class RatScratch.Pipeline.SpotLight : RatScratch.Pipeline.Light
--- @field position RatScratch.Math.Vector3
--- @field direction RatScratch.Math.Vector3
--- @field attenuation number
--- @field cutoff number
--- @overload fun(): RatScratch.Pipeline.SpotLight
local SpotLight = Object(Light)

function SpotLight:new()
	Light.new(self)

	self.position = Vector3(0)
	self.direction = Vector3(0, 0, 1)
	self.attenuation = 0
	self.cutoff = 0
end

--- @param data number[]
--- @param offset? integer
function SpotLight:toData(data, offset)
	Light.toData(self, data, offset)

	BufferFormat.setValue(
		Light.LIGHT_FORMAT_INSTANCE,
		data,
		"direction",
		offset,
		Pack.encodeNormal(self.direction:get())
	)

	local x, y, z = self.position:get()

	BufferFormat.setValue(
		Light.LIGHT_FORMAT_INSTANCE,
		data,
		"position",
		offset,
		x,
		y,
		z,
		0
	)

	BufferFormat.setValue(
		Light.LIGHT_FORMAT_INSTANCE,
		data,
		"attenuation",
		offset,
		self.attenuation,
		math.cos(self.cutoff)
	)
end

--- @return number
function SpotLight:getAttenuation()
	return self.attenuation
end

--- @param value number
function SpotLight:setAttenuation(value)
	self.attenuation = value
	self:dirty()
end

--- @return number
function SpotLight:getCutoff()
	return self.cutoff
end

--- @param value number
function SpotLight:setCutoff(value)
	self.cutoff = Common.wrapAngle(value)
	self:dirty()
end

--- @return RatScratch.Math.Vector3
function SpotLight:getPosition()
	return self.position
end

--- @param value RatScratch.Math.Vector3
function SpotLight:setPosition(value)
	self.position:from(value:get())
	self:dirty()
end

--- @return RatScratch.Math.Vector3
function SpotLight:getDirection()
	return self.direction
end

--- @param value RatScratch.Math.Vector3
function SpotLight:setDirection(value)
	self.direction:from(value:get()):normalize(self.direction)
	self:dirty()
end

return SpotLight
