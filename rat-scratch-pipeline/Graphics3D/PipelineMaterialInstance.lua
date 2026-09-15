local Object = require("rat-scratch-common").Object
local EventSource = require("rat-scratch-common").EventSource
local PipelineMaterialInstanceEvent =
	require("rat-scratch-pipeline.Graphics3D.PipelineMaterialInstanceEvent")
local PipelineMaterialUniformsBuffer =
	require("rat-scratch-pipeline.Graphics3D.PipelineMaterialUniformsBuffer")

--- @class RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance : RatScratch.Common.BaseObject
--- @field private material RatScratch.Pipeline.Graphics3D.PipelineMaterial
--- @field private materialPipeline RatScratch.Pipeline.MaterialPipeline
--- @field private parent? RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance
--- @field private uniformsBuffer RatScratch.Pipeline.Graphics3D.PipelineMaterialUniformsBuffer
--- @field private eventSource RatScratch.Common.EventSource<RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance>
--- @overload fun(material: RatScratch.Pipeline.Graphics3D.PipelineMaterial, materialPipeline: RatScratch.Pipeline.MaterialPipeline): RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance
local PipelineMaterialInstance = Object()

--- @param material RatScratch.Pipeline.Graphics3D.PipelineMaterial
--- @param materialPipeline RatScratch.Pipeline.MaterialPipeline
function PipelineMaterialInstance:new(material, materialPipeline)
	self.material = material
	self.materialPipeline = materialPipeline
	self.uniformsBuffer =
		PipelineMaterialUniformsBuffer(material, materialPipeline)

	if material:getParentName() then
		self.parent = PipelineMaterialInstance(
			materialPipeline:getMaterialByName(material:getParentName()),
			materialPipeline
		)
	end

	self.eventSource = EventSource()
end

PipelineMaterialInstance.listen, PipelineMaterialInstance.silence =
	EventSource.mixin("eventSource")

function PipelineMaterialInstance:getMaterial()
	return self.material
end

function PipelineMaterialInstance:getParent()
	return self.parent
end

function PipelineMaterialInstance:getUniformsBuffer()
	return self.uniformsBuffer
end

--- @param uniformKey string | integer
function PipelineMaterialInstance:hasUniformValue(uniformKey)
	if self.material:hasUniform(uniformKey) then
		return true
	end

	if not self.parent then
		return false
	end

	return self.parent:hasUniformValue(uniformKey)
end

--- @generic T
--- @param uniformKey string | integer
--- @param value? number[]
--- @return T ...
function PipelineMaterialInstance:getUniformValue(uniformKey, value)
	if self.parent:hasUniformValue(uniformKey) then
		return self.parent:getUniformValue(uniformKey, value)
	end

	return self.uniformsBuffer:getUniformValue(uniformKey, value)
end

--- @param uniformKey string | integer
function PipelineMaterialInstance:unsetUniformValue(uniformKey)
	if self.parent:hasUniformValue(uniformKey) then
		self.parent:unsetUniformValue(uniformKey)
		return
	end

	if not self.material:hasUniform(uniformKey) then
		return
	end

	local uniform = self.material:getUniform(uniformKey)
	self:setUniformByValue(uniformKey, uniform:getDefaultValue())
end

--- @param uniformKey string | integer
--- @param value number[] | love.ImageData
function PipelineMaterialInstance:setUniformByValue(uniformKey, value)
	if
		self.uniformsBuffer:setUniformByValue(uniformKey, value)
		or (
			self.parent
			and self.parent:hasUniformValue(uniformKey)
			and self.parent:setUniformByValue(uniformKey, value)
		)
	then
		self.eventSource:process(
			PipelineMaterialInstanceEvent.fromSet(
				self.material:getUniform(uniformKey)
			)
		)
	end
end

--- @param uniformKey string | integer
--- @param ... number[] | love.ImageData
function PipelineMaterialInstance:setUniformByArguments(uniformKey, ...)
	if
		self.uniformsBuffer:setUniformByArguments(uniformKey, ...)
		or (
			self.parent
			and self.parent:hasUniformValue(uniformKey)
			and self.parent:setUniformByArguments(uniformKey, ...)
		)
	then
		self.eventSource:process(
			PipelineMaterialInstanceEvent.fromSet(
				self.material:getUniform(uniformKey)
			)
		)
	end
end

return PipelineMaterialInstance
