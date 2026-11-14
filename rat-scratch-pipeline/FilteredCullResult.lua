local Object = require("rat-scratch-common").Object
local Draw = require("rat-scratch-pipeline.Draw")
local IndirectDispatch = require("rat-scratch-pipeline.IndirectDispatch")
local IndirectDraw = require("rat-scratch-pipeline.IndirectDraw")

--- @class RatScratch.Pipeline.FilteredCullResult : RatScratch.Common.BaseObject
--- @field private cullResult RatScratch.Pipeline.CullResult
--- @field private inputDrawsBuffer love.GraphicsBuffer
--- @field private outputDrawsBuffer love.GraphicsBuffer
--- @field private multiIndirectDrawBuffer love.GraphicsBuffer
--- @field private indirectDrawBuffers love.GraphicsBuffer[]
--- @field private indirectDispatchBuffer love.GraphicsBuffer
--- @field private sortDepthBuffer love.GraphicsBuffer
--- @field private sortDepthScratchBuffer love.GraphicsBuffer
--- @overload fun(cullResult: RatScratch.Pipeline.CullResult): RatScratch.Pipeline.FilteredCullResult
local FilteredCullResult = Object()

FilteredCullResult.SORT_CLUSTER_FORMAT = {
	{ location = 0, name = "depthKey", format = "uint32" },
	{ location = 1, name = "depthValue", format = "float" },
	{ location = 2, name = "drawIndex", format = "uint32" },
}

FilteredCullResult.OPAQUE_PASS_INDIRECT_BUFFER_INDEX = 1
FilteredCullResult.BLEND_PASS_INDIRECT_BUFFER_INDEX = 2
FilteredCullResult.MASK_PASS_INDIRECT_BUFFER_INDEX = 3
FilteredCullResult.MAX_PASS_BUFFER_COUNT = 3

--- @param cullResult RatScratch.Pipeline.CullResult
function FilteredCullResult:new(cullResult)
	self.cullResult = cullResult

	self.multiIndirectDrawBuffer = love.graphics.newBuffer(
		IndirectDraw.INDIRECT_DRAW_FORMAT,
		FilteredCullResult.MAX_PASS_BUFFER_COUNT,
		{ shaderstorage = true, indirectarguments = true }
	)

	self.indirectDrawBuffers = {}
	for i = 1, FilteredCullResult.MAX_PASS_BUFFER_COUNT do
		self.indirectDrawBuffers[i] = love.graphics.newBuffer(
			IndirectDraw.INDIRECT_DRAW_FORMAT,
			1,
			{ shaderstorage = true, indirectarguments = true }
		)
	end

	self.indirectDispatchBuffer = love.graphics.newBuffer(
		IndirectDispatch.INDIRECT_DISPATCH_FORMAT,
		1,
		{ shaderstorage = true, indirectarguments = true }
	)

	self.outputDrawsBuffer = {}
end

function FilteredCullResult:getCamerasBuffer()
	return self.cullResult:getCamerasBuffer()
end

function FilteredCullResult:getInputDrawBuffer()
	return self.cullResult:getDrawsBuffer()
end

function FilteredCullResult:getInputIndirectDrawBuffer()
	return self.cullResult:getIndirectDrawBuffer()
end

--- @param index integer
--- @return love.GraphicsBuffer
function FilteredCullResult:getIndirectDrawBuffer(index)
	return self.indirectDrawBuffers[index]
end

--- @param index integer
--- @return love.GraphicsBuffer
function FilteredCullResult:getOutputDrawBuffer(index)
	return self.outputDrawsBuffer[index]
end

--- @return love.GraphicsBuffer
function FilteredCullResult:getMultiIndirectDrawBuffer()
	return self.multiIndirectDrawBuffer
end

--- @return love.GraphicsBuffer
function FilteredCullResult:getIndirectDispatchBuffer()
	return self.indirectDispatchBuffer
end

function FilteredCullResult:reserveDraws()
	local count = self.cullResult:getDrawsBuffer():getElementCount()

	for i = 1, FilteredCullResult.MAX_PASS_BUFFER_COUNT do
		local buffer = self.outputDrawsBuffer[i]
		if not (buffer and count <= buffer:getElementCount()) then
			buffer = love.graphics.newBuffer(
				Draw.DRAW_FORMAT,
				count,
				{ shaderstorage = true }
			)

			self.outputDrawsBuffer[i] = buffer
		end
	end
end

return FilteredCullResult
