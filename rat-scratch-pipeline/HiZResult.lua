local Object = require("rat-scratch-common").Object
local RenderBuffer = require("rat-scratch-pipeline.RenderBuffer")

--- @class RatScratch.Pipeline.HiZResult : RatScratch.Common.BaseObject
--- @field private camerasBuffer RatScratch.Pipeline.CameraBuffer
--- @field private renderBuffer RatScratch.Pipeline.RenderBuffer
--- @field private hiZRenderBuffer RatScratch.Pipeline.RenderBuffer
--- @overload fun(camerasBuffer: RatScratch.Pipeline.CameraBuffer, renderBuffer: RatScratch.Pipeline.RenderBuffer): RatScratch.Pipeline.HiZResult
local HiZResult = Object()

HiZResult.RENDER_BUFFER_FORMAT = {
	"rg32f",
}

--- @param camerasBuffer RatScratch.Pipeline.CameraBuffer
--- @param renderBuffer RatScratch.Pipeline.RenderBuffer
function HiZResult:new(camerasBuffer, renderBuffer)
	self.camerasBuffer = camerasBuffer
	self.renderBuffer = renderBuffer
	self.hiZRenderBuffer = RenderBuffer(HiZResult.RENDER_BUFFER_FORMAT)
end

--- @return RatScratch.Pipeline.CameraBuffer
function HiZResult:getCamerasBuffer()
	return self.camerasBuffer
end

--- @return RatScratch.Pipeline.RenderBuffer
function HiZResult:getSourceRenderBuffer()
	return self.renderBuffer
end

function HiZResult:getDestinationRenderBuffer()
	return self.hiZRenderBuffer
end

return HiZResult
