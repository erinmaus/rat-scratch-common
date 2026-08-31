local Object = require("rat-scratch-common").Object

--- @class RatScratch.Pipeline.impl.Pipeline : RatScratch.Common.BaseObject
--- @field pipelineRuntime RatScratch.Pipeline.PipelineRuntime
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.impl.Pipeline
local Pipeline = Object()

--- @param pipelineRuntime RatScratch.Pipeline.PipelineRuntime
function Pipeline:new(pipelineRuntime)
	self.pipelineRuntime = pipelineRuntime
end

function Pipeline:getPipelineRuntime()
	return self.pipelineRuntime
end

function Pipeline:getPipelineConfig()
	return self.pipelineRuntime:getConfig()
end

function Pipeline:flush()
	-- Nothing.
end

function Pipeline:update()
	-- Nothing.
end

return Pipeline
