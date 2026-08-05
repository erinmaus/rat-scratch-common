local ffi = require("ffi")
local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")
local PipelineBufferData =
	require("rat-scratch-graphics.Pipeline3D.PipelineBufferData")

ffi.cdef([[
	void *memcpy(void *dest, const void *src, size_t count);
	void *memset(void *dest, int ch, size_t count);
]])

--- @class RatScratch.Graphics.Pipeline3D.PipelineBufferByteData : RatScratch.Graphics.Pipeline3D.PipelineBufferData
--- @overload fun(format: RatScratch.Graphics.Graphics3D.MeshFormatAttribute[], count: integer): RatScratch.Graphics.Pipeline3D.PipelineBufferByteData
--- @field private count integer
--- @field private bufferData love.ByteData
local PipelineBufferByteData = Object(PipelineBufferData)

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @param count integer
function PipelineBufferByteData:new(format, count)
	PipelineBufferData.new(self, format, count)

	local componentCount = self:getFormat():getComponentCount()
	self.bufferData =
		love.data.newByteData(count * self:getFormat():getStride())
end

function PipelineBufferByteData:resize(newCount)
	local oldCount = self:getCount()
	local format = self:getFormat()
	local componentCount = format:getComponentCount()

	local oldBufferData = self.bufferData
	local newBufferData = love.data.newByteData(newCount * format:getStride())
	ffi.C.memcpy(
		newBufferData:getFFIPointer(),
		oldBufferData:getFFIPointer(),
		oldCount * format:getStride()
	)

	self.bufferData = newBufferData
	oldBufferData:release()

	PipelineBufferData.resize(self, newCount)
end

function PipelineBufferByteData:initialize(index, count)
	local pointer = ffi.cast("uint8_t*", self.bufferData:getFFIPointer())
	local p = pointer
	pointer = pointer + (index - 1) * self:getFormat():getStride()
	assert(
		tonumber(ffi.cast("uint32_t", pointer - p)) < self.bufferData:getSize(),
		"tf"
	)
	assert(
		(index - 1) + count * self:getFormat():getStride()
			< self.bufferData:getSize(),
		"wtf"
	)
	ffi.C.memset(pointer, 0, count * self:getFormat():getStride())
end

do
	local cache = {}

	--- @param index integer
	--- @param count integer
	--- @param ... number
	function PipelineBufferByteData:set(index, count, ...)
		assert(
			count
				== math.floor(
					select("#", ...) / self:getFormat():getComponentCount()
				),
			"count (%d) must equal arguments (%d)",
			index
		)

		local c = cache
		Table.clear(c)
		Table.append(c, ...)

		BufferFormat.copyFromFlatTableToByteData(
			self:getFormat(),
			1,
			(index - 1) * self:getFormat():getStride(),
			count,
			c,
			self.bufferData
		)
	end
end

--- @param index integer
--- @param count integer
--- @param data love.ByteData
--- @param offset? integer
function PipelineBufferByteData:copyFromData(index, count, data, offset)
	offset = offset or 0

	local sourcePointer = ffi.cast("uin8_t*", data:getFFIPointer())
	sourcePointer = sourcePointer + offset

	local destinationPointer =
		ffi.cast("uin8_t*", self.bufferData:getFFIPointer())
	destinationPointer = destinationPointer
		+ (index - 1) * self:getFormat():getStride()

	ffi.C.memcpy(
		destinationPointer,
		sourcePointer,
		count * self:getFormat():getStride()
	)
end

--- @param index integer
--- @param count integer
--- @param data number[]
--- @param offset? integer
function PipelineBufferByteData:copyFromTable(index, count, data, offset)
	offset = offset or 0

	BufferFormat.copyFromFlatTableToByteData(
		self:getFormat(),
		offset,
		(index - 1) * self:getFormat():getStride(),
		count,
		data,
		self.bufferData
	)
end

--- @param buffer love.graphics.GraphicsBuffer
function PipelineBufferByteData:toBuffer(buffer, index, count)
	buffer:setArrayData(self.bufferData, index, index, count)
end

return PipelineBufferByteData
