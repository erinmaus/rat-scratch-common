local json = require("lib.json")
local assert = require("rat-scratch-common").Debug.assert
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
