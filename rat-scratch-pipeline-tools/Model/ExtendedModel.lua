local Object = require("rat-scratch-common").Object
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Table = require("rat-scratch-common").Table
local Mesh = require("rat-scratch-graphics").Graphics3D.Mesh
local ExtendedMesh = require("rat-scratch-pipeline-tools.Model.ExtendedMesh")
local ExtendedMeshMeshlet =
	require("rat-scratch-pipeline-tools.Model.ExtendedMeshMeshlet")
local MeshOptimizerFFI =
	require("rat-scratch-pipeline-tools.impl.MeshOptimizerFFI")
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

--- @private
--- @param pipelineConfig RatScratch.Pipeline.PipelineConfig
--- @param mesh RatScratch.Pipeline.ExtendedMesh
--- @param meshDefinition RatScratch.Graphics.Graphics3D.MeshDefinition
--- @param role string
function ExtendedModel:_transformVertexData(
	pipelineConfig,
	mesh,
	meshDefinition,
	role
)
	local meshFormat = BufferFormat.get(meshDefinition.format)

	local vertexFormatCount = pipelineConfig:getVertexFormatCountByRole(role)
	for i = 1, vertexFormatCount do
		local vertexBufferInfo = pipelineConfig:getVertexFormatByRole(role, i)
		local byteDataSize = vertexBufferInfo:getInputFormat():getStride()
			* #meshDefinition.vertices
		local byteData = love.data.newByteData(byteDataSize)

		local outputVertexData = {}
		local vertexFormat = vertexBufferInfo:getInputFormat()
		local attributeCount = #vertexFormat:getFormat()
		for j = 1, attributeCount do
			local attribute = vertexFormat:getFormat()[j]
			if meshFormat:hasAttribute(attribute.name) then
				local vc, vi = meshFormat:getCountOffset(attribute.name)
				local vj = vi + vc - 1

				for k = 1, #meshDefinition.vertices do
					local inputVertex = meshDefinition.vertices[k]
					Table.append(
						outputVertexData,
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
end

--- @private
--- @param pipelineConfig RatScratch.Pipeline.PipelineConfig
--- @param mesh RatScratch.Pipeline.ExtendedMesh
--- @param meshDefinition RatScratch.Graphics.Graphics3D.MeshDefinition
function ExtendedModel:_transformIndexData(pipelineConfig, mesh, meshDefinition)
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

	local triangleCount = pipelineConfig:getMeshletFormat():getTriangleCount()
	local vertexData = mesh:getVertexAttributeBufferData("VertexPosition")
	local vertexFormat = mesh:getVertexAttributeBufferInfo("VertexPosition")
		:getInputFormat()
	local meshlets = MeshOptimizerFFI.buildMeshletsFlex(
		indexData,
		#indices,
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
	for _, meshletIndexData in ipairs(meshlets) do
		local meshlet = ExtendedMeshMeshlet.fromMesh(
			pipelineConfig,
			meshletIndexData,
			mesh,
			meshDefinition
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

		self:_transformVertexData(
			pipelineConfig,
			mesh,
			meshDefinition,
			"static"
		)
		if isSkinned then
			self:_transformVertexData(
				pipelineConfig,
				mesh,
				meshDefinition,
				"skinned"
			)
		end

		self:_transformIndexData(pipelineConfig, mesh, meshDefinition)

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
