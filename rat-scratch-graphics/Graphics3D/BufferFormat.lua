local ffi = require("ffi")
local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Table = require("rat-scratch-common").Table
local Common = require("rat-scratch-math").Common

--- @alias RatScratch.Graphics.Graphics3D.BufferAttributeFormat "float" | "floatvec2" | "floatvec3" | "floatvec4" | "int32" | "int32vec2" | "int32vec3" | "int32vec4" | "uint32" | "uint32vec2" | "uint32vec3" | "uint32vec4"
--- @alias RatScratch.Graphics.Graphics3D.BufferAttributeName "VertexPosition" | "VertexTexCoord" | "VertexColor" | "VertexNormal" | "VertexBoneIndex" | "VertexBoneWeight"

--- @class RatScratch.Graphics.Graphics3D.BufferFormatAttribute
--- @field public location integer
--- @field public name RatScratch.Graphics.Graphics3D.BufferAttributeName | string
--- @field public format RatScratch.Graphics.Graphics3D.BufferAttributeFormat | string
local BufferFormatAttribute = {}

--- @class RatScratch.Graphics.Graphics3D.BufferFormat : RatScratch.Common.BaseObject
--- @overload fun(format: RatScratch.Graphics.Graphics3D.BufferFormatAttribute[]): RatScratch.Graphics.Graphics3D.BufferFormat
--- @field locationToAttribute table<integer, string>
--- @field attributeToLocation table<string, integer>
--- @field index table<string | integer, integer>
local BufferFormat = Object()

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

--- @param name RatScratch.Graphics.Graphics3D.BufferAttributeName | string
--- @return number
function BufferFormat.getFormatAttributeLocationFromName(name)
	return ATTRIBUTE_NAME_TO_LOCATION[name] or -1
end

--- @param name RatScratch.Graphics.Graphics3D.BufferAttributeName | string
--- @return boolean
function BufferFormat.isValidAttributeName(name)
	return ATTRIBUTE_NAME_TO_LOCATION[name] ~= nil
end

--- @param location number
--- @return boolean
function BufferFormat.isReservedLocation(location)
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
	floatmat2x2 = 4,
	floatmat2x3 = 6,
	floatmat2x4 = 8,
	floatmat3x2 = 6,
	floatmat3x3 = 9,
	floatmat3x4 = 12,
	floatmat4x1 = 4,
	floatmat4x2 = 8,
	floatmat4x3 = 12,
	floatmat4x4 = 16,
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
	floatmat2x2 = "floatmat4x4",
	floatmat2x3 = "floatmat4x4",
	floatmat2x4 = "floatmat4x4",
	floatmat3x2 = "floatmat4x4",
	floatmat3x3 = "floatmat4x4",
	floatmat3x4 = "floatmat4x4",
	floatmat4x1 = "floatmat4x4",
	floatmat4x2 = "floatmat4x4",
	floatmat4x3 = "floatmat4x4",
	floatmat4x4 = "floatmat4x4",
}

local SCALAR_TYPE = {
	float = "float",
	floatvec2 = "float",
	floatvec3 = "float",
	floatvec4 = "float",
	int32 = "int32",
	int32vec2 = "int32",
	int32vec3 = "int32",
	int32vec4 = "int32",
	uint32 = "uint32",
	uint32vec2 = "uint32",
	uint32vec3 = "uint32",
	uint32vec4 = "uint32",
	floatmat2x2 = "float",
	floatmat2x3 = "float",
	floatmat2x4 = "float",
	floatmat3x2 = "float",
	floatmat3x3 = "float",
	floatmat3x4 = "float",
	floatmat4x1 = "float",
	floatmat4x2 = "float",
	floatmat4x3 = "float",
	floatmat4x4 = "float",
}

local ATTRIBUTE_NAME_DEFAULT_COMPONENT_VALUES = {
	VertexPosition = { 0, 0, 0, 1 },
	VertexTexCoord = { 0, 0, 0, 0 },
	VertexColor = { 1, 1, 1, 1 },
	VertexNormal = { 0, 0, 0, 0 },
	VertexBoneIndex = { 0, 0, 0, 0 },
	VertexBoneWeight = { 1, 0, 0, 0 },
}

