local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-math").Vector3
local Light = require("rat-scratch-pipeline.Light")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat

--- @class RatScratch.Pipeline.PointLight : RatScratch.Pipeline.Light
--- @field position RatScratch.Math.Vector3
--- @overload fun(): RatScratch.Pipeline.PointLight
local PointLight = Object(Light)

function PointLight:new()
	Light.new(self)

	self.position = Vector3(0)
	self.attenuation = 0
end

--- @param data number[]
--- @param offset? integer
function PointLight:toData(data, offset)
	Light.toData(self, data, offset)

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
		-1
	)
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

function PointLight:getCameraCount()
	return 6
end

--- @param index integer
--- @return RatScratch.Pipeline.Camera
function PointLight:getCamera(index)
	-- TODO
end

return PointLight
