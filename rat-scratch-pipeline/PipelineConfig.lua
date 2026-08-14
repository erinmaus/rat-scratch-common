local PATH = ...
local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local IndexBufferInfo = require("rat-scratch-pipeline.IndexBufferInfo")
local MeshletFormat = require("rat-scratch-pipeline.MeshletFormat")
local RatScratchModule = require("lib.rat-scratch-module")
local VertexBufferInfo = require("rat-scratch-pipeline.VertexBufferInfo")
local json = require("lib.json")

--- @class RatScratch.Pipeline.PipelineConfig : RatScratch.Common.BaseObject
--- @overload fun(definition: RatScratch.Pipeline.PipelineDefinitionConfig): RatScratch.Pipeline.PipelineConfig
--- @field private vertexBuffers RatScratch.Pipeline.VertexBufferInfo[]
--- @field private vertexBufferByRole table<RatScratch.Pipeline.PipelineDefinitionVertexBufferRole, RatScratch.Pipeline.VertexBufferInfo[]>
--- @field private indexBuffer RatScratch.Pipeline.IndexBufferInfo
--- @field private meshletFormat RatScratch.Pipeline.MeshletFormat
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
					not otherVertexBuffer
						:getInputFormat()
						:hasAttribute(attribute.role),
					"vertex attribute role %s already configured",
					attribute.role
				)
			end
		end

		local buffer = VertexBufferInfo(vertexBuffer)
		table.insert(self.vertexBuffers, buffer)

		local vertexBuffersByRole = self.vertexBufferByRole[vertexBuffer.role]
		if not vertexBuffersByRole then
			vertexBuffersByRole = {}
			self.vertexBufferByRole[vertexBuffer.role] = vertexBuffersByRole
		end

		table.insert(vertexBuffersByRole, buffer)
	end

	self.indexFormat = IndexBufferInfo(definition.indexBuffer)
	self.meshletFormat = MeshletFormat(definition.meshletFormat)
end

function PipelineConfig:getMeshletFormat()
	return self.meshletFormat
end

--- @return integer
function PipelineConfig:getVertexFormatCount()
	return #self.vertexBuffers
end

--- @param index integer
--- @return RatScratch.Pipeline.VertexBufferInfo
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
--- @return RatScratch.Pipeline.VertexBufferInfo
function PipelineConfig:getVertexFormatByRole(role, index)
	local buffers = self.vertexBufferByRole[role]
	return buffers and buffers[index]
end

--- @return RatScratch.Pipeline.IndexBufferInfo
function PipelineConfig:getIndexFormat()
	return self.indexFormat
end

function PipelineConfig.loadDefault()
	local path = RatScratchModule.getSelfPath(PATH)
	local defaultConfigFilename = ("%s/Config/Default/Pipeline.json"):format(
		path
	)
	local defaultConfigData = love.filesystem.read(defaultConfigFilename)

	assert(
		defaultConfigData,
		"could not load default config at path '%s'",
		defaultConfigFilename
	)

	--- @type RatScratch.Pipeline.PipelineDefinition
	local defaultConfigJson = json.decode(defaultConfigData)

	return PipelineConfig(defaultConfigJson.pipeline)
end

return PipelineConfig
