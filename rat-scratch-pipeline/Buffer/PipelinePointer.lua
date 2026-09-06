local Object = require("rat-scratch-common").Object
local EventSource = require("rat-scratch-common.EventSource")
local PipelineBufferContextEvent =
	require("rat-scratch-pipeline.Buffer.PipelineBufferContextEvent")

--- @generic T
--- @class RatScratch.Pipeline.Buffer.PipelinePointer<T> : RatScratch.Common.BaseObject
--- @field private context RatScratch.Pipeline.Buffer.PipelineBufferContext
--- @field private instance T
--- @overload fun<T>(context?: RatScratch.Pipeline.Buffer.PipelineBufferContext, instance?: T): RatScratch.Pipeline.Buffer.PipelinePointer
local PipelinePointer = Object()

PipelinePointer.NULL = PipelinePointer()

function PipelinePointer:new(context, instance)
	self.context = context
	self.instance = instance
	self.eventSource = EventSource()
end

PipelinePointer.listen, PipelinePointer.silence =
	EventSource.mixin("eventSource")

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelinePointer<T>
--- @return T
function PipelinePointer:getInstance()
	return self.instance
end

function PipelinePointer:getIndexCount()
	if not (self.context and self.instance) then
		return 1, 0
	end

	if not self.context:has(self.instance) then
		return 1, 0
	end

	return self.context:getIndexCount(self.instance)
end

function PipelinePointer:getOffsetCount()
	local index, count = self:getIndexCount()
	return math.max(index - 1, 0), count
end

function PipelinePointer:move()
	self.eventSource:process(
		PipelineBufferContextEvent.fromMove(
			self.instance,
			self.context:getIndexCount(self.instance)
		)
	)
end

return PipelinePointer
