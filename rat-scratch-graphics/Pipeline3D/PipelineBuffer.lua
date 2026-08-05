local jit = require("jit")
local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Common = require("rat-scratch-math").Common
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")
local PipelineBufferContext =
	require("rat-scratch-graphics.Pipeline3D.PipelineBufferContext")
local PipelineBufferContextEvent =
	require("rat-scratch-graphics.Pipeline3D.PipelineBufferContextEvent")
local PipelineBufferDirtyContext =
	require("rat-scratch-graphics.Pipeline3D.PipelineBufferDirtyContext")

local PipelineBufferData = jit.status()
		and require("rat-scratch-graphics.Pipeline3D.PipelineBufferByteData")
	or require("rat-scratch-graphics.Pipeline3D.PipelineBufferTableData")

--- @class RatScratch.Graphics.Pipeline3D.PipelineBuffer : RatScratch.Common.BaseObject
--- @overload fun(format: RatScratch.Graphics.Graphics3D.MeshFormatAttribute[], flags: table, count?: integer): RatScratch.Graphics.Pipeline3D.PipelineBuffer
--- @field private context RatScratch.Graphics.Pipeline3D.PipelineBufferContext
--- @field private dirtyContext RatScratch.Graphics.Pipeline3D.PipelineBufferDirtyContext
--- @field private data RatScratch.Graphics.Pipeline3D.PipelineBufferData
local PipelineBuffer = Object()

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @param flags table
--- @param count integer
function PipelineBuffer:new(format, flags, count)
	count = 8

	self.format = BufferFormat(format)
	self.flags = flags

	self.context = PipelineBufferContext(count)
	self.context:listen(PipelineBufferContextEvent.RESIZE, self._resize, self)
	self.context:listen(PipelineBufferContextEvent.COMPACT, self._compact, self)

	self.data = PipelineBufferData(format, self.context:getReservedCount())

	self.buffer = love.graphics.newBuffer(
		self.format:getFormat(),
		self.context:getReservedCount(),
		self.flags
	)
	self.dirtyContext = PipelineBufferDirtyContext()
end

function PipelineBuffer:getBuffer()
	return self.buffer
end

function PipelineBuffer:getIsDirty()
	return self.dirtyContext:getIsDirty()
end

function PipelineBuffer:getCount()
	return self.context:getCount()
end

--- @private
--- @param event RatScratch.Graphics.Pipeline3D.PipelineBufferContextEvent
function PipelineBuffer:_resize(event)
	local newCount = event:getNewCount()

	self.data:resize(newCount)
	self.buffer =
		love.graphics.newBuffer(self.format:getFormat(), newCount, self.flags)
	self.dirtyContext:dirty(1, self:getCount())
end

function PipelineBuffer:compact()
	self.context:compact()
end

--- @private
--- @param event RatScratch.Graphics.Pipeline3D.PipelineBufferContextEvent
function PipelineBuffer:_compact(event)
	if event:getOldIndex() == event:getNewIndex() then
		return
	end

	self.data:compact(
		event:getOldIndex(),
		event:getNewIndex(),
		event:getCount()
	)

	self.dirtyContext:dirty(event:getNewIndex(), event:getCount())
end

--- @generic T
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBuffer<T>
--- @param instance T
--- @return boolean
function PipelineBuffer:has(instance)
	return self.context:has(instance)
end

--- @generic T
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBuffer<T>
--- @param instance T
--- @param count integer
function PipelineBuffer:registerOrResize(instance, count)
	self.context:registerOrResize(instance, count)
end

--- @generic T
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBuffer<T>
--- @param instance T
--- @param count integer
function PipelineBuffer:register(instance, count)
	local i, c = self.context:register(instance, count)

	self.data:initialize(i, c)
	self.dirtyContext:dirty(i, c)
end

--- @generic T
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBuffer<T>
--- @param instance T
--- @param newCount integer
function PipelineBuffer:resize(instance, newCount)
	local _, oldCount = self.context:getIndexCount(instance)
	local index, count = self.context:resize(instance, newCount)

	local i = index + oldCount
	local c = index + count - 1

	if c > 0 then
		self.data:initialize(i, count)
	end

	if newCount > oldCount then
		self.dirtyContext:dirty(index + oldCount, count - oldCount)
	end
end

--- @generic T
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBuffer<T>
--- @param instance T
function PipelineBuffer:unregister(instance)
	self.context:unregister(instance)
end

--- @generic T
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBuffer<T>
--- @param instance T
--- @return integer, integer
--- @overload fun(): integer, integer
function PipelineBuffer:getIndexCount(instance)
	return self.context:getIndexCount(instance)
end

--- @generic T
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBuffer<T>
--- @param instance T
--- @param index integer
--- @param count integer
--- @param ... number
function PipelineBuffer:set(instance, index, count, ...)
	local i, c = self:getIndexCount(instance)
	assert(
		index + count - 1 <= c,
		"count (%d) exceeds total (%d) given index %d",
		count,
		c,
		index
	)

	local n = select("#", ...)
	assert(
		Common.isMultipleOf(n, self.format:getComponentCount()),
		"count of values (%d) must be multiple of component count (%d)",
		n,
		self.format:getComponentCount()
	)

	local k = i + index - 1
	self.data:set(k, count, ...)
	self.dirtyContext:dirty(k, count)
end

function PipelineBuffer:flush()
	local count = self.dirtyContext:getDirtyRangeCount()
	for j = 1, count do
		local i, c = self.dirtyContext:getDirtyRangeIndexCount(j)
		if c > 0 then
			self.data:toBuffer(self.buffer, i, c)
		end
	end

	self.dirtyContext:clear()
end

return PipelineBuffer
