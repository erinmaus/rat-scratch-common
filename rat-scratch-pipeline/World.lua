local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Animation = require("rat-scratch-graphics").Graphics3D.Animation
local Skeleton = require("rat-scratch-graphics").Graphics3D.Skeleton
local AnimationPipeline = require("rat-scratch-pipeline.AnimationPipeline")
local DrawPipeline = require("rat-scratch-pipeline.DrawPipeline")
local MaterialPipeline = require("rat-scratch-pipeline.MaterialPipeline")
local ModelPipeline = require("rat-scratch-pipeline.ModelPipeline")
local ObjectHandle = require("rat-scratch-pipeline.ObjectHandle")
local ObjectHandleEvent = require("rat-scratch-pipeline.ObjectHandleEvent")
local ObjectPipeline = require("rat-scratch-pipeline.ObjectPipeline")
local PipelineBufferContextEvent =
	require("rat-scratch-pipeline.Buffer.PipelineBufferContextEvent")
local PipelineModel = require("rat-scratch-pipeline.Graphics3D.PipelineModel")
local PipelineModelMeshPointer =
	require("rat-scratch-pipeline.Resources.PipelineModelMeshPointer")
local Pipelines = require("rat-scratch-pipeline.Pipelines")
local ResourceTracker = require("rat-scratch-pipeline.impl.ResourceTracker")
local ResourceTrackerEvent =
	require("rat-scratch-pipeline.impl.ResourceTrackerEvent")

--- @class RatScratch.Pipeline.World : RatScratch.Common.BaseObject
--- @field private pipelineRuntime RatScratch.Pipeline.PipelineRuntime
--- @field private pipelines RatScratch.Pipeline.Pipelines
--- @field private objectHandles table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private objectHandleToModelInstancesHandle table<RatScratch.Pipeline.ObjectHandle, RatScratch.Pipeline.ModelPipeline.ModelInstancesHandle>
--- @field private modelInstancesHandleToObjectHandle table<RatScratch.Pipeline.ModelPipeline.ModelInstancesHandle, RatScratch.Pipeline.ObjectHandle>
--- @field private animatorToObjectHandle table<RatScratch.Graphics.Graphics3D.Animator, RatScratch.Pipeline.ObjectHandle>
--- @field private dirtyObjectHandles table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private dirtyObjectHandleDraws table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private dirtyMaterialObjectHandles table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private nextObjectHandleID integer
--- @field private modelResources RatScratch.Pipeline.ResourceTracker<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @field private skeletonResources RatScratch.Pipeline.ResourceTracker<RatScratch.Graphics.Graphics3D.Skeleton>
--- @field private animationResources RatScratch.Pipeline.ResourceTracker<RatScratch.Graphics.Graphics3D.Animation>
--- @field private resources table<RatScratch.Common.BaseObject | string, RatScratch.Pipeline.ResourceTracker>
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.World
local World = Object()

--- @param pipelineRuntime RatScratch.Pipeline.PipelineRuntime
function World:new(pipelineRuntime)
	self.pipelineRuntime = pipelineRuntime
	self.pipelines = Pipelines(pipelineRuntime)

	self.objectHandles = {}
	self.dirtyObjectHandles = {}
	self.dirtyObjectHandleDraws = {}
	self.dirtyMaterialObjectHandles = {}
	self.objectHandleToModelInstancesHandle = {}
	self.modelInstancesHandleToObjectHandle = {}
	self.animatorToObjectHandle = {}
	self.nextObjectHandleID = 1

	self.skeletonResources = ResourceTracker()
	self.skeletonResources:listen(
		ResourceTrackerEvent.ADD,
		self._onAddSkeleton,
		self
	)
	self.skeletonResources:listen(
		ResourceTrackerEvent.REMOVE,
		self._onRemoveSkeleton,
		self
	)
	self.skeletonResources:listen(
		ResourceTrackerEvent.UPDATE,
		self._onUpdateSkeleton,
		self
	)

	self.modelResources = ResourceTracker()
	self.modelResources:listen(ResourceTrackerEvent.ADD, self._onAddModel, self)
	self.modelResources:listen(
		ResourceTrackerEvent.REMOVE,
		self._onRemoveModel,
		self
	)
	self.modelResources:listen(
		ResourceTrackerEvent.UPDATE,
		self._onUpdateModel,
		self
	)

	self.animationResources = ResourceTracker()
	self.animationResources:listen(
		ResourceTrackerEvent.ADD,
		self._onAddAnimation,
		self
	)
	self.animationResources:listen(
		ResourceTrackerEvent.REMOVE,
		self._onRemoveAnimation,
		self
	)
	self.animationResources:listen(
		ResourceTrackerEvent.UPDATE,
		self._onUpdateAnimation,
		self
	)

	self.textureResources = ResourceTracker()
	self.textureResources:listen(
		ResourceTrackerEvent.ADD,
		self._onAddTexture,
		self
	)
	self.textureResources:listen(
		ResourceTrackerEvent.REMOVE,
		self._onRemoveTexture,
		self
	)
	self.textureResources:listen(
		ResourceTrackerEvent.UPDATE,
		self._onUpdateTexture,
		self
	)

	self.resources = {
		[PipelineModel] = self.modelResources,
		[Skeleton] = self.skeletonResources,
		[Animation] = self.animationResources,
		["love.ImageData"] = self.textureResources,
	}

	self.scenes = {}
