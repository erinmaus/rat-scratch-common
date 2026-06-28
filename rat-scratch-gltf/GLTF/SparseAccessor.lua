local Table = require("rat-scratch-common").Table
local GLTFAccessor = require("rat-scratch-gltf.GLTF.Accessor")

--- @class RatScratch.GLTF.GLTFSparseAccessor
--- @field private accessor RatScratch.GLTF.GLTFAccessor
--- @field private values table<number, number[]>
local GLTFSparseAccessor = {}
local GLTFSparseAccessorMetatable = { __index = GLTFSparseAccessor }

--- @param parser RatScratch.GLTF.GLTFParser
--- @param accessor RatScratch.GLTF.Accessor
--- @return table<number, number[]>
function GLTFSparseAccessor.getValues(parser, accessor)
	local indices = GLTFAccessor(parser, {
		bufferView = accessor.sparse.indices.bufferView,
		byteOffset = accessor.sparse.indices.byteOffset or 0,
		componentType = accessor.sparse.indices.componentType,
		type = "SCALAR",
		count = accessor.sparse.count,
	})

	local values = GLTFAccessor(parser, {
		bufferView = accessor.sparse.values.bufferView,
		byteOffset = accessor.sparse.values.byteOffset or 0,
		type = accessor.type,
		componentType = accessor.componentType,
		count = accessor.sparse.count,
	})

	local result = {}

	local indexValue = {}
	for i = 1, accessor.sparse.count do
		indices:read(i, indexValue)

		local value = {}
		values:read(i, value)

		local index = indexValue[1] + 1
		result[index] = value
	end

	return result
end

--- @param parser RatScratch.GLTF.GLTFParser
--- @param accessor RatScratch.GLTF.Accessor
function GLTFSparseAccessor.new(parser, accessor)
	local values = GLTFSparseAccessor.getValues(parser, accessor)

	return setmetatable({
		accessor = GLTFAccessor(parser, accessor),
		values = values,
	}, GLTFSparseAccessorMetatable)
end

function GLTFSparseAccessor:getDataOffset()
	return self.accessor:getDataOffset()
end

function GLTFSparseAccessor:getDataStride()
	return self.accessor:getDataStride()
end

function GLTFSparseAccessor:getComponentType()
	return self.accessor:getComponentType()
end

function GLTFSparseAccessor:getComponentSize()
	return self.accessor:getComponentSize()
end

function GLTFSparseAccessor:getComponentCount()
	return self.accessor:getComponentCount()
end

function GLTFSparseAccessor:getElementType()
	return self.accessor:getElementType()
end

function GLTFSparseAccessor:getElementCount()
	return self.accessor:getElementCount()
end

function GLTFSparseAccessor:getNormalized()
	return self.accessor:getNormalized()
end

--- @param index number
--- @param value number[]
function GLTFSparseAccessor:read(index, value)
	if self.values[index] then
		Table.clear(value)

		for i, v in ipairs(self.values[index]) do
			value[i] = v
		end
	else
		self.accessor:read(index, value)
	end
end

return GLTFSparseAccessor
