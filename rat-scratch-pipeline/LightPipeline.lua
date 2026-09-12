local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local Pipeline = require("rat-scratch-pipeline.impl.Pipeline")
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local CameraFrame = require("rat-scratch-pipeline.CameraFrame")
local Draw = require("rat-scratch-pipeline.Draw")
local Light = require("rat-scratch-pipeline.Light")
local LightEvent = require("rat-scratch-pipeline.LightEvent")
local PipelineMultiBuffer =
	require("rat-scratch-pipeline.Buffer.PipelineMultiBuffer")
local PointLight = require("rat-scratch-pipeline.PointLight")
local Transform = require("rat-scratch-math").Transform

--- @class RatScratch.Pipeline.LightPipeline : RatScratch.Pipeline.impl.Pipeline
--- @field private lights table<RatScratch.Pipeline.Light, true>
--- @field private shadowCastingLights table<RatScratch.Pipeline.Light, true>
--- @field private dirtyLights table<RatScratch.Pipeline.Light, true>
--- @field private lightsBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Light>
--- @field private lightData number[]
--- @field private camerasBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Camera>
--- @field private cameras table<RatScratch.Pipeline.Camera, RatScratch.Pipeline.CameraFrame>
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.LightPipeline
local LightPipeline = Object(Pipeline)

LightPipeline.DEFAULT_LIGHTS_COUNT = 1024
LightPipeline.DEFAULT_CAMERA_COUNT = 64

--- @param pipelineRuntime RatScratch.Pipeline.PipelineRuntime
function LightPipeline:new(pipelineRuntime)
	Pipeline.new(self, pipelineRuntime)

	self.lights = {}
	self.shadowCastingLights = {}
	self.dirtyLights = {}

	self.lightsBuffer = PipelineBuffer(
		Light.LIGHT_FORMAT,
		{ shaderstorage = true },
		LightPipeline.DEFAULT_LIGHTS_COUNT
	)

	self.lightData =
		Table.new(Light.LIGHT_FORMAT_INSTANCE:getComponentCount(), 0)
	BufferFormat.resetValue(Light.LIGHT_FORMAT_INSTANCE, self.lightData)

	self.camerasBuffer = PipelineBuffer(
		CameraFrame.CAMERA_FORMAT,
		{ shaderstorage = true },
		LightPipeline.DEFAULT_CAMERA_COUNT
	)

	self.cameras = setmetatable({}, { __mode = "k" })
end

--- @param light RatScratch.Pipeline.Light
function LightPipeline:addLight(light)
	assert(not self.lights[light], "light already exists in light pipeline")

	self.lightsBuffer:register(light, 1)

	light:listen(LightEvent.UPDATE, self._onLightUpdate, self)

	self.lights[light] = true
	self.shadowCastingLights[light] = nil
	self.dirtyLights[light] = true
end

--- @param light RatScratch.Pipeline.Light
function LightPipeline:removeLight(light)
	assert(self.lights[light], "light not in light pipeline")

	self.lightsBuffer:unregister(light)

	if self.camerasBuffer:has(light) then
		self.camerasBuffer:unregister(light)
	end

	self.lights[light] = nil
	self.shadowCastingLights[light] = nil
	self.dirtyLights[light] = nil
end

--- @private
--- @param event RatScratch.Pipeline.LightEvent
--- @param light RatScratch.Pipeline.Light
function LightPipeline:_onLightUpdate(event, light)
	local isShadowCastingLight = self.shadowCastingLights[light] ~= nil

	if isShadowCastingLight ~= light:getIsShadowCaster() then
		if light:getIsShadowCaster() then
			self:_addShadowCastingLight(light)
		else
			if self.camerasBuffer:has(light) then
				self.camerasBuffer:unregister(light)
			end

			self.shadowCastingLights[light] = nil
		end
	end

	self.dirtyLights[light] = true
end

--- @private
--- @param light RatScratch.Pipeline.Light
function LightPipeline:_addShadowCastingLight(light)
	self.camerasBuffer:registerOrResize(light, light:getCameraCount())
	self.shadowCastingLights[light] = true
end

--- @private
--- @param light RatScratch.Pipeline.Light
function LightPipeline:_flushShadowCastingLight(light)
	local count = light:getCameraCount()

	for i = 1, count do
		local camera = light:getCamera(i)
		local cameraFrame = self.cameras[camera]
		if not cameraFrame then
			cameraFrame = CameraFrame(camera)
			self.cameras[camera] = cameraFrame
		end

		cameraFrame:update()
		self.camerasBuffer:copyTable(light, cameraFrame:getData(), i, 1)
	end
end

--- @private
--- @param light RatScratch.Pipeline.Light
function LightPipeline:_flushLight(light)
	light:toData(self.lightData)

	self.lightsBuffer:copyTable(light, self.lightData, 1, 1)

	if self.shadowCastingLights[light] then
		self:_flushShadowCastingLight(light)
	end
end

--- @private
function LightPipeline:_flushLights()
	for light in pairs(self.dirtyLights) do
		self:_flushLight(light)
		self.dirtyLights[light] = true
	end
end

function LightPipeline:flush()
	if next(self.dirtyLights) then
		self.camerasBuffer:compact()
		self.lightsBuffer:compact()

		self:_flushLights()

		self.camerasBuffer:flush()
		self.lightsBuffer:flush()
	end
end

function LightPipeline:loadDefaultShaders()
	self.clusterShader = self:getPipelineRuntime()
		:loadComputeShader("@Pipeline/Lights/Cluster.lua")
end

function LightPipeline:update()
	self:_clusterLights()
end

return LightPipeline