end

function World:getPipelineRuntime()
	return self.pipelineRuntime
end

function World:getPipelineConfig()
	return self.pipelineRuntime:getConfig()
end

--- @generic T : RatScratch.Common.BaseObject
--- @param pipelineType T | unknown
--- @return T
function World:getPipeline(pipelineType)
	return self.pipelines:get(pipelineType)
end

--- @private
--- @param resource RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>
function World:_tryAddSkeleton(resource)
	if not (resource and resource:getIsReady()) then
		return
	end

	local skeleton = resource:get()
	local animationPipeline = self.pipelines:get(AnimationPipeline)
	animationPipeline:addSkeleton(skeleton)
end

--- @private
--- @param skeleton? RatScratch.Graphics.Graphics3D.Skeleton
function World:_tryRemoveSkeleton(skeleton)
	if not skeleton then
		return
	end

	local animationPipeline = self.pipelines:get(AnimationPipeline)
	animationPipeline:removeSkeleton(skeleton)
end

--- @private
--- @param event RatScratch.Pipeline.impl.ResourceTrackerEvent<RatScratch.Graphics.Graphics3D.Skeleton>
function World:_onAddSkeleton(event)
	self:_tryAddSkeleton(event:getResource())
end

--- @private
--- @param event RatScratch.Pipeline.impl.ResourceTrackerEvent<RatScratch.Graphics.Graphics3D.Skeleton>
function World:_onRemoveSkeleton(event)
	self:_tryRemoveSkeleton(event:getPreviousValue())
end

--- @private
--- @param event RatScratch.Pipeline.impl.ResourceTrackerEvent<RatScratch.Graphics.Graphics3D.Skeleton>
function World:_onUpdateSkeleton(event)
	self:_tryRemoveSkeleton(event:getPreviousValue())
	self:_tryAddSkeleton(event:getResource())
end

--- @private
--- @param resource RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
function World:_tryAddModel(resource)
	if not (resource and resource:getIsReady()) then
		return
	end

	local model = resource:get()
	local modelPipeline = self.pipelines:get(ModelPipeline)
	if not modelPipeline:hasModel(model) then
		modelPipeline:addModel(model)
	end
end

--- @private
--- @param model? RatScratch.Pipeline.Graphics3D.PipelineModel
function World:_tryRemoveModel(model)
	if not model then
		return
	end

	local modelPipeline = self.pipelines:get(ModelPipeline)
	if modelPipeline:hasModel(model) then
		modelPipeline:removeModel(model)
	end
end

--- @private
--- @param event RatScratch.Pipeline.impl.ResourceTrackerEvent<RatScratch.Pipeline.Graphics3D.PipelineModel>
function World:_onAddModel(event)
	self:_tryAddModel(event:getResource())
	self:_onUpdateModel(event)
end

--- @private
--- @param event RatScratch.Pipeline.impl.ResourceTrackerEvent<RatScratch.Pipeline.Graphics3D.PipelineModel>
function World:_onRemoveModel(event)
	self:_tryRemoveModel(event:getPreviousValue())
