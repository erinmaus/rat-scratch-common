local Table = require("rat-scratch-common").Table
local Object = require("rat-scratch-common").Object

--- @class RatScratch.GLTF.GLTFAccessor : RatScratch.Common.BaseObject
--- @overload fun(parser: RatScratch.GLTF.GLTFParser, accessor: RatScratch.GLTF.Accessor): RatScratch.GLTF.GLTFAccessor
--- @field private data love.Data
--- @field private get string
--- @field private dataOffset number
--- @field private dataLength number
--- @field private dataStride number
--- @field private componentType RatScratch.GLTF.AccessorComponentType
--- @field private componentSize number
--- @field private componentCount number
--- @field private elementType string
--- @field private elementCount number
--- @field private normalized boolean
--- @field private normalizedPositiveDenominator number
--- @field private normalizedNegativeDenominator number
local GLTFAccessor = Object()

--- @param parser RatScratch.GLTF.GLTFParser
--- @param accessor RatScratch.GLTF.Accessor
function GLTFAccessor:new(parser, accessor)
    local bufferView = parser:getBufferView(accessor.bufferView)
    local bufferData = parser:getBufferData(bufferView.buffer)
    local componentTypeInfo = parser:getAccessorComponentTypeInfo(accessor.componentType)
    local elementTypeCount = parser:getAccessorElementTypeCount(accessor.type)
    local get = parser:getComponentGetter(accessor.componentType)

    assert(not accessor.normalized or (componentTypeInfo.integer and componentTypeInfo.positive ~= 0 and componentTypeInfo.negative ~= 0), "only some integer types can be normalized")

	self.data = bufferData
	self.get = get
	self.dataOffset = (accessor.byteOffset or 0) + (bufferView and bufferView.byteOffset or 0)
	self.dataStride = bufferView and bufferView.byteStride or (componentTypeInfo.size * elementTypeCount)
	self.componentType = accessor.componentType
	self.componentSize = componentTypeInfo.size
	self.componentCount = elementTypeCount
	self.elementType = accessor.type or "SCALAR"
	self.elementCount = accessor.count
	self.normalized = accessor.normalized or false
	self.normalizedPositiveDenominator = componentTypeInfo.positive
	self.normalizedNegativeDenominator = componentTypeInfo.negative
end

function GLTFAccessor:getDataOffset()
    return self.dataOffset
end

function GLTFAccessor:getDataStride()
    return self.dataStride
end

function GLTFAccessor:getComponentType()
    return self.componentType
end

function GLTFAccessor:getComponentSize()
    return self.componentSize
end

function GLTFAccessor:getComponentCount()
    return self.componentCount
end

function GLTFAccessor:getElementType()
    return self.elementType
end

function GLTFAccessor:getElementCount()
    return self.elementCount
end

function GLTFAccessor:getNormalized()
    return self.normalized
end

--- @param index number
--- @param result number[]
--- @return number[]
function GLTFAccessor:read(index, result)
    Table.clear(result)

    local basePosition = self.dataOffset + (index - 1) * self.dataStride

    ---@diagnostic disable: assign-type-mismatch
    result[1], result[2], result[3], result[4],
    result[5], result[6], result[7], result[8],
    result[9], result[10], result[11], result[12],
    result[13], result[14], result[15], result[16] = self.data[self.get](self.data, basePosition, self.componentCount)

    if self.normalized then
        for i = 1, self.elementCount do
            local value = result[i]

            if value < 0 and self.normalizedNegativeDenominator > 0 then
                value = value / self.normalizedNegativeDenominator
            elseif value > 0 and self.normalizedPositiveDenominator > 0 then
                value = value / self.normalizedPositiveDenominator
            else
                error("got normalized integer, but could not normalize")
            end

            result[i] = value
        end
    end

    return result
end

return GLTFAccessor
