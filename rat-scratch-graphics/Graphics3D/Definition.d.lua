--- @meta

--- @class RatScratch.Graphics.Graphics3D.SceneDefinition
--- @field public name? string
--- @field public models? RatScratch.Graphics.Graphics3D.ModelDefinition[]
local SceneDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.ModelDefinition
--- @field public name? string
--- @field public meshes? RatScratch.Graphics.Graphics3D.MeshDefinition[]
--- @field public skeleton? RatScratch.Graphics.Graphics3D.SkeletonDefinition
--- @field public animations? RatScratch.Graphics.Graphics3D.AnimationDefinition[]
local ModelDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.MeshDefinition
--- @field public name? string
--- @field public buffers RatScratch.Graphics.Graphics3D.MarshalBuffer[]
--- @field public format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @field public vertices number[][] | number
--- @field public indices number[] | number
--- @field public material RatScratch.Graphics.Graphics3D.MaterialDefinition?
local MeshDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.SkeletonDefinition
--- @field public name? string
--- @field public bones RatScratch.Graphics.Graphics3D.BoneDefinition[]
local SkeletonDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.BoneDefinition
--- @field public name? string
--- @field public index integer
--- @field public id number
--- @field public parentID number?
--- @field public inverseBindPoseTransform love.Transform
--- @field public transform love.Transform
--- @field public translation number[]
--- @field public rotation number[]
--- @field public scale number[]
local BoneDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.AnimationDefinition
--- @field public name? string
--- @field public channels RatScratch.Graphics.Graphics3D.AnimationChannelDefinition[]
local AnimationDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.AnimationChannelDefinition
--- @field public boneID integer
--- @field public properties RatScratch.Graphics.Graphics3D.KeyFramesDefinition[]
local AnimationChannelDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.KeyFramesDefinition
--- @field public property RatScratch.Graphics.Graphics3D.KeyFramePropertyType
--- @field public interpolation RatScratch.Graphics.Graphics3D.InterpolatorType
--- @field public frames RatScratch.Graphics.Graphics3D.KeyFrameDefinition[]
local KeyFramesDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.KeyFrameDefinition
--- @field public time number
--- @field public inTangent number[]
--- @field public value number[]
--- @field public outTangent number[]
local KeyFrameDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.MaterialDefinition
--- @field public texture? love.image.ImageData | love.graphics.Texture
--- @field public minFilter? "linear" | "nearest"
--- @field public magFilter? "linear" | "nearest"
--- @field public mipmaps? boolean
--- @field public mipmapFilter? "linear" | "nearest"
--- @field public verticalWrapMode? "clamp" | "repeat" | "mirroredrepeat" | "clampzero" | "clampone"
--- @field public horizontalWrapMode? "clamp" | "repeat" | "mirroredrepeat" | "clampzero" | "clampone"
--- @field public color number[]
local MaterialDefinition = {}
