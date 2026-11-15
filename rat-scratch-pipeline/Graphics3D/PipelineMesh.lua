local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local Material = require("rat-scratch-graphics").Graphics3D.Material
local PipelineBLAS = require("rat-scratch-pipeline.Graphics3D.PipelineBLAS")
local PipelineLOD = require("rat-scratch-pipeline.Graphics3D.PipelineLOD")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local ffi = require("ffi")
local Mesh = require("rat-scratch-graphics").Graphics3D.Mesh
local Vector3 = require("rat-scratch-math").Vector3
local Triangle = require("rat-scratch-math").Geometry3D.Triangle

--- @class RatScratch.Pipeline.Graphics3D.PipelineMesh : RatScratch.Common.BaseObject
--- @field private meshletIndexCount integer
--- @field private vertexCount integer
--- @field private indices love.Data
--- @field private meshletIndices love.Data
--- @field private lod RatScratch.Pipeline.Graphics3D.PipelineLOD
--- @field private blas RatScratch.Pipeline.Graphics3D.PipelineBLAS
--- @field private material? RatScratch.Graphics.Graphics3D.Material
--- @field private cachedVertices table<string, table<integer, RatScratch.Math.Vector3[]>>
--- @overload fun(vertexCount: integer, meshletIndexCount: integer, vertices: table<string, love.Data>, indices: love.Data, meshletIndices: love.Data, blas: RatScratch.Pipeline.Graphics3D.PipelineBLAS, lod: RatScratch.Pipeline.Graphics3D.PipelineLOD, material?: RatScratch.Graphics.Graphics3D.Material): RatScratch.Pipeline.Graphics3D.PipelineMesh
local PipelineMesh = Object()

--- @param vertexCount integer
--- @param meshletIndexCount integer
--- @param vertices table<string, love.Data>
--- @param indices love.Data
--- @param meshletIndices love.Data
--- @param blas RatScratch.Pipeline.Graphics3D.PipelineBLAS
--- @param lod RatScratch.Pipeline.Graphics3D.PipelineLOD
--- @param material? RatScratch.Graphics.Graphics3D.Material
function PipelineMesh:new(
	vertexCount,
	meshletIndexCount,
	vertices,
	indices,
	meshletIndices,
	blas,
	lod,
	material
)
	self.vertexCount = vertexCount
	self.meshletIndexCount = meshletIndexCount
	self.indexCount = indices:getSize() / ffi.sizeof("uint32_t")
	self.indices = indices
	self.meshletIndices = meshletIndices
	self.vertices = Table.cloneHash(vertices)
	self.lod = lod
	self.blas = blas
	self.material = material

	self.cachedVertices = {}
end

function PipelineMesh:getBounds()
	return self.blas:getBounds()
end

do
	local _vertex = {}
	local _triangleIndices = {}
	local TRIANGLE_COUNT = 3

	--- @param triangleIndex integer
	--- @param vertexName string
	--- @param vertexFormat RatScratch.Graphics.Graphics3D.BufferFormat
	--- @return RatScratch.Math.Vector3, RatScratch.Math.Vector3, RatScratch.Math.Vector3
	function PipelineMesh:_getTriangleVertexPositions(
		triangleIndex,
		vertexName,
		vertexFormat
	)
		local cachedVertices = self.cachedVertices[vertexName]
		if not cachedVertices then
			cachedVertices = {}
			self.cachedVertices[vertexName] = cachedVertices
		end

		local positions = cachedVertices[triangleIndex]
		if positions then
			return positions[1], positions[2], positions[3]
		else
			positions = { Vector3(), Vector3(), Vector3() }
		end

		local vertexData = self.vertices[vertexName]
		local triangleIndices = _triangleIndices
		BufferFormat.copyFromByteDataToFlatTable(
			Mesh.INDEX_FORMAT,
			(triangleIndex - 1) * (ffi.sizeof("uint32_t") * TRIANGLE_COUNT),
			1,
			TRIANGLE_COUNT,
			self.indices,
			triangleIndices
		)

		local vertex = _vertex
		for i = 1, TRIANGLE_COUNT do
			local index = triangleIndices[i]

			BufferFormat.copyFromByteDataToFlatTable(
				vertexFormat,
				index * vertexFormat:getStride(),
				1,
				1,
				vertexData,
				vertex
			)

			local x, y, z =
				BufferFormat.getValue(vertexFormat, vertex, "VertexPosition")
			positions[i]:from(x, y, z)
		end

		cachedVertices[triangleIndex] = positions

		return positions[1], positions[2], positions[3]
	end

	--- @param triangleIndex integer
	--- @param vertexName string
	--- @param vertexFormat RatScratch.Graphics.Graphics3D.BufferFormat
	--- @param origin RatScratch.Math.Vector3
	--- @param direction RatScratch.Math.Vector3
	--- @return boolean, number
	function PipelineMesh:raycast(
		triangleIndex,
		vertexName,
		vertexFormat,
		origin,
		direction
	)
		local a, b, c = self:_getTriangleVertexPositions(
			triangleIndex,
			vertexName,
			vertexFormat
		)
		return Triangle.raycast(a, b, c, origin, direction)
	end
end

function PipelineMesh:getVertexCount()
	return self.vertexCount
end

function PipelineMesh:getIndexCount()
	return self.indexCount
end

function PipelineMesh:getMeshletIndexCount()
	return self.meshletIndexCount
end

function PipelineMesh:getBLAS()
	return self.blas
end

--- @param bufferName string
--- @return boolean
function PipelineMesh:hasVertexData(bufferName)
	return self.vertices[bufferName] ~= nil
end

--- @param bufferName any
--- @return love.Data?
function PipelineMesh:getVertexData(bufferName)
	return self.vertices[bufferName]
end

--- @return love.Data
function PipelineMesh:getIndexData()
	return self.meshletIndices
end

--- @return love.Data
function PipelineMesh:getMeshletIndexData()
	return self.meshletIndices
end

--- @return RatScratch.Pipeline.Graphics3D.PipelineLOD
function PipelineMesh:getLOD()
	return self.lod
end

function PipelineMesh:getMaterial()
	return self.material
end

--- @param meshDefinition RatScratch.Pipeline.Graphics3D.PipelineMeshDefinition
function PipelineMesh.fromDefinition(meshDefinition)
	return PipelineMesh(
		meshDefinition.vertexCount,
		meshDefinition.indexCount,
		meshDefinition.vertices,
		meshDefinition.indices,
		meshDefinition.meshletIndices,
		PipelineBLAS.fromDefinition(meshDefinition.blas),
		PipelineLOD.fromDefinition(meshDefinition.lod),
		Material.fromDefinition(meshDefinition.material)
	)
end

return PipelineMesh
