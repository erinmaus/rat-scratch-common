local ffi = require("ffi")
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local PipelineBufferData =
	require("rat-scratch-pipeline.Buffer.PipelineBufferData")

--- @class RatScratch.Pipeline.Buffer.PipelineBufferByteData : RatScratch.Pipeline.Buffer.PipelineBufferData
--- @overload fun(format: RatScratch.Graphics.Graphics3D.MeshFormatAttribute[], count: integer): RatScratch.Pipeline.Buffer.PipelineBufferByteData
--- @field private count integer
--- @field private bufferData love.ByteData
local PipelineBufferByteData = Object(PipelineBufferData)

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @param count integer
function PipelineBufferByteData:new(format, count)
	PipelineBufferData.new(self, format, count)

	self.bufferData =
		love.data.newByteData(count * self:getFormat():getStride())
end

function PipelineBufferByteData:resize(newCount)
	local oldCount = self:getCount()
	local format = self:getFormat()

	local oldBufferData = self.bufferData
	local newBufferData = love.data.newByteData(newCount * format:getStride())
	ffi.copy(
		newBufferData:getFFIPointer(),
		oldBufferData:getFFIPointer(),
		oldCount * format:getStride()
	)

	self.bufferData = newBufferData
	oldBufferData:release()

	PipelineBufferData.resize(self, newCount)
end

function PipelineBufferByteData:initialize(index, count)
	local pointer = ffi.cast("uint8_t *", self.bufferData:getFFIPointer())
	pointer = pointer + (index - 1) * self:getFormat():getStride()
	ffi.fill(pointer, count * self:getFormat():getStride(), 0)
end

do
	local cache = {}

	--- @param index integer
	--- @param count integer
	--- @param ... number
	function PipelineBufferByteData:set(index, count, ...)
		local c = cache
		Table.copy(c, 1, count * self:getFormat():getComponentCount(), ...)

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

	local sourcePointer = ffi.cast("uint8_t *", data:getFFIPointer())
	sourcePointer = sourcePointer + offset

	local destinationPointer =
		ffi.cast("uint8_t *", self.bufferData:getFFIPointer())
	destinationPointer = destinationPointer
		+ (index - 1) * self:getFormat():getStride()

	ffi.copy(
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
	offset = offset or 1

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
