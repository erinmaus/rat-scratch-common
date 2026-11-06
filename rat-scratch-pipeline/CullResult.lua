local Object = require("rat-scratch-common").Object
local Draw = require("rat-scratch-pipeline.Draw")
local IndirectDispatch = require("rat-scratch-pipeline.IndirectDispatch")
local IndirectDraw = require("rat-scratch-pipeline.IndirectDraw")

--- @class RatScratch.Pipeline.CullResult : RatScratch.Common.BaseObject
--- @field private camerasBuffer RatScratch.Pipeline.CameraBuffer
--- @field private inputDrawsBuffer love.GraphicsBuffer
--- @field private outputDrawsBuffer love.GraphicsBuffer
--- @field private indirectDrawBuffer love.GraphicsBuffer
--- @field private indirectDispatchBuffer love.GraphicsBuffer
--- @field private sortDepthBuffer love.GraphicsBuffer
--- @field private sortDepthScratchBuffer love.GraphicsBuffer
--- @overload fun(camerasBuffer: RatScratch.Pipeline.CameraBuffer): RatScratch.Pipeline.CullResult
local CullResult = Object()

CullResult.SORT_CLUSTER_FORMAT = {
	{ location = 0, name = "depthKey", format = "uint32" },
	{ location = 1, name = "depthValue", format = "float" },
	{ location = 2, name = "drawIndex", format = "uint32" },
}

CullResult.DEFAULT_DRAW_PADDING = 16

--- @param camerasBuffer RatScratch.Pipeline.CameraBuffer
function CullResult:new(camerasBuffer)
	self.camerasBuffer = camerasBuffer

	self.indirectDrawBuffer = love.graphics.newBuffer(
		IndirectDraw.INDIRECT_DRAW_FORMAT,
		1,
		{ shaderstorage = true, indirectarguments = true }
	)

	self.indirectDispatchBuffer = love.graphics.newBuffer(
		IndirectDispatch.INDIRECT_DISPATCH_FORMAT,
		1,
		{ shaderstorage = true, indirectarguments = true }
	)
end

--- @return RatScratch.Pipeline.CameraBuffer
function CullResult:getCamerasBuffer()
	return self.camerasBuffer
end

--- @return love.GraphicsBuffer
function CullResult:getDrawsBuffer()
	return self.inputDrawsBuffer
end

--- @return love.GraphicsBuffer
function CullResult:getOtherDrawsBuffer()
	return self.outputDrawsBuffer
end

function CullResult:swapDrawBuffers()
	self.inputDrawsBuffer, self.outputDrawsBuffer =
		self.outputDrawsBuffer, self.inputDrawsBuffer
end

function CullResult:getSortBuffer()
	return self.sortDepthBuffer
end

function CullResult:getSortScratchBuffer()
	return self.sortDepthScratchBuffer
end

--- @return love.GraphicsBuffer
function CullResult:getIndirectDrawBuffer()
	return self.indirectDrawBuffer
end

--- @return love.GraphicsBuffer
function CullResult:getIndirectDispatchBuffer()
	return self.indirectDispatchBuffer
end

function CullResult:hasResult()
	return self.drawsBuffer ~= nil
end

--- @param drawCount integer
function CullResult:reserveDraws(drawCount)
	local cameraCount = self.camerasBuffer:getActiveCameraCount()
	local count = drawCount * cameraCount * CullResult.DEFAULT_DRAW_PADDING

	if
		not self.inputDrawsBuffer
		or count > self.inputDrawsBuffer:getElementCount()
	then
		count = math.max(count, 1)

		self.inputDrawsBuffer = love.graphics.newBuffer(
			Draw.DRAW_FORMAT,
			count,
			{ shaderstorage = true }
		)

		self.outputDrawsBuffer = love.graphics.newBuffer(
			Draw.DRAW_FORMAT,
			count,
			{ shaderstorage = true }
		)

		self.sortDepthBuffer = love.graphics.newBuffer(
			CullResult.SORT_CLUSTER_FORMAT,
			count,
			{ shaderstorage = true }
		)

		self.sortDepthScratchBuffer = love.graphics.newBuffer(
			CullResult.SORT_CLUSTER_FORMAT,
			count,
			{ shaderstorage = true }
		)
	end

	return self.inputDrawsBuffer
end

return CullResult
