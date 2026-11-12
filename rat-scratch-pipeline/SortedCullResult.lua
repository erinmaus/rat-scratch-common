local Object = require("rat-scratch-common").Object
local Draw = require("rat-scratch-pipeline.Draw")
local IndirectDispatch = require("rat-scratch-pipeline.IndirectDispatch")

--- @class RatScratch.Pipeline.SortedCullResult : RatScratch.Common.BaseObject
--- @field private cullResult RatScratch.Pipeline.FilteredCullResult
--- @field private drawsBuffer love.GraphicsBuffer
--- @field private sortDepthBuffer love.GraphicsBuffer
--- @field private sortDepthScratchBuffer love.GraphicsBuffer
--- @overload fun(cullResult: RatScratch.Pipeline.FilteredCullResult, index: integer, sign: -1 | 1): RatScratch.Pipeline.SortedCullResult
local SortedCullResult = Object()

SortedCullResult.SORT_SIGN_OPAQUE = -1
SortedCullResult.SORT_SIGN_BLEND = 1
SortedCullResult.SORT_SIGN_MASK = -1

SortedCullResult.SORT_CLUSTER_FORMAT = {
	{ location = 0, name = "depthKey", format = "uint32" },
	{ location = 1, name = "depthValue", format = "float" },
	{ location = 2, name = "drawIndex", format = "uint32" },
}

--- @param cullResult RatScratch.Pipeline.FilteredCullResult
--- @param index integer
--- @param sign -1 | 1
function SortedCullResult:new(cullResult, index, sign)
	self.cullResult = cullResult
	self.index = index
	self.sign = sign

	self.indirectDispatchBuffer = love.graphics.newBuffer(
		IndirectDispatch.INDIRECT_DISPATCH_FORMAT,
		1,
		{ shaderstorage = true, indirectarguments = true }
	)
end

function SortedCullResult:getCamerasBuffer()
	return self.cullResult:getCamerasBuffer()
end

function SortedCullResult:getSign()
	return self.sign
end

--- @return love.GraphicsBuffer
function SortedCullResult:getDrawsBuffer()
	return self.inputDrawsBuffer
end

--- @return love.GraphicsBuffer
function SortedCullResult:getOtherDrawsBuffer()
	return self.outputDrawsBuffer
end

function SortedCullResult:swapDrawBuffers()
	self.inputDrawsBuffer, self.outputDrawsBuffer =
		self.outputDrawsBuffer, self.inputDrawsBuffer
end

function SortedCullResult:getSortBuffer()
	return self.sortDepthBuffer
end

function SortedCullResult:getSortScratchBuffer()
	return self.sortDepthScratchBuffer
end

--- @return love.GraphicsBuffer
function SortedCullResult:getIndirectDrawBuffer()
	return self.cullResult:getIndirectDrawBuffer(self.index)
end

--- @return love.GraphicsBuffer
function SortedCullResult:getIndirectDispatchBuffer()
	return self.indirectDispatchBuffer
end

function SortedCullResult:reserveDraws()
	local count = self.cullResult:getInputDrawBuffer():getElementCount()

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
			SortedCullResult.SORT_CLUSTER_FORMAT,
			count,
			{ shaderstorage = true }
		)

		self.sortDepthScratchBuffer = love.graphics.newBuffer(
			SortedCullResult.SORT_CLUSTER_FORMAT,
			count,
			{ shaderstorage = true }
		)
	end
end

function SortedCullResult:copyDraws()
	love.graphics.copyBuffer(
		self.cullResult:getOutputDrawBuffer(self.index),
		self.inputDrawsBuffer
	)
end

return SortedCullResult
