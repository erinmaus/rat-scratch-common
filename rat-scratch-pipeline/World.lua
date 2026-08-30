local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Animation = require("rat-scratch-graphics").Graphics3D.Animation
local Skeleton = require("rat-scratch-graphics").Graphics3D.Skeleton
local AnimationPipeline = require("rat-scratch-pipeline.AnimationPipeline")
local ModelPipeline = require("rat-scratch-pipeline.ModelPipeline")
local ObjectHandle = require("rat-scratch-pipeline.ObjectHandle")
local ObjectHandleEvent = require("rat-scratch-pipeline.ObjectHandleEvent")
local PipelineModel = require("rat-scratch-pipeline.Graphics3D.PipelineModel")
local Pipelines = require("rat-scratch-pipeline.Pipelines")
local ResourceTracker = require("rat-scratch-pipeline.impl.ResourceTracker")
local ResourceTrackerEvent =
	require("rat-scratch-pipeline.impl.ResourceTrackerEvent")

--- @class RatScratch.Pipeline.World : RatScratch.Common.BaseObject
--- @field private pipelines RatScratch.Pipeline.Pipelines
--- @field private objectHandles table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private dirtyObjectHandles table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private nextObjectHandleID integer
--- @field private modelResources RatScratch.Pipeline.ResourceTracker<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @field private skeletonResources RatScratch.Pipeline.ResourceTracker<RatScratch.Graphics.Graphics3D.Skeleton>
--- @field private animationResources RatScratch.Pipeline.ResourceTracker<RatScratch.Graphics.Graphics3D.Animation>
--- @field private resources table<RatScratch.Common.BaseObject, RatScratch.Pipeline.ResourceTracker>
--- @overload fun(pipelineConfig: RatScratch.Pipeline.PipelineConfig): RatScratch.Pipeline.World
local World = Object()

--- @param pipelineConfig RatScratch.Pipeline.PipelineConfig
function World:new(pipelineConfig)
	self.pipelines = Pipelines(pipelineConfig)

	self.objectHandles = {}
	self.dirtyObjectHandles = {}
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

	self.resources = {
		[PipelineModel] = self.modelResources,
		[Skeleton] = self.skeletonResources,
		[Animation] = self.animationResources,
	}
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
	modelPipeline:addModel(model)
end

--- @private
--- @param model? RatScratch.Pipeline.Graphics3D.PipelineModel
function World:_tryRemoveModel(model)
	if not model then
		return
	end

	local modelPipeline = self.pipelines:get(ModelPipeline)
	modelPipeline:removeModel(model)
end

--- @private
--- @param event RatScratch.Pipeline.impl.ResourceTrackerEvent<RatScratch.Pipeline.Graphics3D.PipelineModel>
function World:_onAddModel(event)
	self:_tryAddModel(event:getResource())
end

--- @private
--- @param event RatScratch.Pipeline.impl.ResourceTrackerEvent<RatScratch.Pipeline.Graphics3D.PipelineModel>
function World:_onRemoveModel(event)
	self:_tryRemoveModel(event:getPreviousValue())
end

--- @private
--- @param event RatScratch.Pipeline.impl.ResourceTrackerEvent<RatScratch.Pipeline.Graphics3D.PipelineModel>
function World:_onUpdateModel(event)
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

	return objectHandle
end

function World:freeObject(objectHandle)
	assert(self.objectHandles[objectHandle], "object handle not in world")

	self.objectHandles[objectHandle] = nil
	self.dirtyObjectHandles[objectHandle] = nil
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

return World
