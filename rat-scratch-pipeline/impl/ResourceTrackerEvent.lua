local Object = require("rat-scratch-common").Object
local Event = require("rat-scratch-common").Event
local EventScope = require("rat-scratch-common").EventScope
local Table = require("rat-scratch-common").Table
local ObjectHandle = require("rat-scratch-pipeline.ObjectHandle")

--- @generic T
--- @class RatScratch.Pipeline.impl.ResourceTrackerEvent<T> : RatScratch.Common.Event
--- @field private resource RatScratch.Resource.Resource<T>
--- @field private previousValue T
--- @field private objects RatScratch.Pipeline.ObjectHandle[]
--- @overload fun(scope: RatScratch.Common.EventScope): RatScratch.Pipeline.impl.ResourceTrackerEvent
local ResourceTrackerEvent = Object(Event)

ResourceTrackerEvent.ADD = EventScope.create()
ResourceTrackerEvent.REMOVE = EventScope.create()
ResourceTrackerEvent.UPDATE = EventScope.create()

function ResourceTrackerEvent:new(scope)
	Event.new(self, scope)

	self.objects = {}
end

function ResourceTrackerEvent:getResource()
	return self.resource
end

function ResourceTrackerEvent:getPreviousValue()
	return self.previousValue
end

function ResourceTrackerEvent:getObjectCount()
	return #self.objects
end

function ResourceTrackerEvent:getObject(index)
	return self.objects[index]
end

--- @param resource RatScratch.Resource.Resource
--- @param objects table<RatScratch.Pipeline.ObjectHandle, true>
--- @return RatScratch.Pipeline.impl.ResourceTrackerEvent
function ResourceTrackerEvent.fromAdd(resource, objects)
	local event = Event.get(ResourceTrackerEvent, ResourceTrackerEvent.ADD)
	event.resource = resource

	for object in pairs(objects) do
		table.insert(event.objects, object)
	end
	table.sort(event.objects, ObjectHandle.less)

	return event
end

--- @generic T
--- @param resource RatScratch.Resource.Resource<T>
--- @param previousValue T
--- @return RatScratch.Pipeline.impl.ResourceTrackerEvent
function ResourceTrackerEvent.fromRemove(resource, previousValue)
	local event = Event.get(ResourceTrackerEvent, ResourceTrackerEvent.REMOVE)
	event.resource = resource
	event.previousValue = previousValue

	return event
end

--- @generic T
--- @param resource RatScratch.Resource.Resource<T>
--- @param objects table<RatScratch.Pipeline.ObjectHandle, true>
--- @param previousValue T
--- @return RatScratch.Pipeline.impl.ResourceTrackerEvent<T>
function ResourceTrackerEvent.fromUpdate(resource, previousValue, objects)
	local event = Event.get(ResourceTrackerEvent, ResourceTrackerEvent.UPDATE)
	event.resource = resource
	event.previousValue = previousValue

	for object in pairs(objects) do
		table.insert(event.objects, object)
	end
	table.sort(event.objects, ObjectHandle.less)

	return event
end

return ResourceTrackerEvent
