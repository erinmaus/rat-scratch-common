local Object = require("rat-scratch-common").Object
local CameraFrame = require("rat-scratch-pipeline.CameraFrame")
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local Table = require("rat-scratch-common.Table")

--- @generic T
--- @class RatScratch.Pipeline.CameraBuffer<T> : RatScratch.Common.BaseObject
--- @field private cameraData table<RatScratch.Pipeline.Camera, RatScratch.Pipeline.CameraFrame>
--- @field private instanceToCamera table<T, (RatScratch.Pipeline.Camera | false)[]>
--- @field private instanceByIndex T[]
--- @field private activeCameraInstances table<T, true>
--- @field private activeCamerasByIndex RatScratch.Pipeline.Camera[]
--- @field private cameraDataByIndex RatScratch.Pipeline.CameraFrame[]
--- @field private camerasBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<T>
--- @field private activeCameraBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Camera>
--- @field private camerasDirty boolean
--- @field private activeCamerasDirty boolean
--- @overload fun(): RatScratch.Pipeline.CameraBuffer
local CameraBuffer = Object()

CameraBuffer.ACTIVE_CAMERA_FORMAT = {
	{ location = 0, name = "index", format = "uint32" },
}

CameraBuffer.DEFAULT_CAMERA_COUNT = 64

function CameraBuffer:new()
	self.instanceToCamera = {}
	self.instanceByIndex = {}
	self.cameraData = {}
	self.cameraDataByIndex = {}

	self.activeCameraInstances = {}
	self.activeCamerasByIndex = {}

	self.cameraBuffer = PipelineBuffer(
		CameraFrame.CAMERA_FORMAT,
		{ shaderstorage = true },
		CameraBuffer.DEFAULT_CAMERA_COUNT
	)

	self.activeCameraBuffer = PipelineBuffer(
		CameraBuffer.ACTIVE_CAMERA_FORMAT,
		{ shaderstorage = true },
		CameraBuffer.DEFAULT_CAMERA_COUNT
	)

	self.activeCamerasDirty = false
	self.camerasDirty = false
end

--- @param shader love.Shader
function CameraBuffer:bind(shader)
	if shader:hasUniform("rat_ActiveCameraCount") then
		shader:send("rat_ActiveCameraCount", self:getActiveCameraCount())
	end

	if shader:hasUniform("rat_ActiveCamerasBuffer") then
		shader:send(
			"rat_ActiveCamerasBuffer",
			self.activeCameraBuffer:getBuffer()
		)
	end

	if shader:hasUniform("rat_CamerasBuffer") then
		shader:send("rat_CamerasBuffer", self.cameraBuffer:getBuffer())
	end
end

--- @generic T
--- @param self RatScratch.Pipeline.CameraBuffer<T>
--- @param instance T
--- @return boolean
function CameraBuffer:has(instance)
	return self.instanceToCamera[instance] ~= nil
end

--- @generic T
--- @param self RatScratch.Pipeline.CameraBuffer<T>
--- @param instance T
--- @param cameraCount integer
function CameraBuffer:registerOrResize(instance, cameraCount)
	if self.instanceToCamera[instance] then
		for i = 1, cameraCount do
			self.instanceToCamera[instance][i] = self.instanceToCamera[instance][i]
				or false
		end

		for i = cameraCount + 1, #self.instanceToCamera[instance] do
			local camera = self.instanceToCamera[instance][i]
			if camera and self.activeCameraBuffer:has(camera) then
				self.activeCameraBuffer:unregister(camera)
				Table.remove(self.activeCamerasByIndex, camera)

				local frame = self.cameraData[camera]
				self.cameraData[camera] = nil
				Table.remove(self.cameraDataByIndex, frame)
			end

			self.instanceToCamera[instance][i] = nil
		end
	else
		self:register(instance, cameraCount)
	end
end

--- @generic T
--- @param self RatScratch.Pipeline.CameraBuffer<T>
--- @param instance T
--- @param cameraCount integer
function CameraBuffer:register(instance, cameraCount)
	assert(
		not self.instanceToCamera[instance],
		"instance already registered in camera buffer"
	)

	self.instanceToCamera[instance] = {}
	for i = 1, cameraCount do
		self.instanceToCamera[instance][i] = false
	end

	table.insert(self.instanceByIndex, instance)

	self.cameraBuffer:register(instance, cameraCount)
	self.camerasDirty = true