end

--- @private
--- @param event RatScratch.Pipeline.impl.ResourceTrackerEvent<RatScratch.Pipeline.Graphics3D.PipelineModel>
function World:_onUpdateModel(event)
	if event:getResource():getIsReady() then
		for i = 1, event:getObjectCount() do
			local object = event:getObject(i)
			local handle = self.objectHandleToModelInstancesHandle[object]
			if handle then
				handle:update(event:getResource())
				self.dirtyObjectHandleDraws[object] = true
			end
		end
	end

	self:_tryRemoveModel(event:getPreviousValue())
	self:_tryAddModel(event:getResource())
end

--- @private
--- @param resource RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>
--- @param skeleton? RatScratch.Graphics.Graphics3D.Skeleton
function World:_tryAddAnimation(resource, skeleton)
	if not (resource and resource:getIsReady()) then
		return
	end

	if not skeleton then
		return
	end

	local animation = resource:get()
	local animationPipeline = self.pipelines:get(AnimationPipeline)
	if animationPipeline:hasSkeleton(skeleton) then
		animationPipeline:addAnimation(animation, skeleton)
	end
end

--- @private
--- @param animation? RatScratch.Graphics.Graphics3D.Animation
function World:_tryRemoveAnimation(animation)
	if not animation then
		return
	end

	local animationPipeline = self.pipelines:get(AnimationPipeline)
	animationPipeline:removeAnimation(animation)
end

--- @private
--- @param event RatScratch.Pipeline.impl.ResourceTrackerEvent<RatScratch.Graphics.Graphics3D.Animation>
function World:_onAddAnimation(event)
	--- @type RatScratch.Graphics.Graphics3D.Skeleton?
	local skeleton
	for i = 1, event:getObjectCount() do
		local object = event:getObject(i)
		skeleton = skeleton or object:getSkeleton():get()

		assert(
			not skeleton or skeleton == object:getSkeleton():get(),
			"skeleton/animation mis-match"
		)
	end

	self:_tryAddAnimation(event:getResource(), skeleton)
end

--- @private
--- @param event RatScratch.Pipeline.impl.ResourceTrackerEvent<RatScratch.Graphics.Graphics3D.Animation>
function World:_onRemoveAnimation(event)
	self:_tryRemoveAnimation(event:getPreviousValue())
end

--- @private
--- @param event RatScratch.Pipeline.impl.ResourceTrackerEvent<RatScratch.Graphics.Graphics3D.Animation>
function World:_onUpdateAnimation(event)
	self:_tryRemoveAnimation(event:getPreviousValue())
	self:_tryAddAnimation(event:getResource())
end

--- @private
--- @param resource RatScratch.Resource.Resource<love.ImageData>
function World:_tryAddTexture(resource)
	if not (resource and resource:getIsReady()) then
		return
	end

	local imageData = resource:get()
	local materialPipeline = self.pipelines:get(MaterialPipeline)
	if not materialPipeline:hasTexture(imageData) then
		materialPipeline:addTexture(imageData)
	end
end

--- @private
--- @param imageData? love.ImageData
function World:_tryRemoveTexture(imageData)
	if not imageData then
		return
	end

	local materialPipeline = self.pipelines:get(MaterialPipeline)
	if materialPipeline:hasTexture(imageData) then
		materialPipeline:removeTexture(imageData)
	end
end

--- @private
--- @param event RatScratch.Pipeline.impl.ResourceTrackerEvent<love.ImageData>
function World:_onAddTexture(event)
	self:_tryAddTexture(event:getResource())
end

--- @private
--- @param event RatScratch.Pipeline.impl.ResourceTrackerEvent<love.ImageData>
function World:_onRemoveTexture(event)
	self:_tryRemoveTexture(event:getPreviousValue())
end

--- @private
--- @param event RatScratch.Pipeline.impl.ResourceTrackerEvent<love.ImageData>
function World:_onUpdateTexture(event)
	self:_tryRemoveTexture(event:getPreviousValue())
	self:_tryAddTexture(event:getResource())
end

--- @param object RatScratch.Pipeline.ObjectHandle
--- @return RatScratch.Pipeline.ModelPipeline.ModelInstancesHandle
function World:getModelInstancesHandle(object)
	return self.objectHandleToModelInstancesHandle[object]