local DEFAULT_MISSING_COMPONENT_VALUES =
	{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }

--- @param format string
function BufferFormat.getFormatScalar(format)
	return SCALAR_TYPE[format] or "float"
end

--- @param format RatScratch.Graphics.Graphics3D.BufferFormatAttribute[]
--- @return integer
function BufferFormat.getFormatComponentCount(format)
	local count = 0

	for i, attribute in ipairs(format) do
		local componentCount = ATTRIBUTE_COMPONENTS[attribute.format]
		assert(
			componentCount,
			"attribute %s (index = %d) does not have a valid format: %s",
			attribute.name,
			i,
			attribute.format
		)

		count = count + componentCount
	end

	return count
end

--- @param format RatScratch.Graphics.Graphics3D.BufferFormatAttribute[]
--- @return integer
function BufferFormat.getFormatStride(format)
	local stride = 0
	local totalComponentCount = 0
	local largestAlignment = 0

	for i, attribute in ipairs(format) do
		local componentCount = ATTRIBUTE_COMPONENTS[attribute.format]
		totalComponentCount = totalComponentCount + componentCount

		assert(
			componentCount,
			"attribute %s (index = %d) does not have a valid format: %s",
			attribute.name,
			i,
			attribute.format
		)

		local adjustedComponentCount
		if
			not Common.isMultipleOf(componentCount, 4)
			and not Common.isMultipleOf(componentCount, 2)
			and componentCount ~= 1
		then
			adjustedComponentCount = 4
		else
			adjustedComponentCount = math.min(componentCount, 4)
		end

		local alignmentBytes = adjustedComponentCount * 4
		local nextStride = stride

		local strideRemainder = nextStride % alignmentBytes
		if strideRemainder == 0 then
			stride = nextStride
		else
			stride = nextStride + alignmentBytes - strideRemainder
		end

		stride = stride + componentCount * 4
		largestAlignment = math.max(largestAlignment, alignmentBytes)
	end

	if not Common.isMultipleOf(stride, largestAlignment) then
		stride = Common.nextMultiple(stride, largestAlignment)
	end

	return stride
end

--- @param format RatScratch.Graphics.Graphics3D.BufferFormatAttribute[]
--- @param attributeName string
--- @return integer?
function BufferFormat.getFormatByteOffset(format, attributeName)
	local byteIndex = 0
	for i, attribute in ipairs(format) do
		local componentCount = ATTRIBUTE_COMPONENTS[attribute.format]
		assert(
			componentCount,
			"attribute %s (index = %d) does not have a valid format: %s",
			attribute.name,
			i,
			attribute.format
		)

		local adjustedComponentCount
		if
			not Common.isMultipleOf(componentCount, 4)
			and not Common.isMultipleOf(componentCount, 2)
			and componentCount ~= 1
		then
			adjustedComponentCount = 4
		else
			adjustedComponentCount = math.min(componentCount, 4)
		end

		local alignmentBytes = adjustedComponentCount * 4
		local nextByteIndex = byteIndex

		local bytesRemainder = nextByteIndex % alignmentBytes
		if bytesRemainder == 0 then
			byteIndex = nextByteIndex
		else
			byteIndex = nextByteIndex + alignmentBytes - bytesRemainder
		end

		if attribute.name == attributeName then
			return byteIndex
		end

		byteIndex = byteIndex + componentCount * 4
	end

	return nil
end

--- @param format RatScratch.Graphics.Graphics3D.BufferFormatAttribute[]
--- @param attributeName string
--- @return integer?, integer?
function BufferFormat.getFormatAttributeCountOffset(format, attributeName)
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

function BufferFormat.getFormatVertexAttributeValues(
	count,
	offset,
	attributeName,
	vertex
)
	local defaultValues = ATTRIBUTE_NAME_DEFAULT_COMPONENT_VALUES[attributeName]
		or DEFAULT_MISSING_COMPONENT_VALUES
	local dx, dy, dz, dw = unpack(defaultValues)

	local x, y, z, w = unpack(vertex, offset, offset + count)

	return x or dx, y or dy, z or dz, w or dw