end

--- @generic T
--- @param self RatScratch.Pipeline.CameraBuffer<T>
--- @param instance T
function CameraBuffer:unregister(instance)
	assert(
		self.instanceToCamera[instance],
		"instance not registered in camera buffer"
	)

	self:deactivate(instance)

	for _, camera in ipairs(self.instanceToCamera[instance]) do
		if camera then
			local frame = self.cameraData[camera]

			self.cameraData[camera] = nil
			Table.remove(self.cameraDataByIndex, frame)

			if self.activeCameraBuffer:has(camera) then
				self.activeCameraBuffer:unregister(camera)
			end
		end
	end

	self.instanceToCamera[instance] = nil
	Table.remove(self.instanceByIndex, instance)
	self.cameraBuffer:unregister(instance)

	self.camerasDirty = true
end

--- @generic T
--- @param self RatScratch.Pipeline.CameraBuffer<T>
--- @param instance T
--- @param index integer
--- @param camera RatScratch.Pipeline.Camera
function CameraBuffer:set(instance, index, camera)
	assert(not self.cameraData[camera], "camera exists in buffer")

	local frame = CameraFrame(camera)
	self.cameraData[camera] = frame
	table.insert(self.cameraDataByIndex, frame)

	self.instanceToCamera[instance][index] = camera
end

--- @generic T
--- @param self RatScratch.Pipeline.CameraBuffer<T>
--- @param instance T
function CameraBuffer:activate(instance)
	assert(self.instanceToCamera[instance], "instance does not exist in buffer")

	if self.activeCameraInstances[instance] then
		return
	end

	for i, camera in ipairs(self.instanceToCamera[instance]) do
		assert(camera, "instance missing camera at index %d", i)

		self.activeCameraBuffer:register(camera, 1)
		table.insert(self.activeCamerasByIndex, camera)
	end

	self.activeCameraInstances[instance] = true
end

--- @generic T
--- @param self RatScratch.Pipeline.CameraBuffer<T>
--- @param instance T
function CameraBuffer:deactivate(instance)
	assert(self.instanceToCamera[instance], "instance does not exist in buffer")

	if not self.activeCameraInstances[instance] then
		return
	end

	for i, camera in ipairs(self.instanceToCamera[instance]) do
		assert(camera, "instance missing camera at index %d", i)

		self.activeCameraBuffer:unregister(camera)
		Table.remove(self.activeCamerasByIndex, camera)
	end

	self.activeCameraInstances[instance] = nil

	self.activeCamerasDirty = true
end

function CameraBuffer:getCameraBuffer()
	return self.cameraBuffer
end

function CameraBuffer:getActiveCameraBuffer()
	return self.activeCameraBuffer
end

function CameraBuffer:getCameraCount()
	local _, c = self.cameraBuffer:getIndexCount()
	return c
end

--- @return integer
function CameraBuffer:getActiveCameraCount()
	local _, c = self.activeCameraBuffer:getIndexCount()
	return c
end

function CameraBuffer:update()
	for _, instance in ipairs(self.instanceByIndex) do
		local cameras = self.instanceToCamera[instance]
		for i, camera in ipairs(cameras) do
			if camera then
				local frame = self.cameraData[camera]
				frame:update()

				self.cameraBuffer:copyTable(instance, frame:getData(), i, 1)
			end
		end
	end

	self.cameraBuffer:flush()
end

function CameraBuffer:flush()
	if self.camerasDirty or self.activeCamerasDirty then
		if self.camerasDirty then
			self.cameraBuffer:compact()
			self.camerasDirty = false
		end

		for instance in pairs(self.activeCameraInstances) do
			local index = self.cameraBuffer:getIndexCount(instance)
			for i, camera in ipairs(self.activeCamerasByIndex) do
				self.activeCameraBuffer:set(camera, 1, 1, (index - 1) + (i - 1))
			end
		end

		self.activeCameraBuffer:compact()
		self.activeCameraBuffer:flush()

		self.activeCamerasDirty = false
	end
end

return CameraBuffer
