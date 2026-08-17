--- @meta

--- @class RatScratch.GLTF.WorkingAccessor : RatScratch.GLTF.NamedObject
--- @field public bufferView RatScratch.GLTF.WorkingBufferView
--- @field public componentType RatScratch.GLTF.AccessorComponentType
--- @field public normalized? boolean
--- @field public count integer
--- @field public type RatScratch.GLTF.AccessorElementType
--- @field public min? number[]
--- @field public max? number[]
local WorkingAccessor = {}

--- @class RatScratch.GLTF.WorkingBufferView
--- @field public data love.Data
--- @field public dataLength? integer
--- @field public dataOffset? integer
--- @field public dataStride? integer
local WorkingBufferView = {}
