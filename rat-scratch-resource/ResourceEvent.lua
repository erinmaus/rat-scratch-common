local Object = require("rat-scratch-common").Object
local Event = require("rat-scratch-common").Event
local EventScope = require("rat-scratch-common").EventScope

--- @generic T
--- @class RatScratch.Resource.ResourceEvent<T> : RatScratch.Common.Event
--- @field private previousValue T
--- @overload fun(scope: RatScratch.Common.EventScope): RatScratch.Resource.ResourceEvent
local ResourceEvent = Object(Event)

ResourceEvent.FREE = EventScope.create()
ResourceEvent.RELEASE = EventScope.create()
ResourceEvent.MODIFY = EventScope.create()

function ResourceEvent:new(scope)
	Event.new(self, scope)
end

function ResourceEvent:getPreviousValue()
	return self.previousValue
end

--- @return RatScratch.Resource.ResourceEvent
function ResourceEvent.fromFree()
	return Event.get(ResourceEvent, ResourceEvent.FREE)
end

--- @return RatScratch.Resource.ResourceEvent
function ResourceEvent.fromRelease()
	return Event.get(ResourceEvent, ResourceEvent.RELEASE)
end

--- @generic T
--- @param previousValue T
--- @return RatScratch.Resource.ResourceEvent<T>
function ResourceEvent.fromModify(previousValue)
	local event = Event.get(ResourceEvent, ResourceEvent.MODIFY)
	event.previousValue = previousValue

	return event
end

return ResourceEvent
