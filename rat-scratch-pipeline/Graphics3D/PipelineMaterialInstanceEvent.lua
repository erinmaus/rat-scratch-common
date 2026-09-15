local Object = require("rat-scratch-common").Object
local Event = require("rat-scratch-common").Event
local EventScope = require("rat-scratch-common").EventScope

--- @class RatScratch.Pipeline.Graphics3D.PipelineMaterialInstanceEvent : RatScratch.Common.Event
--- @field private uniform RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform
--- @overload fun(scope: RatScratch.Common.EventScope): RatScratch.Pipeline.Graphics3D.PipelineMaterialInstanceEvent
local PipelineMaterialInstanceEvent = Object(Event)

PipelineMaterialInstanceEvent.SET = EventScope.create()

function PipelineMaterialInstanceEvent:new(scope)
	Event.new(self, scope)
end

function PipelineMaterialInstanceEvent:getUniform()
	return self.uniform
end

--- @param uniform RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform
--- @return RatScratch.Pipeline.Graphics3D.PipelineMaterialInstanceEvent
function PipelineMaterialInstanceEvent.fromSet(uniform)
	local result = Event.get(
		PipelineMaterialInstanceEvent,
		PipelineMaterialInstanceEvent.MODIFY
	)
	result.uniform = uniform

	return result
end

return PipelineMaterialInstanceEvent