end

function World:newObject()
	local objectHandle = ObjectHandle(self.nextObjectHandleID, self)
	self.objectHandles[objectHandle] = true
	self.nextObjectHandleID = self.nextObjectHandleID + 1

	objectHandle:listen(
		ObjectHandleEvent.RESOURCE_ADDED,
		self._onAddResource,
		self
	)
	objectHandle:listen(
		ObjectHandleEvent.RESOURCE_REMOVED,
		self._onRemoveResource,
		self
	)
	objectHandle:listen(
		ObjectHandleEvent.ANIMATOR_ADDED,
		self._onAddAnimator,
		self
	)
	objectHandle:listen(
		ObjectHandleEvent.ANIMATOR_REMOVED,
		self._onRemoveAnimator,
		self
	)
	objectHandle:listen(
		ObjectHandleEvent.MATERIAL_ADDED,
		self._onAddMaterial,
		self
	)
	objectHandle:listen(
		ObjectHandleEvent.MATERIAL_REMOVED,
		self._onRemoveMaterial,
		self
	)

	local modelPipeline = self.pipelines:get(ModelPipeline)
	local modelInstances = modelPipeline:newModelInstances()
	self.objectHandleToModelInstancesHandle[objectHandle] = modelInstances
	self.modelInstancesHandleToObjectHandle[modelInstances] = objectHandle

	local modelInstancesPointer =
		modelPipeline:getModelInstancesPointer(modelInstances)
	objectHandle:setPointer("models", modelInstancesPointer)
	modelInstancesPointer:listen(
		PipelineBufferContextEvent.MOVE,
		self._onModelInstancesPointerMove,
		self
	)

	self.pipelines:get(ObjectPipeline):addObject(objectHandle)

	return objectHandle
end

--- @private
--- @param event RatScratch.Pipeline.Buffer.PipelineBufferContextEvent<RatScratch.Pipeline.ModelPipeline.ModelInstancesHandle>
function World:_onModelInstancesPointerMove(event)
	local modelInstances = event:getInstance()
	local objectHandle = self.modelInstancesHandleToObjectHandle[modelInstances]
	self.dirtyObjectHandles[objectHandle] = true
end

--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function World:freeObject(objectHandle)
	assert(self.objectHandles[objectHandle], "object handle not in world")

	objectHandle:silence(
		ObjectHandleEvent.RESOURCE_ADDED,
		self._onAddResource,
		self
	)

	objectHandle:silence(
		ObjectHandleEvent.RESOURCE_REMOVED,
		self._onRemoveResource,
		self
	)
	objectHandle:silence(
		ObjectHandleEvent.ANIMATOR_ADDED,
		self._onAddAnimator,
		self
	)
	objectHandle:silence(
		ObjectHandleEvent.ANIMATOR_REMOVED,
		self._onRemoveAnimator,
		self
	)
	objectHandle:silence(
		ObjectHandleEvent.MATERIAL_ADDED,
		self._onAddMaterial,
		self
	)
	objectHandle:silence(
		ObjectHandleEvent.MATERIAL_REMOVED,
		self._onRemoveMaterial,
		self
	)

	objectHandle:free()

	self.objectHandles[objectHandle] = nil
	self.dirtyObjectHandles[objectHandle] = nil
	self.dirtyObjectHandleDraws[objectHandle] = nil
	self.dirtyMaterialObjectHandles[objectHandle] = nil

	local modelPipeline = self.pipelines:get(ModelPipeline)
	local modelInstances = self.objectHandleToModelInstancesHandle[objectHandle]
	modelPipeline:freeModelInstances(modelInstances)
	self.objectHandleToModelInstancesHandle[objectHandle] = nil
	self.modelInstancesHandleToObjectHandle[modelInstances] = nil

	local modelInstancesPointer =
		modelPipeline:getModelInstancesPointer(modelInstances)
	modelInstancesPointer:silence(
		PipelineBufferContextEvent.MOVE,
		self._onModelInstancesPointerMove,
		self
	)

	self.pipelines:get(ObjectPipeline):removeObject(objectHandle)
end

