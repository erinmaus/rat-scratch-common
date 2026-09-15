local Object = require("rat-scratch-common").Object

--- @class RatScratch.Pipeline.LightClusterResult : RatScratch.Common.BaseObject
--- @field private camerasBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Camera>
--- @field private lightIndicesBuffer love.GraphicsBuffer
--- @overload fun(camerasBuffer: RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Camera>): RatScratch.Pipeline.LightClusterResult
local LightClusterResult = Object()

LightClusterResult.LIGHT_INDICES_FORMAT = {
	{ location = 0, name = "index", format = "uint32" },
}

--- @param camerasBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Camera>
function LightClusterResult:new(camerasBuffer)
	self.camerasBuffer = camerasBuffer
end

--- @return RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Camera>
function LightClusterResult:getCamerasBuffer()
	return self.camerasBuffer
end

--- @return love.GraphicsBuffer
function LightClusterResult:getLightIndicesBuffer()
	return self.lightIndicesBuffer
end

function LightClusterResult:hasResult()
	return self.lightIndicesBuffer ~= nil
end

--- @param count integer
function LightClusterResult:reserveLightIndices(count)
	if
		not self.lightIndicesBuffer
		or count > self.lightIndicesBuffer:getElementCount()
	then
		self.lightIndicesBuffer = love.graphics.newBuffer(
			LightClusterResult.LIGHT_INDICES_FORMAT,
			math.max(count, 1),
			{ shaderstorage = true }
		)
	end

	return self.lightIndicesBuffer
end

return LightClusterResult
