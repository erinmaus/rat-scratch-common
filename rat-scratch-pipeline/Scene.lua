local Object = require("rat-scratch-common").Object
local DrawPipeline = require("rat-scratch-pipeline.DrawPipeline")
local LightEvent = require("rat-scratch-pipeline.LightEvent")
local ObjectHandleEvent = require("rat-scratch-pipeline.ObjectHandleEvent")
local Pipelines = require("rat-scratch-pipeline.Pipelines")

--- @class RatScratch.Pipeline.Scene : RatScratch.Common.BaseObject
--- @field private world RatScratch.Pipeline.World
--- @field private objectHandles table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private dirtyObjectHandles table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private lights table<RatScratch.Pipeline.Light, true>
--- @field private shadowCastingLights table<RatScratch.Pipeline.Light, true>
--- @field private dirtyLights table<RatScratch.Pipeline.Light, true>
--- @overload fun(world: RatScratch.Pipeline.World): RatScratch.Pipeline.Scene
local Scene = Object()

--- @param world RatScratch.Pipeline.World
function Scene:new(world)
	self.world = world
	self.objectHandles = {}
	self.dirtyObjectHandles = {}
	self.dirtyObjectHandleDraws = {}

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
	assert(self.objectHandles[object], "object is in scene")

	self.objectHandles[object] = true
	self.dirtyObjectHandles[object] = true
end

--- @param object RatScratch.Pipeline.ObjectHandle
function Scene:removeObject(object)
	assert(self.objectHandles[object], "object is not in scene")

	self.objectHandles[object] = nil
	self.dirtyObjectHandles[object] = nil
end

--- @param object RatScratch.Pipeline.ObjectHandle
function Scene:updateObject(object)
	assert(self.objectHandles[object], "object is not in scene")

	self.dirtyObjectHandles[object] = true
end

--- @generic T : RatScratch.Pipeline.Light
--- @param lightType T | unknown
--- @return T
function Scene:newLight(lightType)
	local light = lightType()

	light:listen(LightEvent.UPDATE, self._onLightUpdated, self)

	self.lights[light] = true
	self.dirtyLights[light] = true

	return light
end

--- @param light RatScratch.Pipeline.Light
function Scene:freeLight(light)
	assert(self.lights[light], "light not in scene")

	light:silence(LightEvent.UPDATE, self._onLightUpdated, self)

	self.lights[light] = nil
	self.shadowCastingLights[light] = nil
	self.dirtyLights[light] = nil
end

--- @private
--- @param light RatScratch.Pipeline.Light
function Scene:_onLightUpdated(light)
	self.dirtyLights[light] = true
end

--- @private
--- @param object RatScratch.Pipeline.ObjectHandle
function Scene:_updateDirtyObjectHandle(object)
	local modelInstances = self.world:getModelInstancesHandle(object)

	local meshletCount = 0
	for i = 1, modelInstances:getHandleCount() do
		local handle = modelInstances:getHandle(i)
		local model = handle.model:get()
		local meshes = handle.meshes
		for j = 1, #meshes do
			local mesh = model:getMesh(j)
			meshletCount = meshletCount + mesh:getMeshletCount()
		end
	end

	local drawPipeline = self:getPipeline(DrawPipeline)
	drawPipeline:updateDrawable()
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
end

return Scene
