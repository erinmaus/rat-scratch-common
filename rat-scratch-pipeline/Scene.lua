local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local CameraBuffer = require("rat-scratch-pipeline.CameraBuffer")
local CameraFrame = require("rat-scratch-pipeline.CameraFrame")
local CullResult = require("rat-scratch-pipeline.CullResult")
local DrawPipeline = require("rat-scratch-pipeline.DrawPipeline")
local LightClusterResult = require("rat-scratch-pipeline.LightClusterResult")
local LightPipeline = require("rat-scratch-pipeline.LightPipeline")
local ObjectHandleEvent = require("rat-scratch-pipeline.ObjectHandleEvent")
local Pipelines = require("rat-scratch-pipeline.Pipelines")
local Vector3 = require("rat-scratch-math").Vector3

--- @class RatScratch.Pipeline.Scene : RatScratch.Common.BaseObject
--- @field private world RatScratch.Pipeline.World
--- @field private camera RatScratch.Pipeline.Camera
--- @field private cameraFrame RatScratch.Pipeline.CameraFrame
--- @field private camerasBuffer RatScratch.Pipeline.CameraBuffer<RatScratch.Pipeline.Camera>
--- @field private objectHandles table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private staticObjects RatScratch.Pipeline.ObjectHandle[]
--- @field private dynamicObjects RatScratch.Pipeline.ObjectHandle[]
--- @field private dirtyObjectHandles table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private lights table<RatScratch.Pipeline.Light, true>
--- @field private lightsByIndex RatScratch.Pipeline.Light[]
--- @field private staticMinBounds RatScratch.Math.Vector3
--- @field private staticMaxBounds RatScratch.Math.Vector3
--- @field private staticObjectBoundsDirty boolean
--- @field private dynamicMinBounds RatScratch.Math.Vector3
--- @field private dynamicMaxBounds RatScratch.Math.Vector3
--- @field private dynamicObjectBoundsDirty boolean
--- @field private minBounds RatScratch.Math.Vector3
--- @field private maxBounds RatScratch.Math.Vector3
--- @field private sceneBoundsDirty boolean
--- @overload fun(world: RatScratch.Pipeline.World): RatScratch.Pipeline.Scene
local Scene = Object()

--- @param world RatScratch.Pipeline.World
function Scene:new(world)
	self.world = world
	self.objectHandles = {}
	self.staticObjects = {}
	self.dynamicObjects = {}
	self.dirtyObjectHandles = {}
	self.dirtyObjectHandleDraws = {}

	self.lights = {}
	self.lightsByIndex = {}

	self.pipelines = Pipelines(world:getPipelineRuntime())

	self.camerasBuffer = CameraBuffer()

	self.staticMinBounds = Vector3()
	self.staticMaxBounds = Vector3()
	self.staticObjectBoundsDirty = false

	self.dynamicMinBounds = Vector3()
	self.dynamicMaxBounds = Vector3()
	self.dynamicObjectBoundsDirty = false

	self.minBounds = Vector3()
	self.maxBounds = Vector3()
	self.sceneBoundsDirty = false
end

function Scene:newCullResult()
	return CullResult(self.camerasBuffer)
end

function Scene:newLightClusterResult()
	return LightClusterResult(self.camerasBuffer)
end

--- @param shader love.Shader
--- @param qualityPreset string
function Scene:bind(shader, qualityPreset)
	self.camerasBuffer:bind(shader)
end

--- @param camera RatScratch.Pipeline.Camera
function Scene:setCamera(camera)
	if self.camera then
		self.camerasBuffer:unregister(self.camera)
	end

	self.camera = camera
	self.cameraFrame = CameraFrame(camera)

	self.camerasBuffer:register(self.camera, 1)
	self.camerasBuffer:set(self.camera, 1, self.camera)
	self.camerasBuffer:activate(self.camera)
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

	object:listen(
		ObjectHandleEvent.TRANSFORMED,
		self._onObjectTransformed,
		self
	)

	self.pipelines:get(DrawPipeline):addDrawable(object)

	if object:getIsStatic() then
		table.insert(self.staticObjects, object)
	elseif object:getIsDynamic() then
		table.insert(self.dynamicObjects, object)
	end
