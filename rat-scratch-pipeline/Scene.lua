local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local CameraFrame = require("rat-scratch-pipeline.CameraFrame")
local DrawPipeline = require("rat-scratch-pipeline.DrawPipeline")
local LightClusterResult = require("rat-scratch-pipeline.LightClusterResult")
local LightPipeline = require("rat-scratch-pipeline.LightPipeline")
local ObjectHandleEvent = require("rat-scratch-pipeline.ObjectHandleEvent")
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local Pipelines = require("rat-scratch-pipeline.Pipelines")

--- @class RatScratch.Pipeline.Scene : RatScratch.Common.BaseObject
--- @field private world RatScratch.Pipeline.World
--- @field private camera RatScratch.Pipeline.Camera
--- @field private cameraFrame RatScratch.Pipeline.CameraFrame
--- @field private camerasBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Camera>
--- @field private objectHandles table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private dirtyObjectHandles table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private lights table<RatScratch.Pipeline.Light, true>
--- @field private lightsByIndex RatScratch.Pipeline.Light[]
--- @field private lightClusterResults RatScratch.Pipeline.LightClusterResult
--- @overload fun(world: RatScratch.Pipeline.World): RatScratch.Pipeline.Scene
local Scene = Object()

--- @param world RatScratch.Pipeline.World
function Scene:new(world)
	self.world = world
	self.objectHandles = {}
	self.dirtyObjectHandles = {}
	self.dirtyObjectHandleDraws = {}

	self.lights = {}
	self.lightsByIndex = {}

	self.pipelines = Pipelines(world:getPipelineRuntime())

	self.camerasBuffer =
		PipelineBuffer(CameraFrame.CAMERA_FORMAT, { shaderstorage = true }, 1)
	self.lightClusterResults = LightClusterResult(self.camerasBuffer)
end

--- @param shader love.Shader
--- @param qualityPreset string
function Scene:bind(shader, qualityPreset)
	if self.camera and shader:hasUniform("rat_CamerasBuffer") then
		shader:send("rat_CamerasBuffer", self.camerasBuffer:getBuffer())

		if
			qualityPreset
				== self.world:getPipelineRuntime():getDefaultQualityPreset()
			and shader:hasUniform("rat_LightCountIndicesBuffer")
		then
			shader:send(
				"rat_LightCountIndicesBuffer",
				self.lightClusterResults:getLightIndicesBuffer()
			)
		end
	end
end

--- @param camera RatScratch.Pipeline.Camera
function Scene:setCamera(camera)
	if self.camera then
		self.camerasBuffer:unregister(self.camera)
	end

	self.camera = camera
	self.cameraFrame = CameraFrame(camera)

	self.camerasBuffer:register(self.camera, 1)
end

function Scene:getCamera()
	return self.camera
end

--- @generic T : RatScratch.Common.BaseObject
--- @param pipelineType T | unknown
--- @return T
function Scene:getPipeline(pipelineType)
	return self.pipelines:get(pipelineType)
end

--- @param object RatScratch.Pipeline.ObjectHandle
function Scene:addObject(object)
	assert(not self.objectHandles[object], "object is in scene")

	self.objectHandles[object] = true
	self.dirtyObjectHandles[object] = true

	object:listen(
		ObjectHandleEvent.DRAW_UPDATED,
		self._onObjectDrawUpdated,
		self
	)

	self.pipelines:get(DrawPipeline):addDrawable(object)
end

--- @private
--- @param event RatScratch.Pipeline.ObjectHandleEvent
--- @param object RatScratch.Pipeline.ObjectHandle
function Scene:_onObjectDrawUpdated(event, object)
	self.dirtyObjectHandles[object] = true
end

--- @param object RatScratch.Pipeline.ObjectHandle
function Scene:removeObject(object)
	assert(self.objectHandles[object], "object is not in scene")

	self.objectHandles[object] = nil
	self.dirtyObjectHandles[object] = nil

	object:silence(
		ObjectHandleEvent.DRAW_UPDATED,
		self._onObjectDrawUpdated,
		self
	)

	self.pipelines:get(DrawPipeline):removeDrawable(object)
end

--- @generic T : RatScratch.Pipeline.Light
--- @param lightType T | unknown
--- @return T
function Scene:newLight(lightType)
	local light = lightType()
	self:getPipeline(LightPipeline):addLight(light)

	self.lights[light] = true
	table.insert(self.lightsByIndex, light)

	return light
end

--- @param light RatScratch.Pipeline.Light
function Scene:freeLight(light)
	assert(self.lights[light], "light not in scene")

	self:getPipeline(LightPipeline):removeLight(light)

	self.lights[light] = nil
	Table.remove(self.lightsByIndex, light)
end

--- @private
--- @param object RatScratch.Pipeline.ObjectHandle
function Scene:_updateDirtyObjectHandle(object)
	local modelInstances = self.world:getModelInstancesHandle(object)
	local meshletCount = modelInstances:calculateMeshletCount()

	local drawPipeline = self:getPipeline(DrawPipeline)
	drawPipeline:resizeDrawable(object, meshletCount)
	drawPipeline:updateDrawable(object)
end

--- @private
function Scene:_updateDirtyObjectHandles()
	for object in pairs(self.dirtyObjectHandles) do
		self:_updateDirtyObjectHandle(object)
		self.dirtyObjectHandles[object] = nil
	end
end

function Scene:flush()
	if next(self.dirtyObjectHandles) then
		self:_updateDirtyObjectHandles()
	end

	self.pipelines:get(DrawPipeline):flush()
	self.pipelines:get(LightPipeline):flush()

	if self.camera then
		self.cameraFrame:update()

		self.camerasBuffer:copyTable(
			self.camera,
			self.cameraFrame:getData(),
			1,
			1
		)
		self.camerasBuffer:flush()

		self.pipelines:get(LightPipeline):clusterLights(
			self.world:getPipelineRuntime():getDefaultQualityPreset(),
			self.lightClusterResults
		)
	end
end

return Scene