function World:updateObject(objectHandle)
	assert(self.objectHandles[objectHandle], "object handle not in world")

	self.dirtyObjectHandles[objectHandle] = true
end

--- @private
--- @param event RatScratch.Pipeline.ObjectHandleEvent
--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function World:_onAddResource(event, objectHandle)
	local resourceTracker = self.resources[event:getResourceType()]
	if resourceTracker then
		resourceTracker:add(event:getResource(), objectHandle)
	end
end

--- @private
--- @param event RatScratch.Pipeline.ObjectHandleEvent
--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function World:_onRemoveResource(event, objectHandle)
	local resourceTracker = self.resources[event:getResourceType()]
	if resourceTracker then
		resourceTracker:remove(event:getResource(), objectHandle)
	end
end

--- @private
--- @param event RatScratch.Pipeline.ObjectHandleEvent
--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function World:_onAddAnimator(event, objectHandle)
	local animationPipeline = self.pipelines:get(AnimationPipeline)
	animationPipeline:addAnimator(event:getAnimator())

	local bonesPointer =
		animationPipeline:getAnimatorBonePointer(event:getAnimator())
	objectHandle:setPointer("bones", bonesPointer)

	self.animatorToObjectHandle[event:getAnimator()] = objectHandle
	bonesPointer:listen(
		PipelineBufferContextEvent.MOVE,
		self._onAnimatorBonesPointerMove,
		self
	)
end

--- @private
--- @param event RatScratch.Pipeline.Buffer.PipelineBufferContextEvent<RatScratch.Graphics.Graphics3D.Animator>
function World:_onAnimatorBonesPointerMove(event)
	local animator = event:getInstance()
	local objectHandle = self.animatorToObjectHandle[animator]
	self.dirtyObjectHandles[objectHandle] = true
end

--- @private
--- @param event RatScratch.Pipeline.ObjectHandleEvent
--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function World:_onRemoveAnimator(event, objectHandle)
	local animationPipeline = self.pipelines:get(AnimationPipeline)
	animationPipeline:removeAnimator(event:getAnimator())

	self.animatorToObjectHandle[event:getAnimator()] = nil
	objectHandle:setPointer("bones", nil)
end

--- @private
--- @param event RatScratch.Pipeline.ObjectHandleEvent
--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function World:_onAddMaterial(event, objectHandle)
	self.dirtyObjectHandles[objectHandle] = true
	self.dirtyMaterialObjectHandles[objectHandle] = true

	self:getPipeline(ModelPipeline)
		:updateModelInstances(
			self.objectHandleToModelInstancesHandle[objectHandle]
		)
end

--- @private
--- @param event RatScratch.Pipeline.ObjectHandleEvent
--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function World:_onRemoveMaterial(event, objectHandle)
	self.dirtyObjectHandles[objectHandle] = true
	self.dirtyMaterialObjectHandles[objectHandle] = true
end

--- @private
--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function World:_updateObjectHandleMaterials(objectHandle)
	local materialPipeline = self.pipelines:get(MaterialPipeline)

	local modelInstances = self.objectHandleToModelInstancesHandle[objectHandle]

	for i = 1, modelInstances:getHandleCount() do
		local handle = modelInstances:getHandle(i)
		local resource = handle.model

		if resource:getIsReady() then
			local model = resource:get()

			for i = 1, model:getMeshCount() do
				local meshPointer =
					PipelineModelMeshPointer.newModelMeshPointer(resource, i)
				local materialInstance =
					objectHandle:getMeshMaterial(meshPointer)
				local index =
					materialPipeline:getMaterialInstanceIndex(materialInstance)
				modelInstances:setMaterial(resource, i, index)
			end
		end
	end
end

--- @private
--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function World:_updateObjectHandle(objectHandle)
	objectHandle:flush()

	local objectPipeline = self.pipelines:get(ObjectPipeline)
	objectPipeline:updateObject(objectHandle)

	if self.dirtyMaterialObjectHandles[objectHandle] then
		self:_updateObjectHandleMaterials(objectHandle)
		self.dirtyMaterialObjectHandles[objectHandle] = nil
	end
end

