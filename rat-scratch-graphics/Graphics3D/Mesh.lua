local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")

--- @alias RatScratch.Graphics.Graphics3D.MeshVertexAttributeFormat RatScratch.Graphics.Graphics3D.BufferAttributeFormat
--- @alias RatScratch.Graphics.Graphics3D.MeshVertexAttributeName RatScratch.Graphics.Graphics3D.BufferAttributeName
--- @alias RatScratch.Graphics.Graphics3D.MeshFormatAttribute RatScratch.Graphics.Graphics3D.BufferFormatAttribute

--- @class RatScratch.Graphics.Graphics3D.Mesh : RatScratch.Common.BaseObject
--- @field private name string
--- @field private format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @field private mesh love.Mesh
--- @field private buffers table<RatScratch.Graphics.Graphics3D.BufferRole, love.graphics.GraphicsBuffer>
--- @field private bufferInfo table<RatScratch.Graphics.Graphics3D.BufferRole, RatScratch.Graphics.Graphics3D.MarshalBuffer>
--- @field private indexBuffer love.graphics.GraphicsBuffer
--- @field private material? RatScratch.Graphics.Graphics3D.Material
local Mesh = Object()

--- @alias RatScratch.Graphics.Graphics3D.MeshIndexMode "fan" | "points" | "strip" | "triangles"

--- @alias RatScratch.Graphics.Graphics3D.BufferRole "compute_input" | "compute_output" | "static"
--- @class RatScratch.Graphics.Graphics3D.BufferDefinition
--- @field public name? string
--- @field public role RatScratch.Graphics.Graphics3D.BufferRole
--- @field public format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
local BufferDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.MarshalBuffer
--- @field public name? string
--- @field public role RatScratch.Graphics.Graphics3D.BufferRole
--- @field public format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @field public vertices number[][] | number
local BufferDefinition = {}

--- @alias RatScratch.Graphics.Graphics3D.PreprocessedMeshFormat table<string, number[]>

--- @type RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
Mesh.SKINNED_MESH_FORMAT = {
	{ location = 0, name = "VertexPosition", format = "floatvec4" },
	{ location = 1, name = "VertexTexCoord", format = "floatvec4" },
	{ location = 2, name = "VertexColor", format = "floatvec4" },
	{ location = 10, name = "VertexNormal", format = "floatvec4" },
	{ location = 20, name = "VertexBoneIndex", format = "uint32vec4" },
	{ location = 21, name = "VertexBoneWeight", format = "floatvec4" },
}

--- @type RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
Mesh.STATIC_MESH_FORMAT = {
	{ location = 0, name = "VertexPosition", format = "floatvec4" },
	{ location = 1, name = "VertexTexCoord", format = "floatvec4" },
	{ location = 2, name = "VertexColor", format = "floatvec4" },
	{ location = 10, name = "VertexNormal", format = "floatvec4" },
}

--- @type RatScratch.Graphics.Graphics3D.BufferDefinition
Mesh.STATIC_BUFFER_DEFINITION = {
	role = "static",
	format = Mesh.STATIC_MESH_FORMAT,
}

--- @type RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
Mesh.CONSTANT_BUFFER_FORMAT = {
	{ location = 1, name = "VertexTexCoord", format = "floatvec4" },
	{ location = 2, name = "VertexColor", format = "floatvec4" },
}

--- @type RatScratch.Graphics.Graphics3D.BufferDefinition
Mesh.CONSTANT_BUFFER_DEFINITION = {
	role = "static",
	format = Mesh.CONSTANT_BUFFER_FORMAT,
}

--- @type RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
Mesh.TRANSFORM_BUFFER_INPUT_FORMAT = {
	{ location = 0, name = "VertexPosition", format = "floatvec4" },
	{ location = 10, name = "VertexNormal", format = "floatvec4" },
	{ location = 20, name = "VertexBoneIndex", format = "uint32vec4" },
	{ location = 21, name = "VertexBoneWeight", format = "floatvec4" },
}

