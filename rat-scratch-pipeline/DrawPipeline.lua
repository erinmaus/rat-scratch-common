local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local Pipeline = require("rat-scratch-pipeline.impl.Pipeline")
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Draw = require("rat-scratch-pipeline.Draw")
local PipelineMultiBuffer =
	require("rat-scratch-pipeline.Buffer.PipelineMultiBuffer")
local Transform = require("rat-scratch-math").Transform

--- @class RatScratch.Pipeline.DrawPipeline : RatScratch.Pipeline.impl.Pipeline
--- @field private drawables table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private dirtyDrawables table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private drawableToDraws table<RatScratch.Pipeline.ObjectHandle, RatScratch.Pipeline.Draw[]>
--- @field private compactDraws boolean
--- @field private indirectDrawBuffer love.GraphicsBuffer
--- @field private camerasBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Camera>
--- @field private inputDrawsBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.ObjectHandle>
--- @field private outputDrawsBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.ObjectHandle>
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.DrawPipeline
local DrawPipeline = Object(Pipeline)

DrawPipeline.INDIRECT_DRAW_FORMAT = {
	{ location = 0, name = "vertexCount", format = "uint32" },
	{ location = 1, name = "instanceCount", format = "uint32" },
	{ location = 2, name = "firstVertex", format = "uint32" },
	{ location = 3, name = "firstInstance", format = "uint32" },
}

DrawPipeline.DEFAULT_CAMERA_COUNT = 64
DrawPipeline.DEFAULT_DRAW_COUNT = 1024 * 16 * DrawPipeline.DEFAULT_CAMERA_COUNT
DrawPipeline.DEFAULT_DRAW_OUTPUTS = DrawPipeline.DEFAULT_CAMERA_COUNT
	* DrawPipeline.DEFAULT_CAMERA_COUNT

--- @param pipelineRuntime RatScratch.Pipeline.PipelineRuntime
function DrawPipeline:new(pipelineRuntime)
	Pipeline.new(self, pipelineRuntime)

	self.drawables = {}
	self.dirtyDrawables = {}
	self.drawableToDraws = {}
	self.compactDrawables = false

	self.indirectDrawBufferData = {}
	BufferFormat.resetValue(
		DrawPipeline.INDIRECT_DRAW_FORMAT,
		self.indirectDrawBufferData
	)

	self.indirectDrawBuffer = love.graphics.newBuffer(
		DrawPipeline.INDIRECT_DRAW_FORMAT,
		1,
		{ shaderstorage = true, indirectarguments = true }
	)

	self.inputDrawsBuffer = PipelineBuffer(
		Draw.DRAW_FORMAT,
		{ shaderstorage = true },
		DrawPipeline.DEFAULT_DRAW_COUNT
	)

	self.outputDrawsBuffer = PipelineBuffer(
		Draw.DRAW_FORMAT,
		{ shaderstorage = true },
		DrawPipeline.DEFAULT_DRAW_COUNT
	)
end

--- @return RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.ObjectHandle>
function DrawPipeline:getDrawsBuffer()
	return self.inputDrawsBuffer
end

--- @param object RatScratch.Pipeline.ObjectHandle
function DrawPipeline:addDrawable(object)
	assert(not self.drawables[object], "object is in drawables list")

	self.drawables[object] = true
end

--- @param object RatScratch.Pipeline.ObjectHandle
function DrawPipeline:removeDrawable(object)
	assert(self.drawables[object], "object is in not drawables list")

	self.drawables[object] = nil
	self.inputDrawsBuffer:unregister(object)
end

--- @param object RatScratch.Pipeline.ObjectHandle
function DrawPipeline:updateDrawable(object)
	assert(self.drawables[object], "object is not in drawables list")

	if self.drawableToDraws[object] then
		self.dirtyDrawables[object] = true
	end
end

--- @param object RatScratch.Pipeline.ObjectHandle
--- @param meshletCount integer
function DrawPipeline:resizeDrawable(object, meshletCount)
	assert(self.drawables[object], "object is not in drawables list")

	if meshletCount == 0 then
		return
	end

	self.inputDrawsBuffer:registerOrResize(object, meshletCount)

	local draws = self.drawableToDraws[object]
	local data = draws and draws[1] and draws[1]:getData()

	draws = Draw.newBatch(meshletCount, data, 1, draws)
	self.drawableToDraws[object] = draws

	self:updateDrawable(object)

	return draws
end

--- @param object RatScratch.Pipeline.ObjectHandle
--- @param index integer
--- @return RatScratch.Pipeline.Draw
function DrawPipeline:getDraw(object, index)
	local draws = self.drawableToDraws[object]
	return draws and draws[index]
end

--- @private
--- @param object RatScratch.Pipeline.ObjectHandle
function DrawPipeline:_flushDrawable(object)
	local draws = self.drawableToDraws[object]
	Draw.updateBatch(draws)

	local data = draws[1]:getData()

	self.inputDrawsBuffer:copyTable(object, data, 1, #draws, 1)
end

--- @private
function DrawPipeline:_flushDrawables()
	for drawable in pairs(self.dirtyDrawables) do
		self:_flushDrawable(drawable)
		self.dirtyDrawables[drawable] = nil
	end
end

function DrawPipeline:flush()
	if self.compactDrawables then
		self.inputDrawsBuffer:compact()
		self.compactDrawables = false
	end

	if next(self.dirtyDrawables) then
		self:_flushDrawables()
	end

	self.inputDrawsBuffer:flush()
end

--- @param cullShader love.Shader
--- @param cameraCount integer
function DrawPipeline:cull(cullShader, cameraCount)
	local _, drawCount = self.inputDrawsBuffer:getIndexCount()

	BufferFormat.resetValue(
		DrawPipeline.INDIRECT_DRAW_FORMAT,
		self.indirectDrawBufferData
	)
	BufferFormat.setValue(
		DrawPipeline.INDIRECT_DRAW_FORMAT,
		self.indirectDrawBufferData,
		"vertexCount",
		0,
		self:getPipelineConfig():getMeshletFormat():getTriangleCount() * 3
	)
	self.indirectDrawBuffer:setArrayData(self.indirectDrawBufferData)

	local localX, localY = cullShader:getLocalThreadgroupSize()
	if cullShader:hasUniform("rat_DrawsBuffer") then
		cullShader:send("rat_DrawsBuffer", self.inputDrawsBuffer:getBuffer())
	end

	if cullShader:hasUniform("rat_OutputDrawsBuffer") then
		cullShader:send(
			"rat_OutputDrawsBuffer",
			self.outputDrawsBuffer:getBuffer()
		)
	end

	if cullShader:hasUniform("rat_IndirectDrawsBuffer") then
		cullShader:send("rat_IndirectDrawsBuffer", self.indirectDrawBuffer)
	end

	if cullShader:hasUniform("rat_DrawCount") then
		cullShader:send("rat_DrawCount", drawCount)
	end

	if cullShader:hasUniform("rat_CameraCount") then
		cullShader:send("rat_CameraCount", cameraCount)
	end

	love.graphics.dispatchThreadgroups(
		cullShader,
		math.max(math.ceil(drawCount / localX), 1),
		math.max(math.ceil(cameraCount / localY), 1)
	)
end

function DrawPipeline:draw()
	love.graphics.drawFromShaderIndirect("triangles", self.indirectDrawBuffer)
end

return DrawPipeline
