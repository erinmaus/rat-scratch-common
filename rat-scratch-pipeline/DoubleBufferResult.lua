local Object = require("rat-scratch-common").Object

--- @class RatScratch.Pipeline.DoubleBufferResult : RatScratch.Common.BaseObject
--- @field private sourceBuffer RatScratch.Pipeline.RenderBuffer
--- @field private otherBuffer RatScratch.Pipeline.RenderBuffer
--- @field private originalBuffer RatScratch.Pipeline.RenderBuffer
--- @field private attachment integer[]
--- @field private currentBuffer? RatScratch.Pipeline.RenderBuffer
--- @field private nextBuffer? RatScratch.Pipeline.RenderBuffer
--- @overload fun(sourceBuffer: RatScratch.Pipeline.RenderBuffer, otherBuffer: RatScratch.Pipeline.RenderBuffer, attachment: integer, originalBuffer?: RatScratch.Pipeline.RenderBuffer): RatScratch.Pipeline.DoubleBufferResult
local DoubleBufferResult = Object()

DoubleBufferResult.DEFAULT_DRAW_PADDING = 16

--- @param sourceBuffer RatScratch.Pipeline.RenderBuffer
--- @param otherBuffer RatScratch.Pipeline.RenderBuffer
--- @param attachment integer
--- @param originalBuffer? RatScratch.Pipeline.RenderBuffer
function DoubleBufferResult:new(
	sourceBuffer,
	otherBuffer,
	attachment,
	originalBuffer
)
	self.sourceBuffer = sourceBuffer
	self.otherBuffer = otherBuffer
	self.originalBuffer = originalBuffer or self.sourceBuffer
	self.attachment = { attachment }
	self.isProcessing = false
end

function DoubleBufferResult:getSourceBuffer()
	return self.sourceBuffer
end

function DoubleBufferResult:getOtherBuffer()
	return self.otherBuffer
end

function DoubleBufferResult:start()
	assert(not self.isProcessing, "double buffer result is already started")

	self.isProcessing = true

	self.currentBuffer = self.originalBuffer
	if self.originalBuffer == self.sourceBuffer then
		self.nextBuffer = self.otherBuffer
	else
		self.nextBuffer = self.sourceBuffer
	end
end

function DoubleBufferResult:step()
	assert(self.isProcessing, "double buffer result is not started")
	if
		self.currentBuffer == self.originalBuffer
		and self.originalBuffer ~= self.sourceBuffer
	then
		self.currentBuffer, self.nextBuffer = self.nextBuffer, self.otherBuffer
	else
		self.currentBuffer, self.nextBuffer =
			self.nextBuffer, self.currentBuffer
	end
end

function DoubleBufferResult:stop()
	assert(self.isProcessing, "double buffer result is not started")
	self.isProcessing = false

	self.resultBuffer = self.nextBuffer
	self.currentBuffer, self.nextBuffer = nil, nil
end

--- @return love.Texture
function DoubleBufferResult:getCurrentTexture()
	return self.currentBuffer:getCanvas(self.attachment[1])
end

function DoubleBufferResult:getNextTexture()
	return self.nextBuffer:getCanvas(self.attachment[1])
end

--- @param shader love.Shader
--- @param uniform string
function DoubleBufferResult:bindShaderInput(shader, uniform)
	if shader:hasUniform(uniform) then
		shader:send(uniform, self:getCurrentTexture())
	end
end

function DoubleBufferResult:bindShaderOutput()
	self.nextBuffer:bind(self.attachment)
end

--- @return boolean
function DoubleBufferResult:hasResult()
	return self.resultBuffer ~= nil
end

--- @return love.Texture
function DoubleBufferResult:getResult()
	return self.resultBuffer:getCanvas(self.attachment[1])
end

return DoubleBufferResult