end

local FORMAT_POOL = setmetatable({}, { __mode = "k" })

--- @param format RatScratch.Graphics.Graphics3D.BufferFormatAttribute[]
--- @return RatScratch.Graphics.Graphics3D.BufferFormat
function BufferFormat.get(format)
	local result = FORMAT_POOL[format]
	if not result then
		result = BufferFormat(format)
		FORMAT_POOL[format] = result
	end

	return result
end

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[] | RatScratch.Graphics.Graphics3D.BufferFormat
--- @param baseFormat RatScratch.Graphics.Graphics3D.BufferFormatAttribute[]
function BufferFormat.extendFormat(format, baseFormat)
	--- @type RatScratch.Graphics.Graphics3D.BufferFormat
	local formatInstance = Object.isDerived(
		Object.getType(format),
		BufferFormat
	) and format or BufferFormat.get(format)

	--- @type RatScratch.Graphics.Graphics3D.BufferFormat
	local baseFormatInstance = Object.isDerived(
		Object.getType(baseFormat),
		BufferFormat
	) and baseFormat or BufferFormat.get(baseFormat)

	return baseFormatInstance:extend(formatInstance)
end

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[] | RatScratch.Graphics.Graphics3D.BufferFormat
--- @param vertex number[]
--- @param offset? number
function BufferFormat.resetValue(format, vertex, offset)
	--- @type RatScratch.Graphics.Graphics3D.BufferFormat
	local formatInstance = Object.isDerived(
		Object.getType(format),
		BufferFormat
	) and format or BufferFormat.get(format)
	offset = offset or 0

	for _, attribute in ipairs(formatInstance.format) do
		formatInstance:fillExpandedValues(attribute.location, vertex, offset)
	end
end

--- @param inputFormat RatScratch.Graphics.Graphics3D.MeshFormatAttribute[] | RatScratch.Graphics.Graphics3D.BufferFormat
--- @param inputVertex number[]
--- @param outputFormat RatScratch.Graphics.Graphics3D.MeshFormatAttribute[] | RatScratch.Graphics.Graphics3D.BufferFormat
--- @param outputVertex number[]
--- @param inputVertexOffset? integer
--- @param outputVertexOffset? integer
function BufferFormat.marshalFromInputFormatToOutputFormat(
	inputFormat,
	inputVertex,
	outputFormat,
	outputVertex,
	inputVertexOffset,
	outputVertexOffset
)
	--- @type RatScratch.Graphics.Graphics3D.BufferFormat
	local inputFormatInstance = Object.isDerived(
		Object.getType(inputFormat),
		BufferFormat
	) and inputFormat or BufferFormat.get(inputFormat)

	--- @type RatScratch.Graphics.Graphics3D.BufferFormat
	local outputFormatInstance = Object.isDerived(
		Object.getType(outputFormat),
		BufferFormat
	) and outputFormat or BufferFormat.get(outputFormat)

	inputVertexOffset = inputVertexOffset or 0
	outputVertexOffset = outputVertexOffset or 0

	for _, attribute in ipairs(inputFormatInstance.format) do
		if outputFormatInstance:hasAttribute(attribute.location) then
			local inputCount, inputOffset =
				inputFormatInstance:getCountOffset(attribute.location)

			outputFormatInstance:fillExpandedValues(
				attribute.location,
				outputVertex,
				outputVertexOffset,
				unpack(
					inputVertex,
					inputOffset + inputVertexOffset,
					inputOffset + inputVertexOffset + (inputCount - 1)
				)
			)
		end
	end

	for _, attribute in ipairs(outputFormatInstance.format) do
		if not inputFormatInstance:hasAttribute(attribute.location) then
			outputFormatInstance:fillExpandedValues(
				attribute.location,
				outputVertex,
				outputVertexOffset
			)
		end
	end
end

--- @type table<string, fun<T>(data: T, offset: integer, count?: integer, result: number[], resultOffset: integer): ...: number>
local GET_FUNCS

