local Object = require("rat-scratch-common").Object
local Event = require("rat-scratch-common").Event
local EventScope = require("rat-scratch-common").EventScope

--- @class RatScratch.Pipeline.ObjectHandleEvent : RatScratch.Common.Event
--- @field private resource RatScratch.Resource.Resource
--- @field private resourceType RatScratch.Common.BaseObject
--- @field private animator RatScratch.Graphics.Graphics3D.Animator
--- @field private mesh RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @field private material RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance
--- @overload fun(scope: RatScratch.Common.EventScope): RatScratch.Pipeline.ObjectHandleEvent
local ObjectHandleEvent = Object(Event)

ObjectHandleEvent.RESOURCE_ADDED = EventScope.create()
ObjectHandleEvent.RESOURCE_REMOVED = EventScope.create()
ObjectHandleEvent.RESOURCE_UPDATED = EventScope.create()
ObjectHandleEvent.MATERIAL_ADDED = EventScope.create()
ObjectHandleEvent.MATERIAL_REMOVED = EventScope.create()
ObjectHandleEvent.ANIMATOR_ADDED = EventScope.create()
ObjectHandleEvent.ANIMATOR_REMOVED = EventScope.create()

function ObjectHandleEvent:new(scope)
	Event.new(self, scope)
end

function ObjectHandleEvent:getResource()
	return self.resource
end

function ObjectHandleEvent:getResourceType()
	return self.resourceType
end

function ObjectHandleEvent:getAnimator()
	return self.animator
end

function ObjectHandleEvent:getMesh()
	return self.mesh
end

function ObjectHandleEvent:getMaterial()
	return self.material
end

--- @param resource RatScratch.Resource.Resource
--- @param resourceType RatScratch.Common.BaseObject | unknown
--- @return RatScratch.Pipeline.ObjectHandleEvent
function ObjectHandleEvent.fromResourceAdded(resource, resourceType)
	local event = Event.get(ObjectHandleEvent, ObjectHandleEvent.RESOURCE_ADDED)
	event.resource = resource
	event.resourceType = resourceType

	return event
end

--- @param resource RatScratch.Resource.Resource
--- @param resourceType RatScratch.Common.BaseObject | unknown
--- @return RatScratch.Pipeline.ObjectHandleEvent
function ObjectHandleEvent.fromResourceRemoved(resource, resourceType)
	local event =
		Event.get(ObjectHandleEvent, ObjectHandleEvent.RESOURCE_REMOVED)
	event.resource = resource
	event.resourceType = resourceType

	return event
end

--- @param resource RatScratch.Resource.Resource
--- @return RatScratch.Pipeline.ObjectHandleEvent
function ObjectHandleEvent.fromResourceUpdated(resource)
	local event =
		Event.get(ObjectHandleEvent, ObjectHandleEvent.RESOURCE_UPDATED)
	event.resource = resource

	local value = resource:get()
	if Object.isObject(value) then
		--- @cast value RatScratch.Common.BaseObject
		event.resourceType = value:getType()
	end

	return event
end

--- @param animator RatScratch.Graphics.Graphics3D.Animator
--- @return RatScratch.Pipeline.ObjectHandleEvent
function ObjectHandleEvent.fromAnimatorAdded(animator)
	local event = Event.get(ObjectHandleEvent, ObjectHandleEvent.ANIMATOR_ADDED)
	event.animator = animator

	return event
end

--- @param animator RatScratch.Graphics.Graphics3D.Animator
--- @return RatScratch.Pipeline.ObjectHandleEvent
function ObjectHandleEvent.fromAnimatorRemoved(animator)
	local event =
		Event.get(ObjectHandleEvent, ObjectHandleEvent.ANIMATOR_REMOVED)
	event.animator = animator

	return event
end

--- @param mesh RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @param material RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance
--- @return RatScratch.Pipeline.ObjectHandleEvent
function ObjectHandleEvent.fromMaterialAdded(mesh, material)
	local event = Event.get(ObjectHandleEvent, ObjectHandleEvent.MATERIAL_ADDED)
	event.mesh = mesh
	event.material = material

	return event
end

--- @param mesh RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @param material RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance
--- @return RatScratch.Pipeline.ObjectHandleEvent
function ObjectHandleEvent.fromMaterialRemoved(mesh, material)
	local event =
		Event.get(ObjectHandleEvent, ObjectHandleEvent.MATERIAL_REMOVED)
	event.mesh = mesh
	event.material = material

	return event
end

return ObjectHandleEvent