--- @type RatScratch.Graphics.Graphics3D.BufferDefinition
Mesh.TRANSFORM_INPUT_BUFFER_DEFINITION = {
	role = "compute_input",
	format = Mesh.TRANSFORM_BUFFER_INPUT_FORMAT,
}

--- @type RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
Mesh.TRANSFORM_BUFFER_OUTPUT_FORMAT = {
	{ location = 0, name = "VertexPosition", format = "floatvec4" },
	{ location = 10, name = "VertexNormal", format = "floatvec4" },
}

--- @type RatScratch.Graphics.Graphics3D.BufferDefinition
Mesh.TRANSFORM_OUTPUT_BUFFER_DEFINITION = {
	role = "compute_output",
	format = Mesh.TRANSFORM_BUFFER_OUTPUT_FORMAT,
}

--- @type RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
Mesh.INDEX_FORMAT = {
	{ location = 0, name = "index", format = "uint32" },
}

--- @param inputIndices number[]
--- @param inputIndexMode RatScratch.Graphics.Graphics3D.MeshIndexMode | string
function Mesh.marshalTriangles(inputIndices, inputIndexMode)
	if inputIndexMode == "triangles" then
		return inputIndices
	end

	local outputIndices = {}
	if inputIndexMode == "strip" then
		for t = 1, #inputIndices - 2 do
			if t % 2 == 1 then
				table.insert(outputIndices, inputIndices[t])
				table.insert(outputIndices, inputIndices[t + 1])
				table.insert(outputIndices, inputIndices[t + 2])
			else
				table.insert(outputIndices, inputIndices[t + 1])
				table.insert(outputIndices, inputIndices[t])
				table.insert(outputIndices, inputIndices[t + 2])
			end
		end
	elseif inputIndexMode == "fan" then
		for t = 2, #inputIndices - 1 do
			table.insert(outputIndices, inputIndices[1])
			table.insert(outputIndices, inputIndices[t])
			table.insert(outputIndices, inputIndices[t + 1])
		end
	else
		error('mesh index mode must be "triangles", "strip", or "fan"')
	end

	return outputIndices
end

local VERTEX_BUFFER_USAGE = { shaderstorage = true, vertex = true }
local INDEX_BUFFER_USAGE = { shaderstorage = true, index = true }

--- @param buffers RatScratch.Graphics.Graphics3D.BufferDefinition[]
--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @param vertices number[][] | number
--- @param indices? number[] | number
--- @param mode? RatScratch.Graphics.Graphics3D.MeshIndexMode | string
function Mesh.marshal(buffers, format, vertices, indices, mode)
	--- @type number[][] | number, number
	local outputVertices, vertexCount

	--- @type RatScratch.Graphics.Graphics3D.MarshalBuffer[]
	local outputBuffers = {}

	if type(vertices) == "number" then
		outputVertices = vertices
		vertexCount = vertices

		for _, buffer in ipairs(buffers) do
			--- @type RatScratch.Graphics.Graphics3D.MarshalBuffer
			local outputBuffer = {
				role = buffer.role,
				format = buffer.format,
				name = buffer.name,
				vertices = outputVertices,
			}

			table.insert(outputBuffer, outputBuffer)
		end
	else
		vertexCount = #vertices

		for _, buffer in ipairs(buffers) do
			--- @type number[][]
			local outputBufferVertices = {}

			--- @type RatScratch.Graphics.Graphics3D.MarshalBuffer
			local outputBuffer = {
				role = buffer.role,
				format = buffer.format,
				name = buffer.name,
				vertices = outputBufferVertices,
			}

			for _, inputVertex in ipairs(vertices) do
				local outputVertex = {}

				BufferFormat.marshalFromInputFormatToOutputFormat(
					format,
					inputVertex,
					buffer.format,
					outputVertex
				)
				table.insert(outputBufferVertices, outputVertex)
			end

			table.insert(outputBuffers, outputBuffer)
		end
	end

	local outputIndices
	if type(indices) == "nil" then
		outputIndices = {}

		local indexCount = vertexCount - 1
		for i = 0, indexCount do
			table.insert(outputIndices, i)
		end
	elseif type(indices) == "number" then
		outputIndices = indices
	else
		--- @cast indices number[]
		outputIndices = Mesh.marshalTriangles(indices, mode or "triangles")
	end

	return outputBuffers, outputIndices