--- @type fun(data: love.Data): ffi.cdata* | love.Data
local _dataGetPointer

if jit.status() then
	_dataGetPointer = function(data)
		return ffi.cast("uint8_t*", data:getFFIPointer())
	end

	local function _get(pointer, count, result, resultOffset)
		for i = 1, count do
			result[resultOffset + i - 1] = pointer[0]
			pointer = pointer + 1
		end
	end

	local function _dataGetFloat(data, offset, count, result, resultOffset)
		local pointer = ffi.cast("float*", data + offset)
		return _get(pointer, count, result, resultOffset)
	end

	local function _dataGetUInt32(data, offset, count, result, resultOffset)
		local pointer = ffi.cast("uint32_t*", data + offset)
		return _get(pointer, count, result, resultOffset)
	end

	local function _dataGetInt32(data, offset, count, result, resultOffset)
		local pointer = ffi.cast("int32_t*", data + offset)
		return _get(pointer, count, result, resultOffset)
	end

	GET_FUNCS = {
		float = _dataGetFloat,
		uint32 = _dataGetUInt32,
		int32 = _dataGetInt32,
	}
else
	_dataGetPointer = function(data)
		return data
	end

	local function _dataGetFloat(data, offset, count, result, resultOffset)
		return Table.copy(
			result,
			resultOffset,
			resultOffset + count - 1,
			data:getFloat(offset, count)
		)
	end

	local function _dataGetUInt32(data, offset, count, result, resultOffset)
		return Table.copy(
			result,
			resultOffset,
			resultOffset + count - 1,
			data:getUInt32(offset, count)
		)
	end

	local function _dataGetInt32(data, offset, count, result, resultOffset)
		return Table.copy(
			result,
			resultOffset,
			resultOffset + count - 1,
			data:getInt32(offset, count)
		)
	end

	GET_FUNCS = {
		float = _dataGetFloat,
		uint32 = _dataGetUInt32,
		int32 = _dataGetInt32,
	}
end

--- @type table<string, fun<T>(data: T, offset: integer, count?: integer, source: number[], sourceOffset: integer): ...: number>
local SET_FUNCS

if jit.status() then
	local function _set(pointer, count, source, sourceOffset)
		for i = 1, count do
			pointer[0] = source[sourceOffset + i - 1]
			pointer = pointer + 1
		end
	end

	local function _dataSetFloat(data, offset, count, source, sourceOffset)
		local pointer = ffi.cast("float*", data + offset)
		return _set(pointer, count, source, sourceOffset)
	end

	local function _dataSetUInt32(data, offset, count, source, sourceOffset)
		local pointer = ffi.cast("uint32_t*", data + offset)
		return _set(pointer, count, source, sourceOffset)
	end

	local function _dataSetInt32(data, offset, count, source, sourceOffset)
		local pointer = ffi.cast("int32_t*", data + offset)
		return _set(pointer, count, source, sourceOffset)
	end

	SET_FUNCS = {
		float = _dataSetFloat,
		uint32 = _dataSetUInt32,
		int32 = _dataSetInt32,
	}
else
	local function _dataSetFloat(data, offset, count, source, sourceOffset)
		data:setFloat(
			offset,
			unpack(source, sourceOffset, sourceOffset + count - 1)
		)
	end

	local function _dataSetUInt32(data, offset, count, source, sourceOffset)
		data:setUInt32(
			offset,
			unpack(source, sourceOffset, sourceOffset + count - 1)
		)
	end

	local function _dataSetInt32(data, offset, count, source, sourceOffset)
		data:setInt32(
			offset,
			unpack(source, sourceOffset, sourceOffset + count - 1)
		)
	end

	SET_FUNCS = {
		float = _dataSetFloat,
		uint32 = _dataSetUInt32,
		int32 = _dataSetInt32,
	}
end

local ATTRIBUTES = {}

