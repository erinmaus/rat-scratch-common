local Object = require("rat-scratch-common").Object
local Event = require("rat-scratch-common").Event
local EventScope = require("rat-scratch-common").EventScope

--- @class RatScratch.Pipeline.LightEvent : RatScratch.Common.Event
--- @overload fun(scope: RatScratch.Common.EventScope): RatScratch.Pipeline.LightEvent
local LightEvent = Object(Event)

LightEvent.UPDATE = EventScope.create()

function LightEvent:new(scope)
	Event.new(self, scope)
end

--- @return RatScratch.Pipeline.LightEvent
function LightEvent.fromUpdate()
	return Event.get(LightEvent, LightEvent.UPDATE)
end

return LightEvent
