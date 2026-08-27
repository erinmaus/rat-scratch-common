local jit = require("jit")
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

--- @class RatScratch.Pipeline.Buffer.PipelineMultiBuffer : RatScratch.Common.BaseObject
--- @overload fun(formats: RatScratch.Graphics.Graphics3D.MeshFormatAttribute[][], flags: table, count?: integer): RatScratch.Pipeline.Buffer.PipelineMultiBuffer
--- @field private bufferCount integer
--- @field private flags table
--- @field private formats RatScratch.Graphics.Graphics3D.BufferFormat[]
--- @field private data RatScratch.Pipeline.Buffer.PipelineBufferData[]
--- @field private buffers love.graphics.GraphicsBuffer[]
--- @field private context RatScratch.Pipeline.Buffer.PipelineBufferContext
--- @field private dirtyContext RatScratch.Pipeline.Buffer.PipelineBufferDirtyContext
local PipelineMultiBuffer = Object()

--- @param formats RatScratch.Graphics.Graphics3D.MeshFormatAttribute[][]
--- @param flags table
--- @param count integer
function PipelineMultiBuffer:new(formats, flags, count)
	self.flags = flags

	self.bufferCount = #formats

	self.context = PipelineBufferContext(count)
	self.context:listen(PipelineBufferContextEvent.RESIZE, self._resize, self)
	self.context:listen(PipelineBufferContextEvent.COMPACT, self._compact, self)

	self.formats = {}
	self.buffers = {}
	self.data = {}
	for _, format in ipairs(formats) do
		table.insert(self.formats, BufferFormat(format))
		table.insert(
			self.data,
			PipelineBufferData(format, self.context:getReservedCount())
		)
		table.insert(
			self.data,
			love.graphics.newBuffer(
				format,
				self.context:getReservedCount(),
				self.flags
			)
		)
	end

	self.dirtyContext = PipelineBufferDirtyContext()
end

function PipelineMultiBuffer:getBufferCount(index)
	return self.bufferCount
end

function PipelineMultiBuffer:getData(index)
	return self.data[index]
end

function PipelineMultiBuffer:getFormat(index)
	return self.formats[index]
end

function PipelineMultiBuffer:getBuffer(index)
	return self.buffers[index]
end

function PipelineMultiBuffer:getIsDirty()
	return self.dirtyContext:getIsDirty()
end

function PipelineMultiBuffer:getCount()
	return self.context:getCount()
end

--- @private
--- @param event RatScratch.Pipeline.Buffer.PipelineBufferContextEvent
function PipelineMultiBuffer:_resize(event)
	local newCount = event:getNewCount()

	for i = 1, self.bufferCount do
		self.data[i]:resize(newCount)
		self.buffers[i] = love.graphics.newBuffer(
			self.formats[i]:getFormat(),
			newCount,
			self.flags
		)
	end

	self.dirtyContext:dirty(1, self:getCount())
end

function PipelineMultiBuffer:compact()
	self.context:compact()
end

--- @private
--- @param event RatScratch.Pipeline.Buffer.PipelineBufferContextEvent
function PipelineMultiBuffer:_compact(event)
	if event:getOldIndex() == event:getNewIndex() then
		return
	end

	for i = 1, #self.data do
		self.data[i]:compact(
			event:getOldIndex(),
			event:getNewIndex(),
			event:getCount()
		)
	end

	self.dirtyContext:dirty(event:getNewIndex(), event:getCount())
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineMultiBuffer<T>
--- @param instance T
--- @return boolean
function PipelineMultiBuffer:has(instance)
	return self.context:has(instance)
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineMultiBuffer<T>
--- @param instance T
--- @param count integer
function PipelineMultiBuffer:registerOrResize(instance, count)
	self.context:registerOrResize(instance, count)
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineMultiBuffer<T>
--- @param instance T
--- @param count integer
function PipelineMultiBuffer:register(instance, count)
	local i, c = self.context:register(instance, count)

	for j = 1, #self.bufferCount do
		self.data[j]:initialize(i, c)
	end

	self.dirtyContext:dirty(i, c)
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineMultiBuffer<T>
--- @param instance T
--- @param newCount integer
function PipelineMultiBuffer:resize(instance, newCount)
	local _, oldCount = self.context:getIndexCount(instance)
	local index, count = self.context:resize(instance, newCount)

	local i = index + oldCount
	local c = index + count - 1

	if c > 0 then
		for j = 1, #self.bufferCount do
			self.data[j]:initialize(i, c)
		end
	end

	if newCount > oldCount then
		self.dirtyContext:dirty(index + oldCount, count - oldCount)
	end
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineMultiBuffer<T>
--- @param instance T
function PipelineMultiBuffer:unregister(instance)
	self.context:unregister(instance)
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineMultiBuffer<T>
--- @param instance T
--- @return integer, integer
--- @overload fun(): integer, integer
function PipelineMultiBuffer:getIndexCount(instance)
	return self.context:getIndexCount(instance)
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineMultiBuffer<T>
--- @param buffer integer
--- @param instance T
--- @param index integer
--- @param count integer
--- @param ... number
function PipelineMultiBuffer:set(buffer, instance, index, count, ...)
	local i = self:getIndexCount(instance)

	local k = i + index - 1
	self.data[k]:set(k, count, ...)
	self.dirtyContext:dirty(k, count)
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineMultiBuffer<T>
--- @param buffer integer
--- @param instance T
--- @param data love.Data
--- @param index? integer
--- @param count? integer
--- @param offset? integer
function PipelineMultiBuffer:copyData(
	buffer,
	instance,
	data,
	index,
	count,
	offset
)
	local _, maxCount = self.context:getIndexCount(instance)

	index = index or 0
	count = count or data:getSize() / self.formats[buffer]:getStride()
	offset = offset or 0

	self.data[buffer]:copyFromData(
		index,
		math.min(count, maxCount),
		data,
		offset
	)
end

--- @generic T
--- @param self RatScratch.Pipeline.Buffer.PipelineMultiBuffer<T>
--- @param buffer integer
--- @param instance T
--- @param index? integer
--- @param count? integer
function PipelineMultiBuffer:clear(buffer, instance, index, count)
	index = index or 1
	local _, maxCount = self.context:getIndexCount(instance)

	index = Common.clamp(index, 1, maxCount)
	count = Common.clamp(index, 0, maxCount - index + 1)

	self.data[buffer]:initialize(index, count)
end

function PipelineMultiBuffer:flush()
	local count = self.dirtyContext:getDirtyRangeCount()
	for j = 1, count do
		local i, c = self.dirtyContext:getDirtyRangeIndexCount(j)
		if c > 0 then
			for k = 1, self.bufferCount do
				self.data[k]:toBuffer(self.buffers[k], i, c)
			end
		end
	end

	self.dirtyContext:clear()
end

return PipelineMultiBuffer
