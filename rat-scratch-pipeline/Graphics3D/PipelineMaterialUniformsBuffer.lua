local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local assert = require("rat-scratch-common").Debug.assert
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")

--- @class RatScratch.Pipeline.Graphics3D.PipelineMaterialUniformsBuffer : RatScratch.Common.BaseObject
--- @field private material RatScratch.Pipeline.Graphics3D.PipelineMaterial
--- @field private materialPipeline RatScratch.Pipeline.MaterialPipeline
--- @field private integerData love.ByteData
--- @field private floatData love.ByteData
--- @field private integerValue integer[]
--- @field private floatValue number[]
--- @overload fun(material: RatScratch.Pipeline.Graphics3D.PipelineMaterial, materialPipeline: RatScratch.Pipeline.MaterialPipeline): RatScratch.Pipeline.Graphics3D.PipelineMaterialUniformsBuffer
local PipelineMaterialUniformsBuffer = Object()

--- @param material RatScratch.Pipeline.Graphics3D.PipelineMaterial
--- @param materialPipeline RatScratch.Pipeline.MaterialPipeline
function PipelineMaterialUniformsBuffer:new(material, materialPipeline)
	self.material = material
	self.materialPipeline = materialPipeline

	self.integerValues = {}
	self.integerData =
		love.data.newByteData(material:getIntegerFormat():getStride())
	BufferFormat.resetValue(material:getIntegerFormat(), self.integerValues)

	self.floatValues = {}
	self.floatData =
		love.data.newByteData(material:getFloatFormat():getStride())
	BufferFormat.resetValue(material:getFloatFormat(), self.floatValues)

	for i = 1, material:getUniformCount() do
		local uniform = material:getUniform(i)
		self:setUniformByValue(uniform:getName(), uniform:getDefaultValue())
	end
end

function PipelineMaterialUniformsBuffer:getIntegerData()
	return self.integerData
end

function PipelineMaterialUniformsBuffer:getFloatData()
	return self.floatData
end

--- @generic T
--- @param uniformKey string | integer
--- @param value? number[]
--- @return T ...
function PipelineMaterialUniformsBuffer:getUniformValue(uniformKey, value)
	local uniform = self.material:getUniform(uniformKey)
	local selfValue, _, format = self:_getValuesDataFormat(uniform)

	if uniform:getFormat() == "texture" then
		local _, offset = format:getCountOffset(uniform:getName())
		local index = selfValue[offset]
		return self.materialPipeline:getTextureByIndex(index)
	end

	local count, offset = format:getCountOffset(uniform:getName())

	if value then
		Table.copy(
			value,
			1,
			count,
			Table.unpack(selfValue, offset, offset + count - 1)
		)
	end

	return Table.unpack(selfValue, offset, offset + count - 1)
end

--- @private
--- @param uniform RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform
function PipelineMaterialUniformsBuffer:_getValuesDataFormat(uniform)
	if uniform:getIsFloat() then
		return self.floatValues, self.floatData, self.material:getFloatFormat()
	elseif uniform:getIsInteger() then
		return self.integerValues,
			self.integerData,
			self.material:getIntegerFormat()
	end

	assert(
		false,
		"uniform '%s' is neither integer nor float",
		uniform:getName()
	)
end

--- @param uniformKey string | integer
--- @param value number[] | love.ImageData
function PipelineMaterialUniformsBuffer:setUniformByValue(uniformKey, value)
	local uniform = self.material:getUniform(uniformKey)
	local selfValue, data, format = self:_getValuesDataFormat(uniform)

	local count, offset = format:getCountOffset(uniform:getName())

	local isDirty = false
	if uniform:getFormat() == "texture" then
		local v = self.materialPipeline:getTextureIndex(value)
		if selfValue[offset] ~= v then
			selfValue[offset] = v
			isDirty = true
		end
	else
		for i = 1, count do
			local j = offset + i - 1
			if selfValue[j] ~= value[i] then
				isDirty = true
				selfValue[j] = value[i]
			end
		end
	end

	if not isDirty then
		return false
	end

	BufferFormat.copyFromFlatTableToByteData(format, 1, 0, 1, selfValue, data)

	return true
end

--- @param uniformKey string | integer
--- @param ... number | love.ImageData
function PipelineMaterialUniformsBuffer:setUniformByArguments(uniformKey, ...)
	local uniform = self.material:getUniform(uniformKey)
	local value, data, format = self:_getValuesDataFormat(uniform)

	local count, offset = format:getCountOffset(uniform:getName())

	local isDirty = false
	if uniform:getFormat() == "texture" then
		local t = ...
		--- @cast t love.ImageData

		local v = self.materialPipeline:getTextureIndex(t)
		if value[offset] ~= v then
			value[offset] = v
			isDirty = true
		end
	else
		for i = 1, count do
			local j = offset + i - 1
			local v = select(i, ...)
			if value[j] ~= v then
				isDirty = true
			end

			value[j] = v
		end
	end

	if not isDirty then
		return false
	end

	BufferFormat.copyFromFlatTableToByteData(format, 1, 0, 1, value, data)

	return true
end

return PipelineMaterialUniformsBuffer
