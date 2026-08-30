local Object = require("rat-scratch-common").Object

--- @class RatScratch.Pipeline.Pipelines : RatScratch.Common.BaseObject
--- @field private pipelineConfig RatScratch.Pipeline.PipelineConfig
--- @field private pipelines table<RatScratch.Common.BaseObject, true>
--- @overload fun(pipelineConfig: RatScratch.Pipeline.PipelineConfig): RatScratch.Pipeline.Pipelines
local Pipelines = Object()

--- @param pipelineConfig RatScratch.Pipeline.PipelineConfig
function Pipelines:new(pipelineConfig)
	self.pipelineConfig = pipelineConfig
	self.pipelines = {}
end

function Pipelines:getPipelineConfig()
	return self.pipelineConfig
end

--- @generic T : RatScratch.Common.BaseObject
--- @param pipelineType T | unknown
--- @return T
function Pipelines:get(pipelineType)
	local pipeline = self.pipelines[pipelineType]
	if not pipeline then
		pipeline = pipelineType(self.pipelineConfig)

		self.pipelines[pipelineType] = pipeline
	end

	return pipeline
end

--- @generic T : RatScratch.Common.BaseObject
--- @param pipelineType T | unknown
--- @return boolean
function Pipelines:has(pipelineType)
	return self.pipelines[pipelineType] ~= nil
end

return Pipelines
