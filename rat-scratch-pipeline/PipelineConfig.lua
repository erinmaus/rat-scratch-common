local PATH = ...
local Object = require("rat-scratch-common").Object
local IndexBufferFormat = require("rat-scratch-pipeline.IndexBufferFormat")
local RatScratchModule = require("lib.rat-scratch-module")
local VertexBufferFormat = require("rat-scratch-pipeline.VertexBufferFormat")

--- @class RatScratch.Pipeline.PipelineConfig : RatScratch.Common.BaseObject
--- @overload fun(definition: RatScratch.Pipeline.PipelineDefinitionConfig): RatScratch.Pipeline.PipelineConfig
--- @field private vertexBuffers RatScratch.Pipeline.VertexBufferFormat[]
--- @field private vertexBufferByRole table<RatScratch.Pipeline.PipelineDefinitionVertexBufferRole, RatScratch.Pipeline.VertexBufferFormat[]>
--- @field private indexBuffer RatScratch.Pipeline.IndexBufferFormat
local PipelineConfig = Object()

--- @param definition RatScratch.Pipeline.PipelineDefinitionConfig
function PipelineConfig:new(definition)
	assert(
		RatScratchModule.isCompatible(PATH, definition.version),
		"pipeline config version %s might be incompatible with Rat Scratch Pipeline module version %s",
		definition.version,
		RatScratchModule.getSelfVersion(PATH) or "???"
	)

	self.vertexBuffers = {}
	self.vertexBufferByRole = {}

	for _, vertexBuffer in ipairs(definition.vertexBuffers) do
		for _, otherVertexBuffer in ipairs(self.vertexBuffers) do
			for _, attribute in ipairs(vertexBuffer.format) do
				assert(
					not otherVertexBuffer:hasRole(attribute.role),
					"vertex attribute role %s already configured",
					attribute.role
				)
			end
		end

		local buffer = VertexBufferFormat(vertexBuffer.format)
		table.insert(self.vertexBuffers, buffer)

		local vertexBuffersByRole = self.vertexBufferByRole[vertexBuffer.role]
		if not vertexBuffersByRole then
			vertexBuffersByRole = {}
			self.vertexBufferByRole[vertexBuffer.role] = vertexBuffersByRole
		end

		table.insert(vertexBuffersByRole, buffer)
	end

	self.indexFormat = IndexBufferFormat(definition.indexBuffer)
end

--- @return integer
function PipelineConfig:getVertexFormatCount()
	return #self.vertexBuffers
end

--- @param index integer
--- @return RatScratch.Pipeline.VertexBufferFormat
function PipelineConfig:getVertexFormat(index)
	return self.vertexBuffers[index]
end

--- @param role RatScratch.Pipeline.PipelineDefinitionVertexBufferRole
function PipelineConfig:getVertexFormatCountByRole(role)
	local buffers = self.vertexBufferByRole[role]
	return buffers and #buffers or 0
end

--- @param role RatScratch.Pipeline.PipelineDefinitionVertexBufferRole
--- @param index integer
--- @return RatScratch.Pipeline.VertexBufferFormat
function PipelineConfig:getVertexFormatByRole(role, index)
	local buffers = self.vertexBufferByRole[role]
	return buffers and buffers[index]
end

--- @return RatScratch.Pipeline.IndexBufferFormat
function PipelineConfig:getIndexFormat()
	return self.indexFormat
end

return PipelineConfig
