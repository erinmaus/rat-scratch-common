local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert

--- @class RatScratch.Graphics.Graphics3D.Mesh : RatScratch.Common.BaseObject
--- @field private name string
--- @field private format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @field private mesh love.Mesh
--- @field private buffers table<RatScratch.Graphics.Graphics3D.BufferRole, love.graphics.GraphicsBuffer>
--- @field private bufferInfo table<RatScratch.Graphics.Graphics3D.BufferRole, RatScratch.Graphics.Graphics3D.MarshalBuffer>
--- @field private indexBuffer love.graphics.GraphicsBuffer
--- @field private material? RatScratch.Graphics.Graphics3D.Material
local Mesh = Object()

--- @alias RatScratch.Graphics.Graphics3D.MeshVertexAttributeFormat "float" | "floatvec2" | "floatvec3" | "floatvec4" | "int32" | "int32vec2" | "int32vec3" | "int32vec4" | "uint32" | "uint32vec2" | "uint32vec3" | "uint32vec4"
--- @alias RatScratch.Graphics.Graphics3D.MeshVertexAttributeName "VertexPosition" | "VertexTexCoord" | "VertexColor" | "VertexNormal" | "VertexBoneIndex" | "VertexBoneWeight"
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

--- @class RatScratch.Graphics.Graphics3D.MeshFormatAttribute
--- @field public location number
--- @field public name RatScratch.Graphics.Graphics3D.MeshVertexAttributeName | string
--- @field public format RatScratch.Graphics.Graphics3D.MeshVertexAttributeFormat
local MeshFormatAttribute = {}

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

local ATTRIBUTE_NAME_TO_LOCATION = {
	VertexPosition = 0,
	VertexTexCoord = 1,
	VertexColor = 2,
	VertexNormal = 10,
	VertexBoneIndex = 20,
	VertexBoneWeight = 21,
}

local RESERVED_LOCATIONS = {
	[0] = true,
	[1] = true,
	[2] = true,
	[10] = true,
	[20] = true,
	[21] = true,
}

--- @param name RatScratch.Graphics.Graphics3D.MeshVertexAttributeName | string
--- @return number
function Mesh.getAttributeLocationFromName(name)
	return ATTRIBUTE_NAME_TO_LOCATION[name] or -1
end

--- @param name RatScratch.Graphics.Graphics3D.MeshVertexAttributeName | string
--- @return boolean
function Mesh.isValidAttributeName(name)
	return ATTRIBUTE_NAME_TO_LOCATION[name] ~= nil
end

--- @param location number
--- @return boolean
function Mesh.isReservedLocation(location)
	return RESERVED_LOCATIONS[location] == true
end

local ATTRIBUTE_COMPONENTS = {
	float = 1,
	floatvec2 = 2,
	floatvec3 = 3,
	floatvec4 = 4,
	int32 = 1,
	int32vec2 = 2,
	int32vec3 = 3,
	int32vec4 = 4,
	uint32 = 1,
	uint32vec2 = 2,
	uint32vec3 = 3,
	uint32vec4 = 4,
}

local EXPANDED_ATTRIBUTE_FORMAT = {
	float = "floatvec4",
	floatvec2 = "floatvec4",
	floatvec3 = "floatvec4",
	floatvec4 = "floatvec4",
	int32 = "int32vec4",
	int32vec2 = "int32vec4",
	int32vec3 = "int32vec4",
	int32vec4 = "int32vec4",
	uint32 = "uint32vec4",
	uint32vec2 = "uint32vec4",
	uint32vec3 = "uint32vec4",
	uint32vec4 = "uint32vec4",
}

local ATTRIBUTE_NAME_DEFAULT_COMPONENT_VALUES = {
	VertexPosition = { 0, 0, 0, 1 },
	VertexTexCoord = { 0, 0, 0, 0 },
	VertexColor = { 1, 1, 1, 1 },
	VertexNormal = { 0, 0, 0, 0 },
	VertexBoneIndex = { 0, 0, 0, 0 },
	VertexBoneWeight = { 1, 0, 0, 0 },
}

local DEFAULT_MISSING_COMPONENT_VALUES = { 0, 0, 0, 0 }

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @param attributeName string
--- @return integer?, integer?
function Mesh.getAttributeCountOffset(format, attributeName)
	local index = 0
	for _, attribute in ipairs(format) do
		local count = ATTRIBUTE_COMPONENTS[attribute.format]
		assert(
			count,
			"attribute format not valid for %s: %s",
			attribute.name,
			attribute.format
		)

		if attribute.name == attributeName then
			return count, index + 1
		end

		index = index + count
	end

	return nil, nil
end

function Mesh.getVertexAttributeValues(count, offset, attributeName, vertex)
	local defaultValues = ATTRIBUTE_NAME_DEFAULT_COMPONENT_VALUES[attributeName]
		or DEFAULT_MISSING_COMPONENT_VALUES
	local dx, dy, dz, dw = unpack(defaultValues)

	local x, y, z, w = unpack(vertex, offset, offset + count)

	return x or dx, y or dy, z or dz, w or dw
end

local function _copy(i, j, v, c, ...)
	if i > j then
		return
	end

	v[i] = c or 0
	return _copy(i + 1, j, v, ...)
