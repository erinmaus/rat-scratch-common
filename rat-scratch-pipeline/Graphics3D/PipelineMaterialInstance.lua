local PATH = ...
local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local BoneInstance = require("rat-scratch-graphics").Graphics3D.BoneInstance
local Module = require("lib.rat-scratch-module")
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local ShaderPreprocessor = require("rat-scratch-graphics").ShaderPreprocessor
local Transform = require("rat-scratch-math").Transform
local Atlas = require("rat-scratch-graphics").Atlas.Atlas
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")
local EventSource = require("rat-scratch-common").EventSource
local PipelineMaterialInstanceEvent =
	require("rat-scratch-pipeline.Graphics3D.PipelineMaterialInstanceEvent")

--- @class RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance : RatScratch.Common.BaseObject
--- @field private material RatScratch.Pipeline.Graphics3D.PipelineMaterial
--- @field private materialPipeline RatScratch.Pipeline.MaterialPipeline
--- @field private data love.ByteData
--- @field private value number[]
--- @field private eventSource RatScratch.Common.EventSource<RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance>
--- @overload fun(material: RatScratch.Pipeline.Graphics3D.PipelineMaterial, materialPipeline: RatScratch.Pipeline.MaterialPipeline): RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance
local PipelineMaterialInstance = Object()

--- @param material RatScratch.Pipeline.Graphics3D.PipelineMaterial
--- @param materialPipeline RatScratch.Pipeline.MaterialPipeline
function PipelineMaterialInstance:new(material, materialPipeline)
	self.material = material
	self.materialPipeline = materialPipeline

	self.value = {}
	BufferFormat.resetValue(material:getFormat(), self.value)

	for i = 1, material:getUniformCount() do
		local uniform = material:getUniform(i)

		local defaultValue = uniform:getDefaultValue()
		local count, offset =
			material:getFormat():getCountOffset(uniform:getName())

		Table.copy(
			self.value,
			offset,
			offset + count - 1,
			Table.unpack(defaultValue, 1, count)
		)
	end

	self.data = love.data.newByteData(material:getFormat():getStride())
	BufferFormat.copyFromFlatTableToByteData(
		material:getFormat(),
		1,
		0,
		1,
		self.value,
		self.data
	)

	self.eventSource = EventSource()
end

PipelineMaterialInstance.listen, PipelineMaterialInstance.silence =
	EventSource.mixin("eventSource")

function PipelineMaterialInstance:getMaterial()
	return self.material
end

function PipelineMaterialInstance:getData()
	return self.data
end

--- @generic T
--- @param uniformKey string | integer
--- @param value? number[]
--- @return T ...
function PipelineMaterialInstance:getUniformValue(uniformKey, value)
	local uniform = self.material:getUniform(uniformKey)
	if uniform:getFormat() == "texture" then
	end
	local count, offset =
		self.material:getFormat():getCountOffset(uniform:getName())

	if value then
		Table.copy(
			value,
			1,
			count,
			Table.unpack(self.value, offset, offset + count - 1)
		)
	end

	return Table.unpack(self.value, offset, offset + count - 1)
end

--- @param uniformKey string | integer
function PipelineMaterialInstance:unsetUniformValue(uniformKey)
	local uniform = self.material:getUniform(uniformKey)
	self:setUniformByValue(uniformKey, uniform:getDefaultValue())
end

--- @param uniformKey string | integer
--- @param value number[] | love.ImageData
function PipelineMaterialInstance:setUniformByValue(uniformKey, value)
	local uniform = self.material:getUniform(uniformKey)
	local count, offset =
		self.material:getFormat():getCountOffset(uniform:getName())

	local isDirty = false
	if uniform:getFormat() == "texture" then
		local v = self.materialPipeline:getTextureIndex(value)
		if self.value[offset] ~= v then
			self.value[offset] = v
			isDirty = true
		end
	else
		for i = 1, count do
			local j = offset + i - 1
			if self.value[j] ~= value[i] then
				isDirty = true
			end

			self.value[j] = value[i]
		end
	end

	if not isDirty then
		return
	end

	BufferFormat.copyFromFlatTableToByteData(
		self.material:getFormat(),
		1,
		0,
		1,
		self.value,
		self.data
	)

	self.eventSource:process(PipelineMaterialInstanceEvent.fromSet(uniform))
end

--- @param uniformKey string | integer
--- @param ... number[] | love.ImageData
function PipelineMaterialInstance:setUniformByArguments(uniformKey, ...)
	local uniform = self.material:getUniform(uniformKey)
	local count, offset =
		self.material:getFormat():getCountOffset(uniform:getName())

	local isDirty = false
	if uniform:getFormat() == "texture" then
		local t = ...
		local v = self.materialPipeline:getTextureIndex(v)
		if self.value[offset] ~= v then
			self.value[offset] = v
			isDirty = true
		end
	else
		for i = 1, count do
			local j = offset + i - 1
			local v = select(i, ...)

			if self.value[j] ~= v then
				isDirty = true
			end

			self.value[j] = v
		end
	end

	if not isDirty then
		return
	end

	BufferFormat.copyFromFlatTableToByteData(
		self.material:getFormat(),
		1,
		0,
		1,
		self.value,
		self.data
	)

	self.eventSource:process(PipelineMaterialInstanceEvent.fromSet(uniform))
end

return PipelineMaterialInstance
