local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-math").Vector3
local Light = require("rat-scratch-pipeline.Light")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local ArcballCamera = require("rat-scratch-pipeline.ArcballCamera")
local Quaternion = require("rat-scratch-math").Quaternion
local CubeMap = require("rat-scratch-graphics").CubeMap

--- @class RatScratch.Pipeline.PointLight : RatScratch.Pipeline.Light
--- @field position RatScratch.Math.Vector3
--- @field attenuation number
--- @field cameras (RatScratch.Pipeline.ArcballCamera | false)[]
--- @overload fun(): RatScratch.Pipeline.PointLight
local PointLight = Object(Light)

function PointLight:new()
	Light.new(self)

	self.position = Vector3(0)
	self.attenuation = 0
	self.cameras = {
		false,
		false,
		false,
		false,
		false,
		false,
	}
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
	return CubeMap.FACES
end

do
	local _rotation = Quaternion()

	--- @param index integer
	--- @return RatScratch.Pipeline.Camera
	function PointLight:getCamera(index)
		local camera = self.cameras[index]
		if not camera then
			camera = ArcballCamera()
			camera:setRotation(CubeMap.getRotation(index, _rotation))
			self.cameras[index] = camera
		end

		camera:setNear(0.1)
		camera:setFar(math.max(self.attenuation, 1))
		camera:setTranslation(self.position)

		return camera
	end
end

return PointLight
