local Object = require("rat-scratch-common").Object
local Event = require("rat-scratch-common").Event
local EventScope = require("rat-scratch-common.EventScope")

--- @class RatScratch.Pipeline.Buffer.PipelineBufferContextEvent : RatScratch.Common.Event
--- @overload fun(scope: RatScratch.Common.EventScope): RatScratch.Pipeline.Buffer.PipelineBufferContextEvent
--- @field private newIndex integer
--- @field private oldIndex integer
--- @field private count integer
--- @field private instance any
--- @field private newCount integer
--- @field private oldCount integer
local PipelineBufferContextEvent = Object(Event)

PipelineBufferContextEvent.RESIZE = EventScope.create()
PipelineBufferContextEvent.COMPACT = EventScope.create()

function PipelineBufferContextEvent:new(scope)
	Event.new(self, scope)

	self.oldIndex = 0
	self.newIndex = 0
	self.count = 0
	self.newCount = 0
	self.oldCount = 0
end

function PipelineBufferContextEvent:getNewIndex()
	return self.newIndex
end

function PipelineBufferContextEvent:getOldIndex()
	return self.oldIndex
end

function PipelineBufferContextEvent:getCount()
	return self.count
end

--- @generic T
--- @return T
function PipelineBufferContextEvent:getInstance()
	return self.instance
end

function PipelineBufferContextEvent:getNewCount()
	return self.newCount
end

function PipelineBufferContextEvent:getOldCount()
	return self.oldCount
end

--- @param count integer
--- @return RatScratch.Pipeline.Buffer.PipelineBufferContextEvent
function PipelineBufferContextEvent.fromCompact(
	instance,
	newIndex,
	oldIndex,
	count
)
	local event =
		Event.get(PipelineBufferContextEvent, PipelineBufferContextEvent.RESIZE)

	event.instance = instance
	event.newIndex = newIndex
	event.oldIndex = oldIndex
	event.count = count

	return event
end

--- @param oldCount integer
--- @param newCount integer
--- @return RatScratch.Pipeline.Buffer.PipelineBufferContextEvent
function PipelineBufferContextEvent.fromResize(oldCount, newCount)
	local event =
		Event.get(PipelineBufferContextEvent, PipelineBufferContextEvent.RESIZE)

	event.newCount = newCount
	event.oldCount = oldCount

	return event
end

return PipelineBufferContextEvent