end

--- @private
--- @param object RatScratch.Pipeline.ObjectHandle
function Scene:_makeBoundsDirty(object)
	if object:getIsStatic() then
		self.staticObjectBoundsDirty = true
	elseif object:getIsDynamic() then
		self.dynamicObjectBoundsDirty = true
	end
end

--- @private
--- @param event RatScratch.Pipeline.ObjectHandleEvent
--- @param object RatScratch.Pipeline.ObjectHandle
function Scene:_onObjectDrawUpdated(event, object)
	self.dirtyObjectHandles[object] = true
	self:_makeBoundsDirty(object)
end

--- @private
--- @param event RatScratch.Pipeline.ObjectHandleEvent
--- @param object RatScratch.Pipeline.ObjectHandle
function Scene:_onObjectTransformed(event, object)
	self:_makeBoundsDirty(object)
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

	object:silence(
		ObjectHandleEvent.TRANSFORMED,
		self._onObjectTransformed,
		self
	)

	self.pipelines:get(DrawPipeline):removeDrawable(object)

	if object:getIsStatic() then
		Table.remove(self.staticObjects, object)
	elseif object:getIsDynamic() then
		Table.remove(self.dynamicObjects, object)
	end
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
	local drawPipeline = self:getPipeline(DrawPipeline)
	drawPipeline:updateDrawable(object)
end

--- @private
function Scene:_updateDirtyObjectHandles()
	for object in pairs(self.dirtyObjectHandles) do
		self:_updateDirtyObjectHandle(object)
		self.dirtyObjectHandles[object] = nil
	end
end

--- @private
--- @param objects RatScratch.Pipeline.ObjectHandle[]
--- @param minBounds RatScratch.Math.Vector3
--- @param maxBounds RatScratch.Math.Vector3
function Scene:_updateObjectBounds(objects, minBounds, maxBounds)
	if #objects == 0 then
		minBounds:from(0)
		maxBounds:from(0)

		return
	end

	minBounds:from(math.huge)
	maxBounds:from(-math.huge)
	for _, object in ipairs(objects) do
		local objectMinBounds, objectMaxBounds = object:getTransformedBounds()

		minBounds:min(objectMinBounds, minBounds)
		maxBounds:max(objectMaxBounds, maxBounds)
	end
end

function Scene:getStaticBounds()
	if self.staticObjectBoundsDirty then
		self:_updateObjectBounds(
			self.staticObjects,
			self.staticMinBounds,
			self.staticMaxBounds
		)

		self.staticObjectBoundsDirty = false
	end

	return self.staticMinBounds, self.staticMaxBounds
end

function Scene:getDynamicBounds()
	if self.dynamicObjectBoundsDirty then
		self:_updateObjectBounds(
			self.dynamicObjects,
			self.dynamicMinBounds,
			self.dynamicMaxBounds
		)

		self.dynamicObjectBoundsDirty = false
	end

	return self.dynamicMinBounds, self.dynamicMaxBounds
end

function Scene:getBounds()
	if self.sceneBoundsDirty then
		local dynamicMinBounds, dynamicMaxBounds = self:getDynamicBounds()
		local staticMinBounds, staticMaxBounds = self:getStaticBounds()

		self.minBounds:from(staticMinBounds:get())
		self.maxBounds:from(staticMaxBounds:get())

		self.minBounds:min(dynamicMinBounds, self.minBounds)
		self.maxBounds:max(dynamicMaxBounds, self.maxBounds)

		self.sceneBoundsDirty = false
	end

	return self.minBounds, self.maxBounds
end

function Scene:update()
	self.pipelines:get(DrawPipeline):update()
	self.pipelines:get(LightPipeline):update()

	self.camerasBuffer:update()
end

function Scene:flush()
	if next(self.dirtyObjectHandles) then
		self:_updateDirtyObjectHandles()
	end

	self.pipelines:get(DrawPipeline):flush()
	self.pipelines:get(LightPipeline):flush()

	self.camerasBuffer:flush()
end

return Scene
