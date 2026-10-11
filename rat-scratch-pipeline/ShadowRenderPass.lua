local Object = require("rat-scratch-common").Object
local LightPipeline = require("rat-scratch-pipeline.LightPipeline")
local RenderPass = require("rat-scratch-pipeline.RenderPass")

--- @class RatScratch.Pipeline.ShadowRenderPass : RatScratch.Pipeline.RenderPass
--- @field private lightPipelineCullResult RatScratch.Pipeline.CullResult
--- @field private lightPipelineShadowBlurDoubleBufferResult RatScratch.Pipeline.DoubleBufferResult
--- @overload fun(): RatScratch.Pipeline.ShadowRenderPass
local ShadowRenderPass = Object(RenderPass)

function ShadowRenderPass:attached()
	local lightPipeline = self:getScene():getPipeline(LightPipeline)

	self.lightPipelineCullResult = lightPipeline:newCullResult()
	self.lightPipelineShadowBlurDoubleBufferResult =
		lightPipeline:newShadowBlurDoubleBufferResult()
end

function ShadowRenderPass:getCullResult()
	return self.lightPipelineCullResult
end

function ShadowRenderPass:getShadowResult()
	return self.lightPipelineShadowBlurDoubleBufferResult
end

return ShadowRenderPass