end

--- @param name? string
--- @param buffers RatScratch.Graphics.Graphics3D.MarshalBuffer[]
--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @param vertices number[][] | number
--- @param indices number[] | number
--- @param material RatScratch.Graphics.Graphics3D.Material?
function Mesh:new(name, buffers, format, vertices, indices, material)
	local numVertices
	if type(vertices) == "number" then
		numVertices = vertices
	else
		numVertices = #vertices
	end

	self.name = name or ""

	self.buffers = {}
	self.bufferInfo = {}
	for _, inputBuffer in ipairs(buffers) do
		assert(
			self.buffers[inputBuffer.role] == nil,
			'more than one buffer with role "%s"; only one buffer is allowed per role',
			inputBuffer.role
		)

		local buffer = love.graphics.newBuffer(
			inputBuffer.format,
			numVertices,
			VERTEX_BUFFER_USAGE
		)
		if type(inputBuffer.vertices) ~= "number" then
			buffer:setArrayData(inputBuffer.vertices)
		end

		self.buffers[inputBuffer.role] = buffer
		self.bufferInfo[inputBuffer.role] = inputBuffer
	end

	local numIndices
	if type(indices) == "number" then
		numIndices = indices
	else
		numIndices = #indices
	end

	self.indexBuffer = love.graphics.newBuffer(
		Mesh.INDEX_FORMAT,
		numIndices,
		INDEX_BUFFER_USAGE
	)
	if type(indices) ~= "number" then
		self.indexBuffer:setArrayData(indices)
	end

	local formatInstance = BufferFormat(format)
	self.format = formatInstance:getFormat()

	self.mesh =
		love.graphics.newMesh(format, numVertices, "triangles", "static")
	do
		local staticBuffer = self.buffers.static
		local staticBufferInfo = self.bufferInfo.static

		if staticBuffer and staticBufferInfo then
			for _, attribute in ipairs(staticBufferInfo.format) do
				if
					formatInstance:hasAttribute(
						attribute.location,
						attribute.name
					)
				then
					self.mesh:setAttributeEnabled(attribute.location, true)
					self.mesh:attachAttribute(attribute.location, staticBuffer)
				end
			end
		end

		local inputBuffer = self.buffers.compute_input
		local inputBufferInfo = self.bufferInfo.compute_input

		if inputBuffer and inputBufferInfo then
			for _, attribute in ipairs(inputBufferInfo.format) do
				if
					formatInstance:hasAttribute(
						attribute.location,
						attribute.name
					)
				then
					self.mesh:setAttributeEnabled(attribute.location, true)
					self.mesh:attachAttribute(attribute.location, inputBuffer)
				end
			end
		end

		local outputBuffer = self.buffers.compute_output
		local outputBufferInfo = self.bufferInfo.compute_output

		if outputBuffer and outputBufferInfo then
			for _, attribute in ipairs(outputBufferInfo.format) do
				if
					formatInstance:hasAttribute(
						attribute.location,
						attribute.name
					)
				then
					self.mesh:setAttributeEnabled(attribute.location, true)
					self.mesh:attachAttribute(attribute.location, outputBuffer)
				end
			end
		end

		self.mesh:setIndexBuffer(self.indexBuffer)
	end

	self.material = material
end

function Mesh:getName()
	return self.name
end

function Mesh:getFormat()
	return self.format
end

function Mesh:getMesh()
	return self.mesh
end

--- @param role RatScratch.Graphics.Graphics3D.BufferRole?
--- @return love.graphics.GraphicsBuffer
function Mesh:getBufferByRole(role)
	return self.buffers[role]
end

--- @param role RatScratch.Graphics.Graphics3D.BufferRole?
--- @return RatScratch.Graphics.Graphics3D.BufferDefinition
function Mesh:getBufferInfoByRole(role)
	return self.bufferInfo[role]
end

function Mesh:getIndexBuffer()
	return self.indexBuffer
end

function Mesh:getMaterial()
	return self.material
end

return Mesh