--- @private
--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function World:_updateObjectHandleDraw(objectHandle)
	local scene = objectHandle:getScene()
	if not scene then
		return
	end

	local drawPipeline = scene:getPipeline(DrawPipeline)

	local modelInstances = self.objectHandleToModelInstancesHandle[objectHandle]
	local meshletCount = modelInstances:calculateMeshletCount()

	local draws = drawPipeline:resizeDrawable(objectHandle, meshletCount)
	--- @cast draws RatScratch.Pipeline.Draw[]

	local currentDraw = 1

	local objectInstancePointer = self:getPipeline(ObjectPipeline)
		:getObjectPointer(objectHandle)
	local bonesPointer = objectHandle:getAnimator()
		and self:getPipeline(AnimationPipeline)
			:getAnimatorBonePointer(objectHandle:getAnimator())
	for i = 1, modelInstances:getHandleCount() do
		local handle = modelInstances:getHandle(i)
		local model = handle.model:get()
		local modelInstancePointer = self:getPipeline(ModelPipeline)
			:getModelInstancesPointer(modelInstances)
		local meshInstancesPointer = self:getPipeline(ModelPipeline)
			:getModelInstancePointer(handle)
		local modelPointer = self:getPipeline(ModelPipeline)
			:getModelPointer(model)

		for j = 1, model:getMeshCount() do
			local mesh = model:getMesh(j)
			local meshletPointer = self:getPipeline(ModelPipeline)
				:getMeshletsPointer(mesh)
			local staticBaseVertexPointer = self:getPipeline(ModelPipeline)
				:getStaticBaseVertexPointer(mesh)
			local skinnedBaseVertexPointer = self:getPipeline(ModelPipeline)
				:getSkinnedBaseVertexPointer(mesh)
			local baseIndexPointer = self:getPipeline(ModelPipeline)
				:getBaseIndexPointer(mesh)

			for k = 1, mesh:getMeshletCount() do
				local draw = draws[currentDraw]

				draw:setPointer("objectInstanceIndex", objectInstancePointer)
				draw:setPointer("modelInstanceIndex", modelInstancePointer, i)
				draw:setPointer("meshInstanceIndex", meshInstancesPointer, j)
				draw:setPointer("modelIndex", modelPointer)
				draw:setPointer("meshIndex", meshInstancesPointer, j)
				draw:setPointer("meshletIndex", meshletPointer, k)
				draw:setPointer(
					"staticBaseVertexOffset",
					staticBaseVertexPointer
				)
				draw:setPointer(
					"skinnedBaseVertexOffset",
					skinnedBaseVertexPointer
				)
				draw:setPointer("boneOffsetCount", bonesPointer)
				draw:setPointer(
					"indexOffset",
					baseIndexPointer,
					(k - 1)
							* self.pipelineRuntime
								:getConfig()
								:getMeshletFormat()
								:getTriangleCount()
							* 3
						+ 1
				)

				currentDraw = currentDraw + 1
			end
		end
	end
end

--- @private
function World:_updateObjectHandleDraws()
	local c = 0
	for objectHandle in pairs(self.dirtyObjectHandleDraws) do
		c = c + 1
		print("update...", c)
		self:_updateObjectHandleDraw(objectHandle)
		self.dirtyObjectHandleDraws[objectHandle] = nil
	end
end

--- @private
function World:_updateObjectHandles()
	for objectHandle in pairs(self.dirtyObjectHandles) do
		self:_updateObjectHandle(objectHandle)
		self.dirtyObjectHandles[objectHandle] = nil
	end
end

function World:flush()
	self.pipelines:get(AnimationPipeline):flush()
	self.pipelines:get(MaterialPipeline):flush()
	self.pipelines:get(ModelPipeline):flush()

	self.modelResources:flush()
	self.skeletonResources:flush()
	self.animationResources:flush()
	self.textureResources:flush()

	if next(self.dirtyObjectHandles) then
		self:_updateObjectHandles()
	end

	if next(self.dirtyObjectHandleDraws) then
		self:_updateObjectHandleDraws()
	end

	self.pipelines:get(AnimationPipeline):update()
	self.pipelines:get(MaterialPipeline):update()
	self.pipelines:get(ModelPipeline):update()

	self.pipelines:get(ObjectPipeline):update()
	self.pipelines:get(ObjectPipeline):flush()
end

return World
