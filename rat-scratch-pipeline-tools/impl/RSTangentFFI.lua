local PATH = ...
local ffi = require("ffi")
local Object = require("rat-scratch-common").Object
local RatScratchModule = require("lib.rat-scratch-module")

--- @class RatScratch.Pipeline.impl.RSTangentFFI : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Pipeline.impl.RSTangentFFI
local RSTangentFFI = Object()

--- @private
RSTangentFFI._IS_INTIALIZED = false

--- @param indexData love.ByteData
--- @param indexCount integer
--- @param positionData love.ByteData
--- @param positionFormat RatScratch.Graphics.Graphics3D.BufferFormat
--- @param normalData love.ByteData
--- @param normalFormat RatScratch.Graphics.Graphics3D.BufferFormat
--- @param textureCoordinateData love.ByteData
--- @param textureCoordinateFormat RatScratch.Graphics.Graphics3D.BufferFormat
--- @return boolean, love.ByteData
function RSTangentFFI.buildTangents(
	indexData,
	indexCount,
	vertexCount,
	positionData,
	positionFormat,
	normalData,
	normalFormat,
	textureCoordinateData,
	textureCoordinateFormat
)
	local indexDataPointer = ffi.cast("uint32_t *", indexData:getFFIPointer())

	local positionDataPointer = ffi.cast(
		"float *",
		ffi.cast("uint8_t *", positionData:getFFIPointer())
			+ positionFormat:getByteOffset("VertexPosition")
	)
	local normalDataPointer = ffi.cast(
		"float *",
		ffi.cast("uint8_t *", normalData:getFFIPointer())
			+ normalFormat:getByteOffset("VertexNormal")
	)
	local textureCoordinateDataPointer = ffi.cast(
		"float *",
		ffi.cast("uint8_t *", textureCoordinateData:getFFIPointer())
			+ textureCoordinateFormat:getByteOffset("VertexTexCoord")
	)

	local tangentData =
		love.data.newByteData(vertexCount * ffi.sizeof("float") * 4)
	local tangentDataPointer = ffi.cast("float *", tangentData:getFFIPointer())

	local rsTangent = RSTangentFFI.load()
	local success = rsTangent.rat_generateTangents(
		indexDataPointer,
		indexCount,
		positionDataPointer,
		positionFormat:getStride(),
		normalDataPointer,
		normalFormat:getStride(),
		textureCoordinateDataPointer,
		textureCoordinateFormat:getStride(),
		tangentDataPointer,
		ffi.sizeof("float") * 4
	)

	return success ~= 0, tangentData
end

function RSTangentFFI.load()
	if RSTangentFFI._IS_INTIALIZED then
		return RSTangentFFI._LIBRARY
	end

	ffi.cdef([[
		int rat_generateTangents(
			uint32_t *indices,
			size_t indexCount,
			float *position,
			size_t positionStride,
			float *normal,
			size_t normalStride,
			float *textureCoordinate,
			size_t textureCoordinateStride,
			float *tangent,
			size_t tangentStride);
	]])

	RSTangentFFI._LIBRARY =
		RatScratchModule.loadLibrary(PATH, "rat_scratch_tangents")
	RSTangentFFI._IS_INTIALIZED = true

	return RSTangentFFI._LIBRARY
end

return RSTangentFFI
