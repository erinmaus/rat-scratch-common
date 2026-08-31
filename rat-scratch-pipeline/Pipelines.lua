local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Pipeline = require("rat-scratch-pipeline.impl.Pipeline")

--- @class RatScratch.Pipeline.Pipelines : RatScratch.Common.BaseObject
--- @field private pipelineRuntime RatScratch.Pipeline.PipelineRuntime
--- @field private pipelines table<RatScratch.Pipeline.impl.Pipeline, RatScratch.Pipeline.impl.Pipeline>
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.Pipelines
local Pipelines = Object()

--- @param pipelineRuntime RatScratch.Pipeline.PipelineRuntime
function Pipelines:new(pipelineRuntime)
	self.pipelineRuntime = pipelineRuntime
	self.pipelines = {}
end

function Pipelines:getPipelineRuntime()
	return self.pipelineRuntime
end

function Pipelines:getPipelineConfig()
	return self.pipelineRuntime:getConfig()
end

--- @generic T : RatScratch.Pipeline.impl.Pipeline
--- @param pipelineType T | RatScratch.Pipeline.impl.Pipeline | unknown
--- @return T
function Pipelines:get(pipelineType)
	assert(
		Object.isType(pipelineType) and Object.isDerived(pipelineType, Pipeline),
		"pipeline type argument '%s' is not derived from RatScratch.Pipeline.impl.Pipeline or is not RatScratch.Common.BaseObject-type",
		Object.isType(pipelineType) and pipelineType._DEBUG.shortName or "???"
	)

	local pipeline = self.pipelines[pipelineType]
	if not pipeline then
		pipeline = pipelineType(self.pipelineRuntime)

		self.pipelines[pipelineType] = pipeline
	end

	return pipeline
end

--- @generic T : RatScratch.Pipeline.impl.Pipeline
--- @param pipelineType T | unknown
--- @return boolean
function Pipelines:has(pipelineType)
	return self.pipelines[pipelineType] ~= nil
end

return Pipelines
