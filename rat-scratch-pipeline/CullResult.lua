local Object = require("rat-scratch-common").Object
local Draw = require("rat-scratch-pipeline.Draw")
local IndirectDraw = require("rat-scratch-pipeline.IndirectDraw")

--- @class RatScratch.Pipeline.CullResult : RatScratch.Common.BaseObject
--- @field private camerasBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Camera>
--- @field private drawsBuffer love.GraphicsBuffer
--- @field private indirectDrawBuffer love.GraphicsBuffer
--- @overload fun(camerasBuffer: RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Camera>): RatScratch.Pipeline.CullResult
local CullResult = Object()

CullResult.DEFAULT_DRAW_PADDING = 16

--- @param camerasBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Camera>
function CullResult:new(camerasBuffer)
	self.camerasBuffer = camerasBuffer

	self.indirectDrawBuffer = love.graphics.newBuffer(
		IndirectDraw.INDIRECT_DRAW_FORMAT,
		1,
		{ shaderstorage = true, indirectarguments = true }
	)
end

--- @return RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Camera>
function CullResult:getCamerasBuffer()
	return self.camerasBuffer
end

--- @return love.GraphicsBuffer
function CullResult:getDrawsBuffer()
	return self.drawsBuffer
end

--- @return love.GraphicsBuffer
function CullResult:getIndirectBuffer()
	return self.indirectDrawBuffer
end

function CullResult:hasResult()
	return self.drawsBuffer ~= nil
end

--- @param drawCount integer
function CullResult:reserveDraws(drawCount)
	local _, cameraCount = self.camerasBuffer:getIndexCount()
	local count = drawCount * cameraCount * CullResult.DEFAULT_DRAW_PADDING

	if not self.drawsBuffer or count > self.drawsBuffer:getElementCount() then
		self.drawsBuffer = love.graphics.newBuffer(
			Draw.DRAW_FORMAT,
			math.max(count, 1),
			{ shaderstorage = true }
		)
	end

	return self.drawsBuffer
end

return CullResult
