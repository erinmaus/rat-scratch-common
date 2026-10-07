local Object = require("rat-scratch-common").Object
local Draw = require("rat-scratch-pipeline.Draw")
local IndirectDraw = require("rat-scratch-pipeline.IndirectDraw")

--- @class RatScratch.Pipeline.DoubleBufferResult : RatScratch.Common.BaseObject
--- @field private sourceBuffer love.Texture
--- @field private otherBuffer love.Texture
--- @field private resultBuffer? love.Texture
--- @field private binding1 table
--- @field private binding2 table
--- @field private currentBinding? table
--- @overload fun(sourceBuffer: love.Texture, otherBuffer: love.Texture): RatScratch.Pipeline.DoubleBufferResult
local DoubleBufferResult = Object()

DoubleBufferResult.DEFAULT_DRAW_PADDING = 16

--- @param sourceBuffer love.Texture
--- @param otherBuffer love.Texture
function DoubleBufferResult:new(sourceBuffer, otherBuffer)
	self.sourceBuffer = sourceBuffer
	self.otherBuffer = otherBuffer

	self.binding1 = {
		sourceBuffer,
		alllayers = true,
	}

	self.binding2 = {
		otherBuffer,
		alllayers = true,
	}
end

function DoubleBufferResult:start()
	self.currentBinding = self.binding1
	self.resultBuffer = nil
end

function DoubleBufferResult:step()
	if self.currentBinding == self.binding1 then
		self.currentBinding = self.binding2
	else
		self.currentBinding = self.binding1
	end
end

function DoubleBufferResult:stop()
	self.resultBuffer = self.currentBinding[1]
	self.currentBinding = nil
end

function DoubleBufferResult:getSourceBuffer()
	if self.currentBinding == self.binding1 then
		return self.binding2[1]
	else
		return self.binding1[1]
	end
end

function DoubleBufferResult:getOtherBuffer()
	if self.currentBinding == self.binding1 then
		return self.binding1[1]
	else
		return self.binding2[1]
	end
end

--- @param shader love.Shader
--- @param uniform string
function DoubleBufferResult:bindShaderInput(shader, uniform)
	if shader:hasUniform(uniform) then
		shader:send(uniform, self:getSourceBuffer())
	end
end

function DoubleBufferResult:bindShaderOutput()
	love.graphics.setCanvas(self.currentBinding)
end

--- @return boolean
function DoubleBufferResult:hasResult()
	return self.resultBuffer ~= nil
end

--- @return love.Texture
function DoubleBufferResult:getResult()
	return self.resultBuffer
end

return DoubleBufferResult
