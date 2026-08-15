local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Table = require("rat-scratch-common").Table
local Mesh = require("rat-scratch-graphics").Graphics3D.Mesh
local ExtendedMesh = require("rat-scratch-pipeline-tools.Model.ExtendedMesh")
local ExtendedMeshMeshlet =
	require("rat-scratch-pipeline-tools.Model.ExtendedMeshMeshlet")
local MeshOptimizerFFI =
	require("rat-scratch-pipeline-tools.impl.MeshOptimizerFFI")
local RSTangentFFI = require("rat-scratch-pipeline-tools.impl.RSTangentFFI")
local ffi = require("ffi")

--- @class RatScratch.Pipeline.ExtendedModel : RatScratch.Common.BaseObject
--- @overload fun(parser: RatScratch.GLTF.GLTFParser, meshIndex: integer): RatScratch.Pipeline.ExtendedModel
--- @field private parser RatScratch.GLTF.GLTFParser
--- @field private meshDefinitions RatScratch.Graphics.Graphics3D.MeshDefinition[]
--- @field private meshes RatScratch.Pipeline.ExtendedMesh[]
--- @field private meshIndex integer
local ExtendedModel = Object()

--- @param parser RatScratch.GLTF.GLTFParser
--- @param meshIndex integer
function ExtendedModel:new(parser, meshIndex)
	self.parser = parser
	self.meshIndex = meshIndex
	self.meshDefinitions = self.parser:loadMesh(meshIndex) or {}
	self.meshes = {}
end

function ExtendedModel:getMeshIndex()
	return self.meshIndex
end

function ExtendedModel:getMeshCount()
	return #self.meshDefinitions
end

--- @param index integer
--- @return RatScratch.Graphics.Graphics3D.MeshDefinition
function ExtendedModel:getMeshDefinition(index)
	return self.meshDefinitions[index]
end

--- @param index integer
--- @return RatScratch.Pipeline.ExtendedMesh
function ExtendedModel:getMesh(index)
	return self.meshes[index]
end

ExtendedModel.POSITION_FORMAT = {
	{ location = 0, name = "VertexPosition", format = "floatvec3" },
}

ExtendedModel.POSITION_FORMAT_INSTANCE =
	BufferFormat(ExtendedModel.POSITION_FORMAT, true)

ExtendedModel.TEXTURE_COORDINATE_FORMAT = {
	{ location = 1, name = "VertexTexCoord", format = "floatvec2" },
}

ExtendedModel.TEXTURE_COORDINATE_FORMAT_INSTANCE =
	BufferFormat(ExtendedModel.TEXTURE_COORDINATE_FORMAT, true)

ExtendedModel.NORMAL_FORMAT = {
	{ location = 10, name = "VertexNormal", format = "floatvec3" },
}

ExtendedModel.NORMAL_FORMAT_INSTANCE =
	BufferFormat(ExtendedModel.NORMAL_FORMAT, true)

ExtendedModel.TANGENT_FORMAT = {
	{ location = 11, name = "VertexTangent", format = "floatvec4" },
}

ExtendedModel.TANGENT_FORMAT_INSTANCE =
	BufferFormat(ExtendedModel.TANGENT_FORMAT, true)

