local PATH = ...
local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Table = require("rat-scratch-common").Table
local IndexBufferInfo = require("rat-scratch-pipeline.IndexBufferInfo")
local MeshletFormat = require("rat-scratch-pipeline.MeshletFormat")
local RatScratchModule = require("lib.rat-scratch-module")
local ShaderPreprocessor = require("rat-scratch-graphics").ShaderPreprocessor
local VertexBufferInfo = require("rat-scratch-pipeline.VertexBufferInfo")
local json = require("lib.json")

--- @class RatScratch.Pipeline.PipelineConfig : RatScratch.Common.BaseObject
--- @overload fun(definition: RatScratch.Pipeline.PipelineDefinitionConfig): RatScratch.Pipeline.PipelineConfig
--- @field private vertexBuffers RatScratch.Pipeline.VertexBufferInfo[]
--- @field private vertexBufferByRole table<RatScratch.Pipeline.PipelineDefinitionVertexBufferRole, RatScratch.Pipeline.VertexBufferInfo[]>
--- @field private vertexBufferToRole table<RatScratch.Pipeline.VertexBufferInfo, RatScratch.Pipeline.PipelineDefinitionVertexBufferRole>
--- @field private indexFormat RatScratch.Pipeline.IndexBufferInfo
--- @field private meshletFormat RatScratch.Pipeline.MeshletFormat
--- @field private definition RatScratch.Pipeline.PipelineDefinitionConfig
--- @field private virtualShaders table<string, string>
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
	self.vertexBufferToRole = {}

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

		self.vertexBufferToRole[buffer] = vertexBuffer.role
	end

	self.indexFormat = IndexBufferInfo(definition.indexBuffer)
	self.meshletFormat = MeshletFormat(definition.meshletFormat)

	self.virtualShaders = {
		["@Pipeline/Generated/Vertex/Vertex.template.glsl"] = self:_loadBaseVertexShader(),
	}

	self.definition = Table.deepClone(definition)
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

--- @return RatScratch.Pipeline.PipelineDefinitionConfig
function PipelineConfig:serialize()
	return { pipeline = Table.deepClone(self.definition) }
end

--- @return table<string, string>
function PipelineConfig:getVirtualShaders()
	return self.virtualShaders
end

--- @param other RatScratch.Pipeline.PipelineConfig
--- @return boolean
function PipelineConfig:isMatch(other)
	if self.definition.version ~= other.definition.version then
		return false
	end

	if
		self.meshletFormat:getTriangleCount()
		~= other.meshletFormat:getTriangleCount()
	then
		return false
	end

	if
		self.indexFormat:getBufferName() ~= other.indexFormat:getBufferName()
	then
		return false
	end

	if
		not self.indexFormat
			:getIndexFormat()
			:isMatch(other.indexFormat:getIndexFormat())
	then
		return false
	end

	if #self.vertexBuffers ~= #other.vertexBuffers then
		return false
	end

	for i = 1, #self.vertexBuffers do
		local selfVertexBuffer = self.vertexBuffers[i]
		local otherVertexBuffer = other.vertexBuffers[i]

		if
			selfVertexBuffer:getBufferName()
			~= otherVertexBuffer:getBufferName()
		then
			return false
		end

		local selfRole = self.vertexBufferToRole[selfVertexBuffer]
		local otherRole = other.vertexBufferToRole[otherVertexBuffer]
		if selfRole ~= otherRole then
			return false
		end

		if
			not (
				selfVertexBuffer
					:getInputFormat()
					:isMatch(otherVertexBuffer:getInputFormat())
				and selfVertexBuffer
					:getVertexFormat()
					:isMatch(otherVertexBuffer:getVertexFormat())
			)
		then
			return false
		end

		local format = selfVertexBuffer:getInputFormat()
		for _, attribute in ipairs(format) do
			local selfUnpackTransform =
				selfVertexBuffer:getUnpackTransform(attribute.name)
			local otherUnpackTransform =
				otherVertexBuffer:getUnpackTransform(attribute.name)

			if selfUnpackTransform ~= otherUnpackTransform then
				return false
			end

			local selfPackTransform =
				selfVertexBuffer:getPackTransform(attribute.name)
			local otherPackTransform =
				otherVertexBuffer:getPackTransform(attribute.name)
			if selfPackTransform ~= otherPackTransform then
				return false
			end
		end
	end

	return true
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

