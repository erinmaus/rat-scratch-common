-- todo:
-- * generate Animator when Skeleton is loaded, reset when modified, clear when removed
-- * update Animator animations when animation reloaded
-- * add "attachAnimations" to add multiple animations from a scene
-- * fire events from ObjectHandle
local EventSource = require("rat-scratch-common").EventSource
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local ObjectHandleEvent = require("rat-scratch-pipeline.ObjectHandleEvent")
local Animation = require("rat-scratch-graphics").Graphics3D.Animation
local Animator = require("rat-scratch-graphics").Graphics3D.Animator
local Skeleton = require("rat-scratch-graphics").Graphics3D.Skeleton
local ObjectHandleAnimatorProvider =
	require("rat-scratch-pipeline.ObjectHandleAnimatorProvider")
local PipelineModel = require("rat-scratch-pipeline.Graphics3D.PipelineModel")
local PipelineScene = require("rat-scratch-pipeline.Graphics3D.PipelineScene")
local PipelineScenePointer =
	require("rat-scratch-pipeline.Resources.PipelineScenePointer")
local ResourceEvent = require("rat-scratch-resource.ResourceEvent")

--- @class RatScratch.Pipeline.ObjectHandle : RatScratch.Common.BaseObject
--- @field animatorProvider RatScratch.Pipeline.Graphics3D.ObjectHandleAnimatorProvider
--- @field animator? RatScratch.Graphics.Graphics3D.Animator
--- @field skeleton? RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>
--- @field animations RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>[]
--- @field animationToResource table<RatScratch.Graphics.Graphics3D.Animation, RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>>
--- @field models RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>[]
--- @field resourcesByInstance table<RatScratch.Resource.Resource, true>
--- @field eventSource RatScratch.Common.EventSource<RatScratch.Pipeline.ObjectHandle>
--- @overload fun(): RatScratch.Pipeline.ObjectHandle
local ObjectHandle = Object()

function ObjectHandle:new()
	self.animatorProvider = ObjectHandleAnimatorProvider(self)
	self.models = {}
	self.animations = {}
	self.animationToResource = {}
	self.resourcesByInstance = {}
	self.eventSource = EventSource(self)
end

ObjectHandle.listen, ObjectHandle.silence = EventSource.mixin("eventSource")

--- @param resource RatScratch.Resource.Resource
--- @param resourceType RatScratch.Common.BaseObject | unknown
--- @return boolean
function ObjectHandle:addResource(resource, resourceType)
	if self.resourcesByInstance[resource] then
		return false
	end

	self.resourcesByInstance[resource] = true
	self.eventSource:process(
		ObjectHandleEvent.fromResourceAdded(resource, resourceType)
	)
	resource:listen(ResourceEvent.MODIFY, self._onResourceUpdate, self)

	return true
end

--- @generic T
--- @param event RatScratch.Resource.ResourceEvent<T>
--- @param resource T
function ObjectHandle:_onResourceUpdate(event, resource)
	self.eventSource:process(ObjectHandleEvent.fromResourceUpdated(resource))
end

--- @param resource RatScratch.Resource.Resource
--- @param resourceType RatScratch.Common.BaseObject | unknown
--- @return boolean
function ObjectHandle:removeResource(resource, resourceType)
	if not self.resourcesByInstance[resource] then
		return false
	end

	resource:silence(ResourceEvent.MODIFY, self._onResourceUpdate, self)

	self.resourcesByInstance[resource] = nil
	self.eventSource:process(
		ObjectHandleEvent.fromResourceRemoved(resource, resourceType)
	)

	return true
end

--- @param skeleton RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>
--- @return boolean
function ObjectHandle:attachSkeleton(skeleton)
	if self.skeleton and not self:detachSkeleton() then
		return false
	end

	if not self:addResource(skeleton, Skeleton) then
		return false
	end

	skeleton:listen(ResourceEvent.MODIFY, self._onSkeletonUpdated, self)
	skeleton:listen(ResourceEvent.RELEASE, self._onSkeletonReleased, self)

	self.skeleton = skeleton
	return true