--- @private
--- @param pipelineConfig RatScratch.Pipeline.PipelineConfig
--- @param mesh RatScratch.Pipeline.ExtendedMesh
--- @param meshDefinition RatScratch.Graphics.Graphics3D.MeshDefinition
--- @param role string
function ExtendedModel:_transformVertexData(
	pipelineConfig,
	mesh,
	meshDefinition,
	role,
	indexData
)
	local meshFormat = BufferFormat.get(meshDefinition.format)

	local hasTangent = false
	local hasPosition = meshFormat:hasAttribute("VertexPosition")
	local hasTexture = meshFormat:hasAttribute("VertexTexCoord")
	local hasNormal = meshFormat:hasAttribute("VertexNormal")
	for i = 1, pipelineConfig:getVertexFormatCountByRole(role) do
		local vertexBufferInfo = pipelineConfig:getVertexFormatByRole(role, i)
		if vertexBufferInfo:getInputFormat():hasAttribute("VertexTangent") then
			hasTangent = true
			break
		end
	end

	local tangentInputs
	if
		not meshFormat:hasAttribute("VertexTangent")
		and hasTangent
		and hasPosition
		and hasTexture
		and hasNormal
	then
		tangentInputs = {
			VertexPosition = {
				data = {},
				format = ExtendedModel.POSITION_FORMAT_INSTANCE,
			},
			VertexTexCoord = {
				data = {},
				format = ExtendedModel.TEXTURE_COORDINATE_FORMAT_INSTANCE,
			},
			VertexNormal = {
				data = {},
				format = ExtendedModel.NORMAL_FORMAT_INSTANCE,
			},
		}
	end

	local vertexFormatCount = pipelineConfig:getVertexFormatCountByRole(role)
	local tangentOutputVertexData, tangentByteData, tangentVertexBufferInfo
	for i = 1, vertexFormatCount do
		local vertexBufferInfo = pipelineConfig:getVertexFormatByRole(role, i)
		local byteDataSize = vertexBufferInfo:getInputFormat():getStride()
			* #meshDefinition.vertices
		local byteData = love.data.newByteData(byteDataSize)

		local vertexFormat = vertexBufferInfo:getInputFormat()
		local attributeCount = #vertexFormat:getFormat()
		local outputVertexData = Table.new(
			#meshDefinition.vertices * vertexFormat:getComponentCount(),
			0
		)
		for i = 1, #meshDefinition.vertices do
			BufferFormat.resetValue(
				vertexFormat,
				outputVertexData,
				(i - 1) * vertexFormat:getComponentCount()
			)
		end

		for j = 1, attributeCount do
			local attribute = vertexFormat:getFormat()[j]
			if meshFormat:hasAttribute(attribute.name) then
				local vc, vi = meshFormat:getCountOffset(attribute.name)
				local vj = vi + vc - 1

				local nc, ni = vertexFormat:getCountOffset(attribute.name)
				local nj = ni + nc - 1

				for k = 1, #meshDefinition.vertices do
					local inputVertex = meshDefinition.vertices[k]
					local o = (k - 1) * vertexFormat:getComponentCount()

					Table.copy(
						outputVertexData,
						ni + o,
						nj + o,
						vertexBufferInfo:pack(
							attribute.name,
							meshFormat:getExpandedValues(
								attribute.name,
								Table.unpack(inputVertex, vi, vj)
							)
						)
					)
				end
			else
				for k = 1, #meshDefinition.vertices do
					Table.append(
						outputVertexData,
						vertexBufferInfo:pack(
							attribute.name,
							vertexFormat:getExpandedValues(attribute.name)
						)
					)
				end
			end

			if attribute.name == "VertexTangent" then
				tangentOutputVertexData = outputVertexData
				tangentByteData = byteData
				tangentVertexBufferInfo = vertexBufferInfo
			end

			if tangentInputs and tangentInputs[attribute.name] then
				local vc, vi = meshFormat:getCountOffset(attribute.name)
				local vj = vi + vc - 1

				local outputs = tangentInputs[attribute.name].data
				local outputFormat = tangentInputs[attribute.name].format

				for k = 1, #meshDefinition.vertices do
					local inputVertex = meshDefinition.vertices[k]
					Table.append(
						outputs,
						outputFormat:getExpandedValues(
							attribute.name,
							Table.unpack(inputVertex, vi, vj)
						)
					)
				end
			end
		end

		BufferFormat.copyFromFlatTableToByteData(
			vertexFormat,
			1,
			0,
			#meshDefinition.vertices,
			outputVertexData,
			byteData
		)

		mesh:addVertexAttributeBuffer(vertexBufferInfo, byteData)
	end

	if tangentInputs and tangentOutputVertexData and tangentByteData then
		local positionData = love.data.newByteData(
			#meshDefinition.vertices
				* ExtendedModel.POSITION_FORMAT_INSTANCE:getStride()
		)

		BufferFormat.copyFromFlatTableToByteData(
			ExtendedModel.POSITION_FORMAT_INSTANCE,
			1,
			0,
			#meshDefinition.vertices,
			tangentInputs.VertexPosition.data,
			positionData
		)

		local normalData = love.data.newByteData(
			#meshDefinition.vertices
				* ExtendedModel.NORMAL_FORMAT_INSTANCE:getStride()
		)

		BufferFormat.copyFromFlatTableToByteData(
			ExtendedModel.NORMAL_FORMAT_INSTANCE,
			1,
			0,
			#meshDefinition.vertices,
			tangentInputs.VertexNormal.data,
			normalData
		)

		local textureCoordinateData = love.data.newByteData(
			#meshDefinition.vertices
				* ExtendedModel.TEXTURE_COORDINATE_FORMAT_INSTANCE:getStride()
		)

		BufferFormat.copyFromFlatTableToByteData(
			ExtendedModel.TEXTURE_COORDINATE_FORMAT_INSTANCE,
			1,
			0,
			#meshDefinition.vertices,
			tangentInputs.VertexTexCoord.data,
			textureCoordinateData
		)

		local success, tangents = RSTangentFFI.buildTangents(
			indexData,
			#meshDefinition.indices,
			#meshDefinition.vertices,
			positionData,
			ExtendedModel.POSITION_FORMAT_INSTANCE,
			normalData,
			ExtendedModel.NORMAL_FORMAT_INSTANCE,
			textureCoordinateData,
			ExtendedModel.TEXTURE_COORDINATE_FORMAT_INSTANCE
		)

		assert(success, "could not generate tangents")

		local tangentData = {}
		BufferFormat.copyFromByteDataToFlatTable(
			ExtendedModel.TANGENT_FORMAT_INSTANCE,
			0,
			1,
			#meshDefinition.vertices,
			tangents,
			tangentData
		)

		local vi, vc = ExtendedModel.TANGENT_FORMAT_INSTANCE:getCountOffset(
			"VertexTangent"
		)
		local vj = vi + vc - 1

		local nc, ni = tangentVertexBufferInfo
			:getInputFormat()
			:getCountOffset("VertexTangent")
		local nj = ni + nc - 1

		for i = 1, #meshDefinition.vertices do
			local o1 = (i - 1)
				* tangentVertexBufferInfo:getInputFormat():getComponentCount()
			local o2 = (i - 1)
				* ExtendedModel.TANGENT_FORMAT_INSTANCE:getComponentCount()

			Table.copy(
				tangentOutputVertexData,
				ni + o1,
				nj + o1,
				tangentVertexBufferInfo:pack(
					"VertexTangent",
					ExtendedModel.TANGENT_FORMAT_INSTANCE:getExpandedValues(
						"VertexTangent",
						Table.unpack(tangentData, vi + o2, vj + 02)
					)
				)
			)
		end

		BufferFormat.copyFromFlatTableToByteData(
			tangentVertexBufferInfo:getInputFormat(),
			1,
			0,
			#meshDefinition.vertices,
			tangentOutputVertexData,
			tangentByteData
		)
	end