--- @private
--- @return string
function PipelineConfig:_loadBaseVertexShader()
	local variables = {
		RAT_SCRATCH_VERTEX = { RAT_SCRATCH_VERTICES = {} },
		RAT_SCRATCH_BUFFERS = {},
		RAT_SCRATCH_GET_VERTEX_FUNCS = {},
		RAT_SCRATCH_FUNCS_BY_PIPELINE = {
			RAT_SCRATCH_GET_VERTEX_STATIC_FUNCS = {},
			RAT_SCRATCH_GET_VERTEX_SKINNED_FUNCS = {},
		},
	}

	for _, vertexBufferInfo in ipairs(self.vertexBuffers) do
		local vertexFormatInstance = vertexBufferInfo:getVertexFormat()
		local vertexFormat = vertexFormatInstance:getFormat()
		local inputFormatInstance = vertexBufferInfo:getInputFormat()
		local inputFormat = inputFormatInstance:getFormat()

		table.insert(variables.RAT_SCRATCH_BUFFERS, {
			RAT_SCRATCH_BUFFER_NAME = vertexBufferInfo:getBufferName(),
			RAT_SCRATCH_SCALAR_TYPE = inputFormatInstance:getScalarType(
				inputFormat[1].name
			),
		})

		local role = self.vertexBufferToRole[vertexBufferInfo]
		for i, attribute in ipairs(vertexFormat) do
			table.insert(variables.RAT_SCRATCH_VERTEX.RAT_SCRATCH_VERTICES, {
				RAT_SCRATCH_VERTEX_TYPE = vertexFormatInstance:getShaderType(
					attribute.name
				),
				RAT_SCRATCH_VERTEX_NAME = attribute.name,
			})

			local count, offset =
				inputFormatInstance:getCountOffset(inputFormat[i].name)

			local values = {}
			for j = 1, count do
				table.insert(values, {
					RAT_SCRATCH_BUFFER_NAME = vertexBufferInfo:getBufferName(),
					RAT_SCRATCH_BUFFER_OFFSET = j - 1,
				})
			end

			table.insert(variables.RAT_SCRATCH_GET_VERTEX_FUNCS, {
				RAT_SCRATCH_ROLE = inputFormat[i].name,
				RAT_SCRATCH_ATTRIBUTE_NAME = attribute.name,
				RAT_SCRATCH_COMPONENTS_COUNT = inputFormatInstance:getComponentCount(),
				RAT_SCRATCH_ATTRIBUTE_OFFSET = offset - 1,
				RAT_SCRATCH_ATTRIBUTE_TYPE = inputFormatInstance:getShaderType(
					inputFormat[i].name
				),
				RAT_SCRATCH_TRANSFORM_FUNC = vertexBufferInfo:getUnpackTransform(
					inputFormat[i].name
				) or vertexFormatInstance:getShaderType(attribute.name),
				RAT_SCRATCH_ATTRIBUTE_VALUES = values,
			})

			if role == "static" then
				table.insert(
					variables.RAT_SCRATCH_FUNCS_BY_PIPELINE.RAT_SCRATCH_GET_VERTEX_STATIC_FUNCS,
					{
						RAT_SCRATCH_ROLE = inputFormat[i].name,
					}
				)
			else
				table.insert(
					variables.RAT_SCRATCH_FUNCS_BY_PIPELINE.RAT_SCRATCH_GET_VERTEX_SKINNED_FUNCS,
					{
						RAT_SCRATCH_ROLE = inputFormat[i].name,
					}
				)
			end
		end
	end

	local source, result = ShaderPreprocessor.preprocess(
		"@Pipeline/Base/Vertex/Vertex.template.glsl",
		{
			variables = variables,
			rootPath = ("%s/Shaders"):format(
				RatScratchModule.getSelfPath("rat-scratch-graphics")
			),
			rootPaths = {
				Pipeline = ("%s/Shaders"):format(
					RatScratchModule.getSelfPath(PATH)
				),
			},
		}
	)

	local message = result and ShaderPreprocessor.validateResult(source, result)
	if message then
		error(message)
	end

	return source
end

return PipelineConfig
