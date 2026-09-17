local Object = require("rat-scratch-common").Object
local Event = require("rat-scratch-common").Event
local EventScope = require("rat-scratch-common").EventScope

--- @class RatScratch.Pipeline.CameraEvent : RatScratch.Common.Event
--- @overload fun(scope: RatScratch.Common.EventScope): RatScratch.Pipeline.CameraEvent
local CameraEvent = Object(Event)

CameraEvent.UPDATE = EventScope.create()

function CameraEvent:new(scope)
	Event.new(self, scope)
end

--- @return RatScratch.Pipeline.CameraEvent
function CameraEvent.fromUpdate()
	return Event.get(CameraEvent, CameraEvent.UPDATE)
end

return CameraEvent