end

--- @private
--- @param skeleton RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>
function ObjectHandle:_updateSkeleton(skeleton)
	if not skeleton:getIsReady() then
		return
	end

	self.animator = Animator(self.animatorProvider, self.animator)
	self.eventSource:process(ObjectHandleEvent.fromAnimatorAdded(self.animator))
end

--- @private
--- @param event RatScratch.Resource.ResourceEvent<RatScratch.Graphics.Graphics3D.Skeleton>
--- @param skeleton RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>
function ObjectHandle:_onSkeletonUpdated(event, skeleton)
	self:_updateSkeleton(skeleton)
end

--- @private
--- @param event RatScratch.Resource.ResourceEvent<RatScratch.Graphics.Graphics3D.Skeleton>
--- @param skeleton RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>
function ObjectHandle:_onSkeletonReleased(event, skeleton)
	if self.skeleton == skeleton then
		self:detachSkeleton()
	end
end

--- @return boolean
function ObjectHandle:detachSkeleton()
	if not self.skeleton then
		return false
	end

	if self.animations then
		for i = #self.animations, 1, -1 do
			local animation = self.animations[i]
			self:detachAnimation(animation)
		end
	end

	if not self:removeResource(self.skeleton, Skeleton) then
		return false
	end

	self.skeleton:silence(ResourceEvent.MODIFY, self._onSkeletonUpdated, self)
	self.skeleton:silence(ResourceEvent.RELEASE, self._onSkeletonReleased, self)

	if self.animator then
		self.eventSource:process(
			ObjectHandleEvent.fromAnimatorRemoved(self.animator)
		)
		self.animator = nil
	end

	self.skeleton = nil
	return true
end

--- @return RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Skeleton>?
function ObjectHandle:getSkeleton()
	return self.skeleton
end

--- @param animation RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>
--- @return boolean
function ObjectHandle:attachAnimation(animation)
	if not self:addResource(animation, Animation) then
		return false
	end

	animation:listen(ResourceEvent.MODIFY, self._onAnimationUpdated, self)
	animation:listen(ResourceEvent.RELEASE, self._onAnimationReleased, self)

	if animation:get() then
		self.animationToResource[animation:get()] = animation
	end

	table.insert(self.animations, animation)
	return true
end

--- @private
--- @param event RatScratch.Resource.ResourceEvent<RatScratch.Graphics.Graphics3D.Animation>
--- @param animation RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>
function ObjectHandle:_onAnimationUpdated(event, animation)
	local previousAnimation = event:getPreviousValue()
	if previousAnimation then
		self.animationToResource[previousAnimation] = nil
	end

	self.animationToResource[animation:get()] = animation

	if self.animator then
		self.animator:swapAnimation(event:getPreviousValue(), animation:get())
	end
end

--- @private
--- @param event RatScratch.Resource.ResourceEvent<RatScratch.Graphics.Graphics3D.Animation>
--- @param animation RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>
function ObjectHandle:_onAnimationReleased(event, animation)
	self:detachAnimation(animation)
end

--- @param animations RatScratch.Pipeline.Graphics3D.PipelineScenePointer<RatScratch.Graphics.Graphics3D.Animation[]>
--- @return boolean
function ObjectHandle:attachAnimationCollection(animations)
	if not self:addResource(animations:getParent(), PipelineScene) then
		return false
	end

	animations
		:getParent()
		:listen(ResourceEvent.MODIFY, self._onAnimationCollectionUpdated, self)
	animations
		:getParent()
		:listen(
			ResourceEvent.RELEASE,
			self._onAnimationCollectionReleased,
			self
		)
	self:_updateAnimationCollection(animations)

	return true
end