end

--- @private
--- @param pipelineConfig RatScratch.Pipeline.PipelineConfig
--- @param meshDefinition RatScratch.Graphics.Graphics3D.MeshDefinition
function ExtendedModel:_marshalIndexData(pipelineConfig, meshDefinition)
	local indexData = love.data.newByteData(
		pipelineConfig:getIndexFormat():getIndexFormat():getStride()
			* #meshDefinition.indices
	)

	local indexFormat = BufferFormat.get(Mesh.INDEX_FORMAT)

	local indices = meshDefinition.indices
	--- @cast indices number[]

	BufferFormat.copyFromFlatTableToByteData(
		indexFormat,
		1,
		0,
		#indices,
		indices,
		indexData
	)

	return indexData
end

--- @private
--- @param pipelineConfig RatScratch.Pipeline.PipelineConfig
--- @param mesh RatScratch.Pipeline.ExtendedMesh
--- @param meshDefinition RatScratch.Graphics.Graphics3D.MeshDefinition
--- @param indexData love.ByteData
function ExtendedModel:_transformIndexData(
	pipelineConfig,
	mesh,
	meshDefinition,
	indexData
)
	local triangleCount = pipelineConfig:getMeshletFormat():getTriangleCount()
	local vertexData = mesh:getVertexAttributeBufferData("VertexPosition")
	local vertexFormat = mesh:getVertexAttributeBufferInfo("VertexPosition")
		:getInputFormat()
	local meshlets, meshletBounds = MeshOptimizerFFI.buildMeshletsFlex(
		indexData,
		#meshDefinition.indices,
		vertexData,
		#meshDefinition.vertices,
		vertexFormat,
		triangleCount * 3,
		triangleCount,
		triangleCount,
		0,
		1
	)

	local totalIndexBufferSize = 0
	for i, meshletIndexData in ipairs(meshlets) do
		local meshlet = ExtendedMeshMeshlet.fromMesh(
			pipelineConfig,
			meshletIndexData,
			mesh,
			meshDefinition
		)
		meshlet:setStaticBounds(
			meshletBounds[i].position,
			meshletBounds[i].radius
		)
		totalIndexBufferSize = totalIndexBufferSize
			+ meshlet:getIndexData():getSize()
		mesh:addMeshlet(meshlet)
	end

	local combinedMeshletIndexData = love.data.newByteData(totalIndexBufferSize)
	local indexBufferOffset = 0
	for i = 1, mesh:getMeshletCount() do
		local meshlet = mesh:getMeshlet(i)
		ffi.copy(
			ffi.cast("uint8_t *", combinedMeshletIndexData:getFFIPointer())
				+ indexBufferOffset,
			meshlet:getIndexData():getFFIPointer(),
			meshlet:getIndexData():getSize()
		)
		indexBufferOffset = indexBufferOffset + meshlet:getIndexData():getSize()
	end

	mesh:addIndexBuffer(
		pipelineConfig:getIndexFormat(),
		combinedMeshletIndexData
	)
end

--- @param pipelineConfig RatScratch.Pipeline.PipelineConfig
function ExtendedModel:build(pipelineConfig)
	for _, meshDefinition in ipairs(self.meshDefinitions) do
		local mesh = ExtendedMesh(#meshDefinition.vertices)

		local meshFormat = BufferFormat.get(meshDefinition.format)
		local isSkinned = meshFormat:hasAttribute("VertexBoneIndex")
			and meshFormat:hasAttribute("VertexBoneWeight")

		local indexData = self:_marshalIndexData(pipelineConfig, meshDefinition)

		self:_transformVertexData(
			pipelineConfig,
			mesh,
			meshDefinition,
			"static",
			indexData
		)
		if isSkinned then
			self:_transformVertexData(
				pipelineConfig,
				mesh,
				meshDefinition,
				"skinned",
				indexData
			)
		end

		self:_transformIndexData(
			pipelineConfig,
			mesh,
			meshDefinition,
			indexData
		)

		table.insert(self.meshes, mesh)
	end

	assert(
		#self.meshes == #self.meshDefinitions,
		"mesh (%d) / mesh definition (%s) count mis-match",
		#self.meshes,
		#self.meshDefinitions
	)
end

return ExtendedModel
