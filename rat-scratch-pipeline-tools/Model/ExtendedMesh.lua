local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert

--- @generic T
--- @class RatScratch.Pipeline.ExtendedMesh.impl.Buffer<T>
--- @field public info T
--- @field public data love.ByteData
local ImplBuffer = {}

--- @class RatScratch.Pipeline.ExtendedMesh : RatScratch.Common.BaseObject
--- @overload fun(vertexCount?: integer, indexCount?: integer): RatScratch.Pipeline.ExtendedMesh
--- @field private vertexCount integer
--- @field private indexCount integer
--- @field private vertexBuffers RatScratch.Pipeline.ExtendedMesh.impl.Buffer<RatScratch.Pipeline.VertexBufferInfo>[]
--- @field private indexBuffer RatScratch.Pipeline.ExtendedMesh.impl.Buffer<RatScratch.Pipeline.IndexBufferInfo>
--- @field private attributeToVertexBuffer table<string, integer>
--- @field private meshlets RatScratch.Pipeline.ExtendedMeshMeshlet[]
local ExtendedMesh = Object()

--- @param vertexCount? integer
--- @param indexCount? integer
function ExtendedMesh:new(vertexCount, indexCount)
	self.vertexCount = vertexCount or 0
	self.indexCount = indexCount or 0
	self.vertexBuffers = {}
	self.attributeToVertexBuffer = {}
	self.meshlets = {}
end

function ExtendedMesh:getVertexCount()
	return self.vertexCount
end

function ExtendedMesh:getIndexCount()
	return self.indexCount
end

--- @param indexBufferInfo RatScratch.Pipeline.IndexBufferInfo
--- @param data love.ByteData
function ExtendedMesh:addIndexBuffer(indexBufferInfo, data)
	assert(not self.indexBuffer, "index buffer already added")
	assert(
		data:getSize()
				== indexBufferInfo:getIndexFormat():getStride() * self.indexCount
			or self.indexCount == 0,
		"expected %d byte(s) index buffer, got %d byte(s)",
		indexBufferInfo:getIndexFormat():getStride() * self.indexCount,
		data:getSize()
	)

	if self.indexCount == 0 then
		self.indexCount = data:getSize()
			/ indexBufferInfo:getIndexFormat():getStride()
	end

	self.indexBuffer = {
		info = indexBufferInfo,
		data = data,
	}
end

function ExtendedMesh:getIndexBufferInfo()
	return self.indexBuffer.info
end

function ExtendedMesh:getIndexBufferData()
	return self.indexBuffer.data
end

function ExtendedMesh:getMeshletCount()
	return #self.meshlets
end

function ExtendedMesh:getMeshlet(index)
	return self.meshlets[index]
end

function ExtendedMesh:addMeshlet(meshlet)
	table.insert(self.meshlets, meshlet)
end

function ExtendedMesh:getIsSkinned()
	return self:getVertexAttributeBufferData("VertexBoneIndex") ~= nil
		and self:getVertexAttributeBufferData("VertexBoneWeight") ~= nil
end

--- @param vertexBufferInfo RatScratch.Pipeline.VertexBufferInfo
--- @param data love.ByteData
function ExtendedMesh:addVertexAttributeBuffer(vertexBufferInfo, data)
	assert(
		data:getSize()
				== vertexBufferInfo:getInputFormat():getStride() * self.vertexCount
			or self.vertexCount == 0,
		"expected %d byte(s) vertex buffer, got %d byte(s)",
		vertexBufferInfo:getInputFormat():getStride() * self.indexCount,
		data:getSize()
	)

	if self.vertexCount == 0 then
		self.vertexCount = data:getSize()
			/ vertexBufferInfo:getInputFormat():getStride()
	end

	local vertexBufferFormat = vertexBufferInfo:getInputFormat()
	for _, attribute in ipairs(vertexBufferFormat:getFormat()) do
		assert(
			not self.attributeToVertexBuffer[attribute.name],
			"vertex buffer '%s' already has attribute %s; cannot add %s"
		)
	end

	table.insert(self.vertexBuffers, {
		info = vertexBufferInfo,
		data = data,
	})

	local format = vertexBufferInfo:getInputFormat():getFormat()
	for _, attribute in ipairs(format) do
		self.attributeToVertexBuffer[attribute.name] = #self.vertexBuffers
	end
end

function ExtendedMesh:getVertexAttributeBufferCount()
	return #self.vertexBuffers
end

--- @param index string | integer
--- @return RatScratch.Pipeline.VertexBufferInfo
function ExtendedMesh:getVertexAttributeBufferInfo(index)
	return self.vertexBuffers[self.attributeToVertexBuffer[index] or index].info
end

--- @param index string | integer
--- @return love.ByteData
function ExtendedMesh:getVertexAttributeBufferData(index)
	return self.vertexBuffers[self.attributeToVertexBuffer[index] or index].data
end

return ExtendedMesh
