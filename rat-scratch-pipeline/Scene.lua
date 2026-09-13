local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local DrawPipeline = require("rat-scratch-pipeline.DrawPipeline")
local LightPipeline = require("rat-scratch-pipeline.LightPipeline")
local ObjectHandleEvent = require("rat-scratch-pipeline.ObjectHandleEvent")
local Pipelines = require("rat-scratch-pipeline.Pipelines")

--- @class RatScratch.Pipeline.Scene : RatScratch.Common.BaseObject
--- @field private world RatScratch.Pipeline.World
--- @field private objectHandles table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private dirtyObjectHandles table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private lights table<RatScratch.Pipeline.Light, true>
--- @field private lightsByIndex RatScratch.Pipeline.Light[]
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
end

return Scene
