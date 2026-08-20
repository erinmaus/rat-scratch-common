local Object = require("rat-scratch-common").Object
local PipelineMeshlet =
	require("rat-scratch-pipeline.Graphics3D.PipelineMeshlet")

--- @class RatScratch.Pipeline.Graphics3D.PipelineMesh : RatScratch.Common.BaseObject
--- @field private indexCount integer
--- @field private vertexCount integer
--- @field private indices love.Data
--- @field private meshlets RatScratch.Pipeline.Graphics3D.PipelineMeshlet[]
--- @overload fun(vertexCount: integer, indexCount: integer, vertices: table<string, love.Data>, indices: love.Data, meshlets: RatScratch.Pipeline.Graphics3D.PipelineMeshlet[]): RatScratch.Pipeline.Graphics3D.PipelineMesh
local PipelineMesh = Object()

--- @param vertexCount integer
--- @param indexCount integer
--- @param vertices table<string, love.Data>
--- @param indices love.Data
--- @param meshlets RatScratch.Pipeline.Graphics3D.PipelineMeshlet[]
function PipelineMesh:new(vertexCount, indexCount, vertices, indices, meshlets)
	self.vertexCount = vertexCount
	self.indexCount = indexCount
	self.vertices = vertices
	self.indices = indices
	self.vertices = {}
	self.meshlets = meshlets
end

function PipelineMesh:getVertexCount()
	return self.vertexCount
end

function PipelineMesh:getIndexCount()
	return self.indexCount
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
	return self.indices
end

--- @return integer
function PipelineMesh:getMeshletCount()
	return #self.meshlets
end

--- @param index integer
--- @return RatScratch.Pipeline.Graphics3D.PipelineMeshlet
function PipelineMesh:getMeshlet(index)
	return self.meshlets[index]
end

--- @param meshDefinition RatScratch.Pipeline.Graphics3D.PipelineMeshDefinition
function PipelineMesh.fromDefinition(meshDefinition)
	local meshlets = {}

	for _, meshletDefinition in ipairs(meshDefinition.meshlets) do
		table.insert(
			meshlets,
			PipelineMeshlet.fromDefinition(meshletDefinition)
		)
	end

	return PipelineMesh(
		meshDefinition.vertexCount,
		meshDefinition.indexCount,
		meshDefinition.vertices,
		meshDefinition.indices,
		meshlets
	)
end

return PipelineMesh
