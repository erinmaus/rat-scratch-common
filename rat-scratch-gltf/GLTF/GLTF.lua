local ffi = require("ffi")
local json = require("lib.json")
local assert = require("rat-scratch-common").Debug.assert
local Path = require("rat-scratch-common").Path
local Table = require("rat-scratch-common").Table
local Common = require("rat-scratch-math").Common
local GLTFParser = require("rat-scratch-gltf.GLTF.Parser")
local GLTFTypes = require("rat-scratch-gltf.GLTF.Types")

local GLTF = {}

--- @param filename string
function GLTF.loadFromFilesystem(filename)
	local file = love.filesystem.openFile(filename, "r")
	return GLTF.loadFromFile(filename, file)
end

--- @param file love.File
function GLTF.loadFromFile(filename, file)
	local magic = file:read(4)
	assert(magic, "could not data from file: %s", filename)

	if magic == "glTF" then
		return GLTF.loadGLBFromFile(filename, file)
	else
		file:seek(0)
		return GLTF.loadJSONFromFile(filename, file)
	end
end

--- comment
--- @param data love.Data?
--- @param ... love.Data?
local function _size(data, ...)
	if not data then
		return 0
	end

	return data:getSize() + _size(...)
end

--- @param pointer ffi.cdata*
--- @param data love.Data?
--- @param ... love.Data?
local function _append(pointer, data, ...)
	if not data then
		return
	end

	ffi.copy(pointer, data:getFFIPointer(), data:getSize())

	return _append(ffi.cast("uint8_t *", pointer) + data:getSize(), ...)
end

--- @param ... love.Data?
--- @return love.ByteData
local function _merge(...)
	local totalSize = _size(...)
	local result = love.data.newByteData(totalSize)
	_append(result:getFFIPointer(), ...)

	return result
end

--- @param parser RatScratch.GLTF.GLTFParser
function GLTF.toGLB(parser)
	local headerMagic = love.data.newByteData("glTF")
	local headerChunk =
		love.data.pack("data", "<I4<I4", GLTFTypes.GLB_VERSION, 0)

	local json = json.encode(parser:getJSON())
	local jsonSize = #json
	if Common.isMultipleOf(jsonSize, 4) then
		jsonSize = Common.nextMultiple(jsonSize, 4)
	end

	local jsonChunkHeader =
		love.data.pack("data", "<I4<I4", jsonSize, GLTFTypes.GLBChunkTypes.json)
	local jsonData = love.data.newByteData(jsonSize)
	ffi.copy(jsonData:getFFIPointer(), json)

	local binaryData = parser:getData()
	local binaryDataSize = binaryData:getSize()
	if not Common.isMultipleOf(binaryDataSize, 4) then
		binaryDataSize = Common.nextMultiple(binaryDataSize, 4)

		local paddedBinaryData = love.data.newByteData(binaryDataSize)
		ffi.copy(
			paddedBinaryData:getFFIPointer(),
			binaryData:getFFIPointer(),
			binaryData:getSize()
		)

		binaryData = paddedBinaryData
	end

	local binaryChunkHeader = love.data.pack(
		"data",
		"<I4<I4",
		binaryDataSize,
		GLTFTypes.GLBChunkTypes.bin
	)

	local result = _merge(
		headerMagic,
		headerChunk,
		jsonChunkHeader,
		jsonData,
		binaryChunkHeader,
		binaryData
	)

	result:setUInt32(8, result:getSize())
	return result
end

--- @param filename string
--- @param parser RatScratch.GLTF.GLTFParser
--- @return boolean, string?
function GLTF.saveGLB(filename, parser)
	local data = GLTF.toGLB(parser)

	local success, message = love.filesystem.write(filename, data)
	if not success then
		return success, message
	end

	return true
end

--- @param gltfFilename string
--- @param binaryFilename string
--- @param parser RatScratch.GLTF.GLTFParser
--- @return boolean, string?
function GLTF.saveGLTF(gltfFilename, binaryFilename, parser)
	local root = Table.deepClone(parser:getJSON())
	local bin = parser:getData()

	root.buffers = {
		{
			uri = Path.makeRelative(gltfFilename, binaryFilename),
			byteLength = bin:getSize(),
		},
	}

	local success, message =
		love.filesystem.write(gltfFilename, json.encode(root))
	if not success then
		return success, message
	end

	success, message = love.filesystem.write(binaryFilename, bin)
	if not success then
		return success, message
	end

	return true
end

--- @param file love.File
function GLTF.parseGLBHeader(file)
	local header, headerBytesRead = file:read(8)
	assert(
		headerBytesRead == 8,
		"file too small for GLB; only read %d bytes after header",
		headerBytesRead
	)

	local version = love.data.unpack("<I4I4", header)
	assert(
		version == GLTFTypes.GLB_VERSION,
		"GLB version mismatch; expected %d, got %d",
		GLTFTypes.GLB_VERSION,
		version
	)
end

--- @param file love.File
function GLTF.parseGLBBody(file)
	local jsonData, binaryData
	while true do
		local chunkHeader, chunkBytesRead = file:read(8)
		if chunkBytesRead < 8 then
			break
		end

		local chunkLength, chunkTypeID = love.data.unpack("<I4I4", chunkHeader)
		--- @cast chunkLength integer
		--- @cast chunkTypeID integer

		local chunkType = GLTFTypes.GLBChunkTypes[chunkTypeID]
		if chunkType == "json" then
			assert(jsonData == nil, "multiple JSON chunks found in GLB")
			jsonData = file:read(chunkLength)
		elseif chunkType == "bin" then
			assert(
				binaryData == nil,
				"multiple binary data chunks found in GLB"
			)
			binaryData = file:read(chunkLength)
		else
			file:seek(file:tell() + chunkLength)
		end
	end

	assert(jsonData ~= nil, "no JSON data in GLB")
	return jsonData, binaryData
end

--- @param file love.File
--- @return RatScratch.GLTF.GLTFParser
function GLTF.loadGLBFromFile(filename, file)
	GLTF.parseGLBHeader(file)

	local jsonData, binaryData = GLTF.parseGLBBody(file)

	--- @type RatScratch.GLTF.GLTF
	local root = json.decode(jsonData)

	return GLTFParser(filename, root, love.data.newByteData(binaryData))
end

--- @param filename string
--- @param file love.File
function GLTF.loadJSONFromFile(filename, file)
	--- @type RatScratch.GLTF.GLTF
	local root = json.decode(file:read())

	assert(
		root and root.asset and root.asset.version == GLTFTypes.GLTF_VERSION,
		"GLTF version mismatch in JSON; expected %s",
		GLTFTypes.GLTF_VERSION
	)

	return GLTFParser(filename, root)
end

return GLTF
