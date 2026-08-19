--- @meta

--- @class RatScratch.Graphics.Graphics3D.Definition
--- @field name? string
--- @field id? integer
--- @field parentID? integer
--- @field extras? table
local Definition = {}

--- @class RatScratch.Graphics.Graphics3D.SceneDefinition : RatScratch.Graphics.Graphics3D.Definition
--- @field public models? RatScratch.Graphics.Graphics3D.ModelDefinition[]
local SceneDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.ModelDefinition : RatScratch.Graphics.Graphics3D.Definition
--- @field public meshes? RatScratch.Graphics.Graphics3D.MeshDefinition[]
--- @field public skeleton? RatScratch.Graphics.Graphics3D.SkeletonDefinition
--- @field public animations? RatScratch.Graphics.Graphics3D.AnimationDefinition[]
--- @field public transform? love.Transform
local ModelDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.MeshDefinition : RatScratch.Graphics.Graphics3D.Definition
--- @field public buffers RatScratch.Graphics.Graphics3D.MarshalBuffer[]
--- @field public format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @field public vertices number[][] | number
--- @field public indices number[] | number
--- @field public material RatScratch.Graphics.Graphics3D.MaterialDefinition?
local MeshDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.SkeletonDefinition : RatScratch.Graphics.Graphics3D.Definition
--- @field public bones RatScratch.Graphics.Graphics3D.BoneDefinition[]
local SkeletonDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.BoneDefinition : RatScratch.Graphics.Graphics3D.Definition
--- @field public index integer
--- @field public id number
--- @field public parentID number?
--- @field public inverseBindPoseTransform love.Transform
--- @field public transform love.Transform
--- @field public translation number[]
--- @field public rotation number[]
--- @field public scale number[]
local BoneDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.AnimationDefinition : RatScratch.Graphics.Graphics3D.Definition
--- @field public name? string
--- @field public channels RatScratch.Graphics.Graphics3D.AnimationChannelDefinition[]
local AnimationDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.AnimationChannelDefinition : RatScratch.Graphics.Graphics3D.Definition
--- @field public boneID integer
--- @field public properties RatScratch.Graphics.Graphics3D.KeyFramesDefinition[]
local AnimationChannelDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.KeyFramesDefinition : RatScratch.Graphics.Graphics3D.Definition
--- @field public property RatScratch.Graphics.Graphics3D.KeyFramePropertyType
--- @field public interpolation RatScratch.Graphics.Graphics3D.InterpolatorType
--- @field public frames RatScratch.Graphics.Graphics3D.KeyFrameDefinition[]
local KeyFramesDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.KeyFrameDefinition : RatScratch.Graphics.Graphics3D.Definition
--- @field public time number
--- @field public inTangent number[]
--- @field public value number[]
--- @field public outTangent number[]
local KeyFrameDefinition = {}

--- @class RatScratch.Graphics.Graphics3D.MaterialDefinition : RatScratch.Graphics.Graphics3D.Definition
--- @field public texture? love.ImageData | love.Texture
--- @field public normalTexture? love.ImageData | love.Texture
--- @field public minFilter? "linear" | "nearest"
--- @field public magFilter? "linear" | "nearest"
--- @field public mipmaps? boolean
--- @field public mipmapFilter? "linear" | "nearest"
--- @field public verticalWrapMode? "clamp" | "repeat" | "mirroredrepeat" | "clampzero" | "clampone"
--- @field public horizontalWrapMode? "clamp" | "repeat" | "mirroredrepeat" | "clampzero" | "clampone"
--- @field public color number[]
local MaterialDefinition = {}
