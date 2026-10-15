local Object = require("rat-scratch-common").Object
local Event = require("rat-scratch-common").Event
local EventScope = require("rat-scratch-common").EventScope

--- @class RatScratch.Pipeline.ReflectionProbeEvent : RatScratch.Common.Event
--- @overload fun(scope: RatScratch.Common.EventScope): RatScratch.Pipeline.ReflectionProbeEvent
local ReflectionProbeEvent = Object(Event)

ReflectionProbeEvent.UPDATE = EventScope.create()

function ReflectionProbeEvent:new(scope)
	Event.new(self, scope)
end

--- @return RatScratch.Pipeline.ReflectionProbeEvent
function ReflectionProbeEvent.fromUpdate()
	return Event.get(ReflectionProbeEvent, ReflectionProbeEvent.UPDATE)
end

return ReflectionProbeEvent
