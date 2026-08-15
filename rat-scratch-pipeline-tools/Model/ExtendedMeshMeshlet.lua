local ffi = require("ffi")
local Object = require("rat-scratch-common").Object
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Mesh = require("rat-scratch-graphics").Graphics3D.Mesh
local Vector3 = require("rat-scratch-math").Vector3

--- @class RatScratch.Pipeline.ExtendedMeshMeshlet : RatScratch.Common.BaseObject
--- @overload fun(mesh: RatScratch.Pipeline.ExtendedMesh, indexData: love.ByteData): RatScratch.Pipeline.ExtendedMeshMeshlet
--- @field private mesh RatScratch.Pipeline.ExtendedMesh
--- @field private indexData love.ByteData
--- @field private vertexIndices integer[]
--- @field private boneIndices integer[]
--- @field private staticBoundsPosition RatScratch.Math.Vector3
--- @field private staticBoundsRadius number
local ExtendedMeshMeshlet = Object()

--- @param mesh RatScratch.Pipeline.ExtendedMesh
--- @param indexData love.ByteData
function ExtendedMeshMeshlet:new(mesh, indexData)
	self.mesh = mesh
	self.indexData = indexData
	self.vertexIndices = {}
	self.boneIndices = {}
	self.bounds = {}
	self.staticBoundsPosition = Vector3()
	self.staticBoundsRadius = 0
end

function ExtendedMeshMeshlet:getStaticBounds()
	return self.staticBoundsPosition, self.staticBoundsRadius
end

--- @param position RatScratch.Math.Vector3
--- @param radius number
function ExtendedMeshMeshlet:setStaticBounds(position, radius)
	self.staticBoundsPosition:from(position:get())
	self.staticBoundsRadius = radius
end

function ExtendedMeshMeshlet:getIndexData()
	return self.indexData
end

function ExtendedMeshMeshlet:getUniqueVertexCount()
	return #self.vertexIndices
end

function ExtendedMeshMeshlet:getUniqueVertex(index)
	return self.vertexIndices[index]
end

function ExtendedMeshMeshlet:getUniqueBoneCount()
	return #self.boneIndices
end

function ExtendedMeshMeshlet:getUniqueBone(index)
	return self.boneIndices[index]
end

function ExtendedMeshMeshlet:getIsSkinned()
	return #self.boneIndices > 0
end

--- @param pipelineConfig RatScratch.Pipeline.PipelineConfig
--- @param indexData love.ByteData
--- @param mesh RatScratch.Pipeline.ExtendedMesh
--- @param meshDefinition RatScratch.Graphics.Graphics3D.MeshDefinition
function ExtendedMeshMeshlet.fromMesh(
	pipelineConfig,
	indexData,
	mesh,
	meshDefinition
)
	local indexFormat = BufferFormat.get(Mesh.INDEX_FORMAT)
	local meshFormat = BufferFormat.get(meshDefinition.format)

	local indexDataPointer = ffi.cast("uint32_t *", indexData:getFFIPointer())
	local indexCount = indexData:getSize() / indexFormat:getStride()

	local bones
	if
		meshFormat:hasAttribute("VertexBoneIndex")
		and meshFormat:hasAttribute("VertexBoneWeight")
	then
		local bonesByIndex = {}

		local boneIndexCount, boneIndexOffset =
			meshFormat:getCountOffset("VertexBoneIndex")
		local boneWeightCount, boneWeightOffset =
			meshFormat:getCountOffset("VertexBoneWeight")
		local count = math.min(boneIndexCount, boneWeightCount)

		for i = 1, indexCount do
			local index = indexDataPointer[i - 1]
			local vertex = meshDefinition.vertices[index + 1]

			for i = 1, count do
				local boneI = boneIndexOffset + i - 1
				local weightI = boneWeightOffset + i - 1

				local bone = vertex[boneI]
				local weight = vertex[weightI]

				if weight > 0 then
					bonesByIndex[bone] = true
				end
			end
		end

		bones = {}
		for bone in pairs(bonesByIndex) do
			table.insert(bones, bone)
		end
		table.sort(bones)
	end

	local verticesByIndex = {}
	for i = 1, indexCount do
		local index = indexDataPointer[i - 1]
		verticesByIndex[index] = true
	end

	local vertices = {}
	for index in ipairs(verticesByIndex) do
		table.insert(vertices, index)
	end
	table.sort(vertices)

	local meshletIndexData
	do
		local triangleCount =
			pipelineConfig:getMeshletFormat():getTriangleCount()
		local targetIndexCount = triangleCount * 3
		if indexCount < targetIndexCount then
			meshletIndexData = love.data.newByteData(
				targetIndexCount * indexFormat:getStride()
			)
			ffi.copy(
				meshletIndexData:getFFIPointer(),
				indexData:getFFIPointer(),
				indexData:getSize()
			)

			local pointer =
				ffi.cast("uint32_t *", meshletIndexData:getFFIPointer())
			for i = indexCount + 1, targetIndexCount do
				pointer[i - 1] = indexDataPointer[indexCount - 1]
			end
		else
			assert(
				indexCount == targetIndexCount,
				"expected %d indices, got %d",
				targetIndexCount,
				indexCount
			)
			meshletIndexData = indexData
		end
	end

	local mesh = ExtendedMeshMeshlet(mesh, meshletIndexData)
	mesh.boneIndices = bones or mesh.boneIndices
	mesh.vertexIndices = vertices

	return mesh
end

return ExtendedMeshMeshlet
