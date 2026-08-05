local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")
local PipelineBufferData =
	require("rat-scratch-graphics.Pipeline3D.PipelineBufferData")

--- @class RatScratch.Graphics.Pipeline3D.PipelineBufferTableData : RatScratch.Graphics.Pipeline3D.PipelineBufferData
--- @overload fun(format: RatScratch.Graphics.Graphics3D.MeshFormatAttribute[], count: integer): RatScratch.Graphics.Pipeline3D.PipelineBufferTableData
--- @field private count integer
--- @field private bufferData number[][]
local PipelineBufferTableData = Object(PipelineBufferData)

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @param count integer
function PipelineBufferTableData:new(format, count)
	PipelineBufferData.new(self, format, count)

	local componentCount = self:getFormat():getComponentCount()
	self.bufferData = Table.new(count * componentCount, 0)

	for i = 1, count do
		BufferFormat.resetValue(
			format,
			self.bufferData,
			(i - 1) * componentCount
		)
	end
end

function PipelineBufferTableData:resize(newCount)
	local oldCount = self:getCount()
	local format = self:getFormat()
	local componentCount = format:getComponentCount()

	for i = oldCount + 1, newCount do
		BufferFormat.resetValue(
			format,
			self.bufferData,
			(i - 1) * componentCount
		)
	end

	PipelineBufferData.resize(self, newCount)
end

--- @param index integer
--- @param count integer
function PipelineBufferTableData:initialize(index, count)
	local format = self:getFormat()
	local componentCount = format:getComponentCount()

	for i = 1, count do
		BufferFormat.resetValue(
			format,
			self.bufferData,
			((i - 1) + (index - 1)) * componentCount
		)
	end
end

--- @param index integer
--- @param count integer
--- @param ... number
function PipelineBufferTableData:set(index, count, ...)
	local componentIndex =
		Table.indexToStride(index, self:getFormat():getComponentCount())

	Table.copy(
		self.bufferData,
		componentIndex,
		componentIndex + count * self:getFormat():getComponentCount() - 1,
		...
	)
end

--- @param index integer
--- @param count integer
--- @param data love.ByteData
--- @param offset? integer
function PipelineBufferTableData:copyFromData(index, count, data, offset)
	offset = offset or 0

	BufferFormat.copyFromByteDataToFlatTable(
		self:getFormat(),
		offset,
		index,
		count,
		data,
		self.bufferData
	)
end

--- @param index integer
--- @param count integer
--- @param data number[]
--- @param offset? integer
function PipelineBufferTableData:copyFromTable(index, count, data, offset)
	offset = offset or 0

	local componentCount = self:getFormat():getComponentCount()
	Table.transfer(
		self.bufferData,
		data,
		count * componentCount,
		Table.indexToStride(index, componentCount),
		offset
	)
end

--- @param buffer love.graphics.GraphicsBuffer
function PipelineBufferTableData:toBuffer(buffer, index, count)
	buffer:setArrayData(self.bufferData, index, index, count)
end

return PipelineBufferTableData
