local Object = require("rat-scratch-common").Object

--- @class RatScratch.Pipeline.PipelineRuntime : RatScratch.Common.BaseObject
--- @overload fun(config: RatScratch.Pipeline.PipelineConfig): RatScratch.Pipeline.PipelineRuntime
local PipelineRuntime = Object()

--- @param config RatScratch.Pipeline.PipelineConfig
function PipelineRuntime:new(config)
	self.config = config
end

function PipelineRuntime:getConfig()
	return self.config
end

return PipelineRuntime