--- @param formatInstance RatScratch.Graphics.Graphics3D.BufferFormat
local function _preprocessAttributeFormat(formatInstance, funcs)
	for i, attribute in ipairs(formatInstance:getFormat()) do
		local f = ATTRIBUTES[i]
		if not f then
			f = {}
			ATTRIBUTES[i] = f
		end

		f[1], f[2] = formatInstance:getCountOffset(attribute.location)
		f[3] = formatInstance:getByteOffset(attribute.location)
		f[4] = funcs[formatInstance:getScalarType(attribute.location)]
	end

	return ATTRIBUTES
end

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[] | RatScratch.Graphics.Graphics3D.BufferFormat
--- @param sourceIndex integer
--- @param destinationOffset integer
--- @param count integer
--- @param source number[]
--- @param destination love.ByteData
function BufferFormat.copyFromFlatTableToByteData(
	format,
	sourceIndex,
	destinationOffset,
	count,
	source,
	destination
)
	local funcs = SET_FUNCS
	local pointer = _dataGetPointer(destination)

	--- @type RatScratch.Graphics.Graphics3D.BufferFormat
	local formatInstance = Object.isDerived(
		Object.getType(format),
		BufferFormat
	) and format or BufferFormat.get(format)

	local attributeInfo = _preprocessAttributeFormat(formatInstance, funcs)

	local componentCount = formatInstance:getComponentCount()
	local stride = formatInstance:getStride()

	for offset = 1, count do
		local k =
			Table.indexToStride(sourceIndex + (offset - 1), componentCount)

		for index in ipairs(formatInstance.format) do
			local info = attributeInfo[index]
			local attributeComponentCount, attributeOffset = info[1], info[2]
			local byteOffset = info[3]
			local set = info[4]

			local i = k + (attributeOffset - 1)

			set(
				pointer,
				(offset - 1) * stride + byteOffset + destinationOffset,
				attributeComponentCount,
				source,
				i
			)
		end
	end
end

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[] | RatScratch.Graphics.Graphics3D.BufferFormat
--- @param sourceIndex integer
--- @param destinationOffset integer
--- @param count integer
--- @param source number[][]
--- @param destination love.ByteData
function BufferFormat.copyFromTableToByteData(
	format,
	sourceIndex,
	destinationOffset,
	count,
	source,
	destination
)
	local funcs = SET_FUNCS
	local pointer = _dataGetPointer(destination)

	--- @type RatScratch.Graphics.Graphics3D.BufferFormat
	local formatInstance = Object.isDerived(
		Object.getType(format),
		BufferFormat
	) and format or BufferFormat.get(format)

	local attributeInfo = _preprocessAttributeFormat(formatInstance, funcs)

	local stride = formatInstance:getStride()

	for offset = 1, count do
		local k = sourceIndex + (offset - 1)
		local vertex = source[k]

		for index in ipairs(formatInstance.format) do
			local info = attributeInfo[index]
			local attributeComponentCount, attributeOffset = info[1], info[2]
			local byteOffset = info[3]
			local set = info[4]

			set(
				pointer,
				(offset - 1) * stride + byteOffset + destinationOffset,
				attributeComponentCount,
				vertex,
				attributeOffset
			)
		end
	end
end

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[] | RatScratch.Graphics.Graphics3D.BufferFormat
--- @param sourceOffset integer
--- @param destinationIndex integer
--- @param count integer
--- @param source love.ByteData
--- @param destination number[]
function BufferFormat.copyFromByteDataToFlatTable(
	format,
	sourceOffset,
	destinationIndex,
	count,
	source,
	destination
)
	local funcs = GET_FUNCS
	local pointer = _dataGetPointer(source)

	--- @type RatScratch.Graphics.Graphics3D.BufferFormat
	local formatInstance = Object.isDerived(
		Object.getType(format),
		BufferFormat
	) and format or BufferFormat.get(format)

	local attributeInfo = _preprocessAttributeFormat(formatInstance, funcs)

	local componentCount = formatInstance:getComponentCount()
	local stride = formatInstance:getStride()

	for offset = 1, count do
		local k = Table.indexToStride(
			destinationIndex + (offset - 1),
			componentCount
		) - 1

		for index in ipairs(formatInstance.format) do
			local info = attributeInfo[index]
			local attributeComponentCount, attributeOffset = info[1], info[2]
			local byteOffset = info[3]
			local get = info[4]

			local i = k + attributeOffset

			get(
				pointer,
				(offset - 1) * stride + byteOffset + sourceOffset,
				attributeComponentCount,
				destination,
				i
			)
		end
	end
