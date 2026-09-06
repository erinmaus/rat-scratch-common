local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Draw = require("rat-scratch-pipeline.Draw")
local PipelineMultiBuffer =
	require("rat-scratch-pipeline.Buffer.PipelineMultiBuffer")
local Transform = require("rat-scratch-math").Transform

--- @class RatScratch.Pipeline.DrawPipeline : RatScratch.Common.BaseObject
--- @field private drawables table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private dirtyDrawables table<RatScratch.Pipeline.ObjectHandle, true>
--- @field private drawableToDraws table<RatScratch.Pipeline.ObjectHandle, RatScratch.Pipeline.Draw[]>
--- @field private compactDraws boolean
--- @field private indirectDrawBuffer love.GraphicsBuffer
--- @field private camerasBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Camera>
--- @field private drawsBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.ObjectHandle>
--- @overload fun(): RatScratch.Pipeline.DrawPipeline
local DrawPipeline = Object()

DrawPipeline.DRAW_FORMAT = {
	{ location = 0, name = "objectInstanceIndex", format = "uint32" },
	{ location = 1, name = "modelInstanceIndex", format = "uint32" },
	{ location = 2, name = "meshInstanceIndex", format = "uint32" },
	{ location = 3, name = "modelIndex", format = "uint32" },
	{ location = 4, name = "meshIndex", format = "uint32" },
	{ location = 5, name = "meshletIndex", format = "uint32" },
	{ location = 6, name = "staticBaseVertexOffset", format = "uint32" },
	{ location = 7, name = "skinnedBaseVertexOffset", format = "uint32" },
	{ location = 8, name = "boneOffsetCount", format = "uint32vec2" },
	{ location = 9, name = "indexOffset", format = "uint32" },
	{ location = 10, name = "cameraIndex", format = "uint32" },
	{ location = 11, name = "layerIndex", format = "uint32" },
}

DrawPipeline.INDIRECT_DRAW_FORMAT = {
	{ location = 0, name = "vertexCount", format = "uint32" },
	{ location = 1, name = "instanceCount", format = "uint32" },
	{ location = 2, name = "firstVertex", format = "uint32" },
	{ location = 3, name = "firstInstance", format = "uint32" },
}

DrawPipeline.CAMERA_FORMAT = {
	{ location = 0, name = "viewTransform", format = "floatmat4x4" },
	{ location = 1, name = "inverseViewTransform", format = "floatmat4x4" },
	{ location = 2, name = "previousViewTransform", format = "floatmat4x4" },
	{
		location = 3,
		name = "inversePreviousViewTransform",
		format = "floatmat4x4",
	},
	{ location = 4, name = "projectionTransform", format = "floatmat4x4" },
	{
		location = 5,
		name = "inverseProjectionTransform",
		format = "floatmat4x4",
	},
	{ location = 6, name = "projectionViewTransform", format = "floatmat4x4" },
	{
		location = 7,
		name = "inverseProjectionViewTransform",
		format = "floatmat4x4",
	},
	{
		location = 8,
		name = "inverseProjectionViewTransform",
		format = "floatmat4x4",
	},
	{
		location = 9,
		name = "inversePreviousProjectionViewTransform",
		format = "floatmat4x4",
	},
	{ location = 10, name = "position", format = "floatvec4" },
}

DrawPipeline.DEFAULT_CAMERA_COUNT = 64
DrawPipeline.DEFAULT_DRAW_COUNT = 1024 * 16 * DrawPipeline.DEFAULT_CAMERA_COUNT

function DrawPipeline:new()
	self.drawables = {}
	self.dirtyDrawables = {}
	self.drawableToDraws = {}
	self.compactDrawables = false

	self.indirectDrawBuffer = love.graphics.newBuffer(
		DrawPipeline.INDIRECT_DRAW_FORMAT,
		1,
		{ shaderstorage = true, indirectarguments = true }
	)

	self.camerasBuffer = PipelineBuffer(
		DrawPipeline.CAMERA_FORMAT,
		{ shaderstorage = true },
		DrawPipeline.DEFAULT_CAMERA_COUNT
	)

	self.drawsBuffer = PipelineBuffer(
		DrawPipeline.DRAW_FORMAT,
		{ shaderstorage = true },
		DrawPipeline.DEFAULT_DRAW_COUNT
	)
end

--- @param object RatScratch.Pipeline.ObjectHandle
function DrawPipeline:addDrawable(object)
	assert(not self.drawables[object], "object is in drawables list")

	self.drawables[object] = true
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
	assert(
		meshletCount >= 1,
		"meshlet count must be >= 1; got %d",
		meshletCount
	)

	self.drawsBuffer:registerOrResize(object, meshletCount)

	local draws = self.drawableToDraws[object]
	local data = draws and draws[1] and draws[1]:getData()

	draws = Draw.newBatch(meshletCount, data, 1, draws)
	self.drawableToDraws[object] = draws

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

	self.drawsBuffer:copyTable(object, data, 1, #draws, 1)
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
		self.drawsBuffer:compact()
		self.compactDrawables = false
	end

	if next(self.dirtyDrawables) then
		self:_flushDrawables()
	end

	self.drawsBuffer:flush()
end

return DrawPipeline
