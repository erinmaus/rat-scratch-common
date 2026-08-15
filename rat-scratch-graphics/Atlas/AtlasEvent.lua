local Object = require("rat-scratch-common").Object
local Event = require("rat-scratch-common").Event
local EventScope = require("rat-scratch-common").EventScope

--- @class RatScratch.Graphics.Atlas.AtlasEvent : RatScratch.Common.Event
--- @overload fun(scope: RatScratch.Common.EventScope): RatScratch.Graphics.Atlas.AtlasEvent
local AtlasEvent = Object(Event)

AtlasEvent.MODIFY = EventScope.create()
AtlasEvent.FREE = EventScope.create()

function AtlasEvent:new(scope)
	Event.new(self, scope)
end

--- @return RatScratch.Graphics.Atlas.AtlasEvent
function AtlasEvent.fromModify()
	return Event.get(AtlasEvent, AtlasEvent.MODIFY)
end

--- @return RatScratch.Graphics.Atlas.AtlasEvent
function AtlasEvent.fromFree()
	return Event.get(AtlasEvent, AtlasEvent.FREE)
end

return AtlasEvent