--- @param animations RatScratch.Pipeline.Graphics3D.PipelineScenePointer<RatScratch.Graphics.Graphics3D.Animation[]>
--- @param previousAnimations? RatScratch.Pipeline.Graphics3D.PipelineScene
function ObjectHandle:_updateAnimationCollection(animations, previousAnimations)
	if not animations:getParent():getIsReady() then
		return
	end

	local scene = animations:getParent():get()
	local count
	if previousAnimations then
		count = previousAnimations:getAnimationCount(1)
		for i = 1, count do
			local previousAnimation = previousAnimations:getAnimation(1, i)
			local previousAnimationResource =
				self.animationToResource[previousAnimation]
			self:removeResource(previousAnimationResource, Animation)

			local nextAnimation = scene:getAnimation(1, i)
			if nextAnimation then
				local nextAnimationResource =
					PipelineScenePointer.newAnimationPointer(scene, 1, i)
				self:addResource(nextAnimationResource, Animation)

				self.animationToResource[nextAnimation] = nextAnimationResource

				if self.animator then
					self.animator:swapAnimation(
						previousAnimation,
						nextAnimation
					)
				end

				for i = 1, #self.animations do
					if self.animations[i] == previousAnimationResource then
						self.animations[i] = nextAnimationResource
						break
					end
				end
			else
				Table.remove(self.animations, previousAnimationResource)
			end
		end
	else
		count = 0
	end

	local nextCount = scene:getAnimationCount(1)
	for i = count + 1, nextCount do
		local nextAnimation = scene:getAnimation(1, i)

		local nextAnimationResource =
			PipelineScenePointer.newAnimationPointer(scene, 1, i)
		self:addResource(nextAnimationResource, Animation)

		self.animationToResource[nextAnimation] = nextAnimationResource
		table.insert(self.animations, nextAnimationResource)
	end
end

--- @private
--- @param event RatScratch.Resource.ResourceEvent<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param animations RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
function ObjectHandle:_onAnimationCollectionUpdated(event, animations)
	self:_updateAnimationCollection(animations, event:getPreviousValue())
end

--- @private
--- @param animations RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
function ObjectHandle:_removeAnimationCollection(animations)
	if not animations:getIsReady() then
		return
	end

	local scene = animations:get()
	local count = scene:getAnimationCount(1)
	for i = 1, count do
		local animation = scene:getAnimation(1, i)
		local animationResource = self.animationToResource[animation]
		if animationResource then
			self:removeResource(animationResource, Animation)
			self.animationToResource[animation] = nil

			Table.remove(self.animations, animationResource)
		end
	end
end

--- @private
--- @param event RatScratch.Resource.ResourceEvent<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param animations RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
function ObjectHandle:_onAnimationCollectionReleased(event, animations)
	if not self:removeResource(animations, PipelineScene) then
		return
	end

	self:_removeAnimationCollection(animations)
end

--- @param animation RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>
--- @return boolean
function ObjectHandle:detachAnimation(animation)
	if not self:removeResource(animation, Animation) then
		return false
	end

	if animation:getIsReady() then
		self.animationToResource[animation:get()] = nil
	end

	Table.remove(self.animations, animation)
	return true
end

--- @param animations RatScratch.Pipeline.Graphics3D.PipelineScenePointer<RatScratch.Graphics.Graphics3D.Animation[]>
--- @return boolean
function ObjectHandle:detachAnimationCollection(animations)
	if not self:removeResource(animations, PipelineScene) then
		return false
	end

	self:_removeAnimationCollection(animations)
	return true
end

--- @return integer
function ObjectHandle:getAnimationCount()
	return #self.animations
end

--- @param index integer
--- @return RatScratch.Resource.Resource<RatScratch.Graphics.Graphics3D.Animation>
function ObjectHandle:getAnimation(index)
	return self.animations[index]
end

--- @param model RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
function ObjectHandle:attachModel(model)
	if not self:addResource(model, PipelineModel) then
		return
	end

	table.insert(self.models, model)
end

--- @param model RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
function ObjectHandle:detachModel(model)
	if not self:removeResource(model, PipelineModel) then
		return
	end

	Table.remove(self.models, model)
end

return ObjectHandle
