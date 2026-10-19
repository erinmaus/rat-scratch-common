local Object = require("rat-scratch-common").Object
local EventSource = require("rat-scratch-common").EventSource
local Vector3 = require("rat-scratch-math").Vector3
local Quaternion = require("rat-scratch-math").Quaternion
local CubeMap = require("rat-scratch-graphics").CubeMap
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local ArcballCameraView = require("rat-scratch-pipeline.ArcballCameraView")
local Camera = require("rat-scratch-pipeline.Camera")
local PerspectiveFOVCameraProjection =
	require("rat-scratch-pipeline.PerspectiveFOVCameraProjection")
local ReflectionProbeEvent =
	require("rat-scratch-pipeline.ReflectionProbeEvent")

--- @class RatScratch.Pipeline.ReflectionProbe : RatScratch.Common.BaseObject
--- @field private data number[]
--- @field private perspective RatScratch.Pipeline.PerspectiveFOVCameraProjection
--- @field private cameras RatScratch.Pipeline.Camera<RatScratch.Pipeline.PerspectiveFOVCameraProjection, RatScratch.Pipeline.ArcballCameraView>[]
--- @field private position RatScratch.Math.Vector3
--- @field private isStatic boolean
--- @field private isDirty boolean
--- @field private eventSource RatScratch.Common.EventSource<RatScratch.Pipeline.ReflectionProbe>
--- @overload fun(): RatScratch.Pipeline.ReflectionProbe
local ReflectionProbe = Object()

ReflectionProbe.REFLECTION_PROBE_FORMAT = {
	{ location = 0, name = "atlasImageIndexCount", format = "uint32vec2" },
	{ location = 1, name = "positionDistance", format = "floatvec4" },
}

ReflectionProbe.REFLECTION_PROBE_FORMAT_INSTANCE =
	BufferFormat.get(ReflectionProbe.REFLECTION_PROBE_FORMAT)

function ReflectionProbe:new()
	self.data = {}
	BufferFormat.resetValue(ReflectionProbe.REFLECTION_PROBE_FORMAT, self.data)

	self.perspective = PerspectiveFOVCameraProjection()
	self.perspective:setNear(0.001)
	self.perspective:setFar(1)

	self.cameras = {}
	self:_initCameras()

	self.distance = 1
	self.position = Vector3()

	self.isStatic = true
	self.isDirty = false

	self.eventSource = EventSource(self)
end

ReflectionProbe.listen, ReflectionProbe.silence =
	EventSource.mixin("eventSource")

function ReflectionProbe:getData()
	return self.data
end

--- @protected
function ReflectionProbe:getIsDirty()
	return self.isDirty
end

--- @protected
function ReflectionProbe:dirty()
	if not self.isDirty then
		self.isDirty = true
		self.eventSource:process(ReflectionProbeEvent.fromUpdate())
	end
end

--- @param value RatScratch.Math.Vector3
function ReflectionProbe:setPosition(value)
	self.position:from(value:get())

	for _, camera in ipairs(self.cameras) do
		camera:getView():setTranslation(value)
	end

	self:dirty()
end

function ReflectionProbe:getPosition()
	return self.position
end

function ReflectionProbe:getIsStatic()
	return self.isStatic
end

function ReflectionProbe:getIsRealtime()
	return not self.isStatic
end

--- @param value boolean
function ReflectionProbe:setIsStatic(value)
	self.isStatic = value
	self:dirty()
end

--- @param value boolean
function ReflectionProbe:setIsRealtime(value)
	self.isStatic = not value
	self:dirty()
end

function ReflectionProbe:getDistance()
	return self.distance
end

--- @param value number
function ReflectionProbe:setDistance(value)
	self.distance = math.max(value, 1)
	self.perspective:setFar(self.distance)

	self:dirty()
end

function ReflectionProbe:update()
	if self.isDirty then
		local x, y, z = self.position:get()
		local d = self.distance

		BufferFormat.setValue(
			ReflectionProbe.REFLECTION_PROBE_FORMAT_INSTANCE,
			self.data,
			"positionDistance",
			0,
			x,
			y,
			z,
			d
		)

		self.isDirty = false
	end
end

function ReflectionProbe:getCameraCount()
	return #self.cameras
end

function ReflectionProbe:getCamera(index)
	return self.cameras[index]
end

do
	local _rotation = Quaternion()

	--- @private
	function ReflectionProbe:_initCameras()
		local rotation = _rotation
		for i = 1, CubeMap.FACES do
			local view = ArcballCameraView()
			view:setRotation(CubeMap.getRotation(i, rotation))

			local camera = Camera(self.perspective, view)
			table.insert(self.cameras, camera)
		end
	end
end

return ReflectionProbe
