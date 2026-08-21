local Object = require("rat-scratch-common").Object
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Table = require("rat-scratch-common").Table
local ffi = require("ffi")

--- @class RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform : RatScratch.Common.BaseObject
--- @field private name string
--- @field private format RatScratch.Pipeline.Graphics3D.PipelineMaterialDefinitionUniformFormat
--- @field private formatInstance RatScratch.Graphics.Graphics3D.BufferFormat
--- @field private offset integer
--- @field private value number[]
--- @field private data love.ByteData
--- @overload fun(name: string, format: RatScratch.Pipeline.Graphics3D.PipelineMaterialDefinitionUniformFormat, value?: number[], offset: integer): RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform
local PipelineMaterialUniform = Object()

--- @param name string
--- @param format RatScratch.Pipeline.Graphics3D.PipelineMaterialDefinitionUniformFormat
--- @param value? number[]
--- @param offset integer
function PipelineMaterialUniform:new(name, format, value, offset)
	self.name = name
	self.format = format
	self.formatInstance = BufferFormat({
		{
			location = 0,
			name = name,
			format = (format == "texture" and "uint32" or format),
		},
	})
	self.offset = offset

	self.value = {}
	do
		local scalar, componentCount
		if self.format == "texture" then
			scalar = "uint32"
			componentCount = 1
		else
			scalar = BufferFormat.getFormatScalar(self.format)
			componentCount = BufferFormat.getFormatComponentCount(self.format)
		end

		for i = 1, componentCount do
			self.value[i] = 0
		end

		if value then
			Table.copy(self.value, 1, #value, Table.unpack(value, 1, #value))
		end

		local scalarSize = BufferFormat.getScalarSize(scalar)

		self.data = love.data.newByteData(scalarSize * componentCount)
		BufferFormat.copyFromFlatTableToByteData(
			self.formatInstance,
			1,
			0,
			componentCount,
			self.value,
			self.data
		)
	end
end

function PipelineMaterialUniform:getName()
	return self.name
end

function PipelineMaterialUniform:getFormat()
	return self.format
end

function PipelineMaterialUniform:getDefaultValue()
	return self.value
end

function PipelineMaterialUniform:getDefaultValueData()
	return self.data
end

function PipelineMaterialUniform:getOffset()
	return self.offset
end

--- @param data love.Data
--- @param offset integer
function PipelineMaterialUniform:set(data, offset)
	offset = offset + self.offset

	ffi.copy(
		ffi.cast("uint8_t *", data:getFFIPointer()) + offset,
		self.data,
		self.data:getSize()
	)
end

return PipelineMaterialUniform