end

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[] | RatScratch.Graphics.Graphics3D.BufferFormat
--- @param sourceOffset integer
--- @param destinationIndex integer
--- @param count integer
--- @param source love.ByteData
--- @param destination number[][]
function BufferFormat.copyFromByteDataToTable(
	format,
	sourceOffset,
	destinationIndex,
	count,
	source,
	destination
)
	local funcs = GET_FUNCS
	local pointer = _dataGetPointer(source)

	--- @type RatScratch.Graphics.Graphics3D.BufferFormat
	local formatInstance = Object.isDerived(
		Object.getType(format),
		BufferFormat
	) and format or BufferFormat.get(format)

	local attributeInfo = _preprocessAttributeFormat(formatInstance, funcs)

	local stride = formatInstance:getStride()

	for offset = 1, count do
		local k = destinationIndex + (offset - 1)
		local vertex = destination[k]

		for index in ipairs(formatInstance.format) do
			local info = attributeInfo[index]
			local attributeComponentCount, attributeOffset = info[1], info[2]
			local byteOffset = info[3]
			local get = info[4]

			get(
				pointer,
				(offset - 1) * stride + byteOffset + sourceOffset,
				attributeComponentCount,
				vertex,
				attributeOffset
			)
		end
	end
end

--- @param format RatScratch.Graphics.Graphics3D.BufferFormatAttribute[]
function BufferFormat:new(format)
	self.format = Table.new(#format, 0)
	self.stride = BufferFormat.getFormatStride(format)
	self.componentCount = BufferFormat.getFormatComponentCount(format)

	self.locationToAttribute = {}
	self.attributeToLocation = {}
	self.index = {}
	self.attributeInfo = Table.new(#format, 0)

	for i, attribute in ipairs(format) do
		self.format[i] = {
			location = attribute.location,
			name = attribute.name,
			format = attribute.format,
		}

		local count, offset =
			BufferFormat.getFormatAttributeCountOffset(format, attribute.name)
		assert(
			count and offset,
			"expected count and offset for attribute '%s'",
			attribute.name
		)

		local byteOffset =
			BufferFormat.getFormatByteOffset(format, attribute.name)

		assert(
			not self.locationToAttribute[attribute.location],
			"attribute location '%d' already reserved",
			attribute.location
		)
		assert(
			not self.attributeToLocation[attribute.name],
			"attribute name '%s' already reserved",
			attribute.name
		)

		self.locationToAttribute[attribute.location] = attribute.name
		self.attributeToLocation[attribute.name] = attribute.location

		self.index[attribute.location] = i
		self.index[attribute.name] = i

		local defaultValues =
			ATTRIBUTE_NAME_DEFAULT_COMPONENT_VALUES[attribute.name]
		if not defaultValues then
			defaultValues = Table.new(count, 0)
			for i = 1, count do
				defaultValues[i] = 0
			end
		end

		self.attributeInfo[i] = {
			location = attribute.location,
			name = attribute.name,
			format = attribute.format,
			scalar = BufferFormat.getFormatScalar(attribute.format),
			count = count,
			offset = offset,
			byteOffset = byteOffset,
			defaultValues = defaultValues,
		}
	end
end

function BufferFormat:getFormat()
	return self.format
end

function BufferFormat:getComponentCount()
	return self.componentCount
end

function BufferFormat:getStride()
	return self.stride
end

--- @param key1 string | integer
--- @param key2? string | integer
function BufferFormat:hasAttribute(key1, key2)
	if key1 and key2 then
		return self.index[key1] == self.index[key2] and self.index[key1]
	end

	return self.index[key1] ~= nil
end

--- @param key string | integer
function BufferFormat:getAttributeName(key)
	local attributeInfo = self.attributeInfo[self.index[key]]
	assert(
		attributeInfo,
		"attribute location/name '%s' not valid for format",
		key
	)

	return attributeInfo.name
end

--- @param key string | integer
function BufferFormat:getAttributeLocation(key)
	local attributeInfo = self.attributeInfo[self.index[key]]
	assert(
		attributeInfo,
		"attribute location/name '%s' not valid for format",
		key
	)

	return attributeInfo.location
end

--- @param key string | integer
function BufferFormat:getAttributeFormat(key)
	local attributeInfo = self.attributeInfo[self.index[key]]
	assert(
		attributeInfo,
		"attribute location/name '%s' not valid for format",
		key
	)

	return attributeInfo.format
end

--- @param key string | integer
--- @return integer, integer
function BufferFormat:getCountOffset(key)
	local attributeInfo = self.attributeInfo[self.index[key]]
	assert(
		attributeInfo,
		"attribute location/name '%s' not valid for format",
		key
	)

	return attributeInfo.count, attributeInfo.offset
end

--- @param key string | integer
--- @return integer
function BufferFormat:getByteOffset(key)
	local attributeInfo = self.attributeInfo[self.index[key]]
	assert(
		attributeInfo,
		"attribute location/name '%s' not valid for format",
		key
	)

	return attributeInfo.byteOffset
end

--- @param key string | integer
function BufferFormat:getScalarType(key)
	local attributeInfo = self.attributeInfo[self.index[key]]
	assert(
		attributeInfo,
		"attribute location/name '%s' not valid for format",
		key
	)

	return attributeInfo.scalar
end

local function _getOrDefault(defaultValues, index, value, ...)
	if index >= #defaultValues then
		return value or defaultValues[index] or 0
	end

	return value or defaultValues[index],
		_getOrDefault(defaultValues, index + 1, ...)
end

--- @param key string | integer
--- @param ... number | nil
--- @return number ...
function BufferFormat:getExpandedValues(key, ...)
	local attributeInfo = self.attributeInfo[self.index[key]]
	assert(
		attributeInfo,
		"attribute location/name '%s' not valid for format",
		key
	)

	return _getOrDefault(attributeInfo.defaultValues, 1, ...)
end

local function _copyOrDefault(
	defaultValues,
	destination,
	offset,
	index,
	value,
	...
)
	destination[offset + index] = value or defaultValues[index] or 0

	if index >= #defaultValues then
		return
	end

	return _copyOrDefault(defaultValues, destination, offset, index + 1, ...)
end

--- @param key string | integer
--- @param destination number[]
--- @param destinationOffset integer
--- @param ... number | nil
function BufferFormat:fillExpandedValues(
	key,
	destination,
	destinationOffset,
	...
)
	local attributeInfo = self.attributeInfo[self.index[key]]
	assert(
		attributeInfo,
		"attribute location/name '%s' not valid for format",
		key
	)

	return _copyOrDefault(
		attributeInfo.defaultValues,
		destination,
		destinationOffset + attributeInfo.offset - 1,
		1,
		...
	)
end

--- @param other RatScratch.Graphics.Graphics3D.BufferFormat
--- @return RatScratch.Graphics.Graphics3D.BufferFormatAttribute[]
function BufferFormat:extend(other)
	--- @type RatScratch.Graphics.Graphics3D.BufferFormatAttribute[]
	local result = {}

	for _, attribute in ipairs(self.format) do
		local format
		if other:hasAttribute(attribute.location, attribute.name) then
			local selfComponentCount = self:getCountOffset(attribute.location)
			local otherComponentCount = other:getCountOffset(attribute.location)

			if selfComponentCount > otherComponentCount then
				format = attribute.format
			else
				format = other:getAttributeFormat(attribute.location)
			end
		end

		table.insert(result, {
			location = attribute.location,
			name = attribute.name,
			format = format,
		})
	end

	for _, attribute in ipairs(other.format) do
		if not self:hasAttribute(attribute.location, attribute.name) then
			table.insert(result, {
				location = attribute.location,
				name = attribute.name,
				format = attribute.format,
			})
		end
	end

	return result
end

return BufferFormat