end

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @param vertex number[]
function Mesh.resetVertex(format, vertex)
	local index = 0
	for _, attribute in ipairs(format) do
		local numComponents = ATTRIBUTE_COMPONENTS[attribute.format]
		local defaultValues = ATTRIBUTE_NAME_DEFAULT_COMPONENT_VALUES[attribute.name]
			or DEFAULT_MISSING_COMPONENT_VALUES

		for i = 1, numComponents do
			vertex[index + i] = defaultValues[i] or 0
		end

		index = index + numComponents
	end
end

--- @param inputFormat RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @param inputVertex number[]
--- @param outputFormat RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @param outputVertex number[]
--- @param preprocessedInputFormat? RatScratch.Graphics.Graphics3D.PreprocessedMeshFormat
--- @param preprocessedOutputFormat? RatScratch.Graphics.Graphics3D.PreprocessedMeshFormat
function Mesh.marshalFromInputFormatToOutputFormat(
	inputFormat,
	inputVertex,
	outputFormat,
	outputVertex,
	preprocessedInputFormat,
	preprocessedOutputFormat
)
	local inputIndex = 0
	for _, attribute in ipairs(inputFormat) do
		local inputCount = ATTRIBUTE_COMPONENTS[attribute.format]
		assert(
			inputCount,
			"attribute format not valid for %s: %s",
			attribute.name,
			attribute.format
		)

		local outputCount, outputIndex
		if preprocessedInputFormat then
			if preprocessedInputFormat[attribute.name] then
				outputCount, outputIndex =
					unpack(preprocessedInputFormat[attribute.name])
			end
		else
			outputCount, outputIndex =
				Mesh.getAttributeCountOffset(outputFormat, attribute.name)
		end

		if outputIndex and outputCount then
			local inputX, inputY, inputZ, inputW =
				Mesh.getVertexAttributeValues(
					inputCount,
					inputIndex + 1,
					attribute.name,
					inputVertex
				)

			_copy(
				outputIndex,
				outputIndex + outputCount - 1,
				outputVertex,
				inputX,
				inputY,
				inputZ,
				inputW
			)
		end

		inputIndex = inputIndex + inputCount
	end

	local outputIndex = 0
	for _, attribute in ipairs(outputFormat) do
		local outputCount = ATTRIBUTE_COMPONENTS[attribute.format]

		local inputCount, inputIndex
		if preprocessedInputFormat then
			if preprocessedInputFormat[attribute.name] then
				inputCount, inputIndex =
					unpack(preprocessedInputFormat[attribute.name])
			end
		else
			inputCount, inputIndex =
				Mesh.getAttributeCountOffset(inputFormat, attribute.name)
		end

		if not (inputCount and inputIndex) then
			local defaultValues = ATTRIBUTE_NAME_DEFAULT_COMPONENT_VALUES[attribute.name]
				or DEFAULT_MISSING_COMPONENT_VALUES
			local x, y, z, w = unpack(defaultValues)

			_copy(
				outputIndex + 1,
				outputIndex + outputCount,
				outputVertex,
				x,
				y,
				z,
				w
			)
		end

		outputIndex = outputIndex + outputCount
	end
end

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

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @param baseFormat RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
function Mesh.extendMeshFormat(format, baseFormat)
	--- @type RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
	local result = {}

	for _, attribute in ipairs(baseFormat) do
		local location, name, format =
			attribute.location, attribute.name, attribute.format
		table.insert(result, {
			location = location,
			name = name,
			format = format,
		})
	end

	for _, attribute in ipairs(format) do
		local isReservedName = attribute.name
			and Mesh.isValidAttributeName(attribute.name)
		local isReservedLocation = attribute.location
			and Mesh.isReservedLocation(attribute.location)

		if not (isReservedName or isReservedLocation) then
			local location, name, format =
				attribute.location, attribute.name, attribute.format
			local expandedFormat = EXPANDED_ATTRIBUTE_FORMAT[format]

			assert(
				expandedFormat,
				"invalid attribute format for %s: %s",
				name,
				format
			)

			table.insert(result, {
				location = location,
				name = name,
				format = expandedFormat,
			})
		end
	end

	return result
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

				Mesh.marshalFromInputFormatToOutputFormat(
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

	self.mesh =
		love.graphics.newMesh(format, numVertices, "triangles", "static")
	do
		local staticBuffer = self.buffers.static
		local staticBufferInfo = self.bufferInfo.static

		if staticBuffer and staticBufferInfo then
			for _, attribute in ipairs(staticBufferInfo.format) do
				self.mesh:setAttributeEnabled(attribute.location, true)
				self.mesh:attachAttribute(attribute.location, staticBuffer)
			end
		end

		local outputBuffer = self.buffers.compute_output
		local outputBufferInfo = self.bufferInfo.compute_output

		if outputBuffer and outputBufferInfo then
			for _, attribute in ipairs(outputBufferInfo.format) do
				self.mesh:setAttributeEnabled(attribute.location, true)
				self.mesh:attachAttribute(attribute.location, outputBuffer)
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
function Mesh:getBufferByRole(role)
	return self.buffers[role]
end

--- @param role RatScratch.Graphics.Graphics3D.BufferRole?
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
