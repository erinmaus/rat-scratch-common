local jit = require("jit")
local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Common = require("rat-scratch-math").Common
local PipelineBufferContext =
	require("rat-scratch-pipeline.Buffer.PipelineBufferContext")
local PipelineBufferContextEvent =
	require("rat-scratch-pipeline.Buffer.PipelineBufferContextEvent")
local PipelineBufferDirtyContext =
	require("rat-scratch-pipeline.Buffer.PipelineBufferDirtyContext")

local PipelineBufferData = jit.status()
		and require("rat-scratch-pipeline.Buffer.PipelineBufferByteData")
	or require("rat-scratch-pipeline.Buffer.PipelineBufferTableData")

--- @class RatScratch.Pipeline.Buffer.PipelineBuffer : RatScratch.Common.BaseObject
--- @overload fun(format: RatScratch.Graphics.Graphics3D.MeshFormatAttribute[], flags: table, count?: integer): RatScratch.Pipeline.Buffer.PipelineBuffer
--- @field private context RatScratch.Pipeline.Buffer.PipelineBufferContext
--- @field private dirtyContext RatScratch.Pipeline.Buffer.PipelineBufferDirtyContext
--- @field private data RatScratch.Pipeline.Buffer.PipelineBufferData
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

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineBuffer<T>
--- @param instance T
--- @return RatScratch.Pipeline.Buffer.PipelinePointer<T>
function PipelineBuffer:newPointer(instance)
	return self.context:newPointer(instance)
end

--- @private
--- @param event RatScratch.Pipeline.Buffer.PipelineBufferContextEvent
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
--- @param event RatScratch.Pipeline.Buffer.PipelineBufferContextEvent
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
--- @param self RatScratch.Pipeline.Buffer.PipelineBuffer<T>
--- @param instance T
--- @return boolean
function PipelineBuffer:has(instance)
	return self.context:has(instance)
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineBuffer<T>
--- @param instance T
--- @param count integer
function PipelineBuffer:registerOrResize(instance, count)
	self.context:registerOrResize(instance, count)
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineBuffer<T>
--- @param instance T
--- @param count integer
function PipelineBuffer:register(instance, count)
	local i, c = self.context:register(instance, count)

	self.data:initialize(i, c)
	self.dirtyContext:dirty(i, c)
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineBuffer<T>
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
--- @param self RatScratch.Pipeline.Buffer.PipelineBuffer<T>
--- @param instance T
function PipelineBuffer:unregister(instance)
	self.context:unregister(instance)
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineBuffer<T>
--- @param instance T
--- @param table number[]
--- @param index? integer
--- @param count? integer
--- @param tableIndex? integer
function PipelineBuffer:copyTable(instance, table, index, count, tableIndex)
	local i, maxCount = self.context:getIndexCount(instance)

	index = i + math.min(index or 1, maxCount) - 1
	count = count or math.floor((#table / self.format:getComponentCount()))
	tableIndex = tableIndex or 1

	self.data:copyFromTable(
		index,
		Common.clamp(count, 0, maxCount - index + 1),
		table,
		tableIndex
	)
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineBuffer<T>
--- @param instance T
--- @param data love.Data
--- @param index? integer
--- @param count? integer
--- @param offset? integer
function PipelineBuffer:copyData(instance, data, index, count, offset)
	local i, maxCount = self.context:getIndexCount(instance)

	index = i + math.min(index or 1, maxCount) - 1
	count = count or math.floor(data:getSize() / self.format:getStride())
	offset = offset or 0

	self.data:copyFromData(
		index,
		Common.clamp(count, 0, maxCount - index + 1),
		data,
		offset
	)
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineBuffer<T>
--- @param instance T
--- @param index? integer
--- @param count? integer
function PipelineBuffer:clear(instance, index, count)
	index = index or 1
	local _, maxCount = self.context:getIndexCount(instance)

	index = Common.clamp(index, 1, maxCount)
	count = Common.clamp(count or 1, 0, maxCount - index + 1)

	self.data:initialize(index, count)
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineBuffer<T>
--- @param instance T
--- @return integer, integer
--- @overload fun(): integer, integer
function PipelineBuffer:getIndexCount(instance)
	return self.context:getIndexCount(instance)
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineBuffer<T>
--- @param instance T
--- @param index integer
--- @param count integer
--- @param ... number
function PipelineBuffer:set(instance, index, count, ...)
	local i = self:getIndexCount(instance)

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
