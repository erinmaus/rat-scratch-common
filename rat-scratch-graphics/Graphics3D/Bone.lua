local Object = require("rat-scratch-common").Object
local Vector3 = require "rat-scratch-math".Vector3
local Quaternion = require "rat-scratch-math".Quaternion
local Transform     = require "rat-scratch-math".Transform

--- @class RatScratch.Graphics.Graphics3D.Bone : RatScratch.Common.BaseObject
--- @overload fun(parent?: RatScratch.Graphics.Graphics3D.Bone, id: number, name?: string, index: integer, inverseBindPoseTransform?: love.Transform, transform: RatScratch.Graphics.Graphics3D.BoneTransform): RatScratch.Graphics.Graphics3D.Bone
--- @field private parent RatScratch.Graphics.Graphics3D.Bone | nil
--- @field private id number
--- @field private name string
--- @field private inverseBindPoseTransform love.Transform
--- @field private transform love.Transform
--- @field private translation RatScratch.Math.Vector3
--- @field private rotation RatScratch.Math.Quaternion
--- @field private scale RatScratch.Math.Vector3
local Bone = Object()

--- @class RatScratch.Graphics.Graphics3D.BoneTransform
--- @field public transform love.Transform
--- @field public translation RatScratch.Math.Vector3 | nil
--- @field public rotation RatScratch.Math.Quaternion | nil
--- @field public scale RatScratch.Math.Vector3 | nil
local BoneTransform = {}

--- @param parent? RatScratch.Graphics.Graphics3D.Bone
--- @param id number
--- @param name? string
--- @param index integer
--- @param inverseBindPoseTransform? love.Transform
--- @param transform RatScratch.Graphics.Graphics3D.BoneTransform
function Bone:new(parent, id, name, index, inverseBindPoseTransform, transform)
	self.parent = parent
	self.id = id
	self.name = name or ""
    self.index = index
	self.inverseBindPoseTransform = inverseBindPoseTransform or love.math.newTransform()
	self.transform = transform.transform or love.math.newTransform()
	self.translation = Vector3((transform and transform.translation or Vector3.ZERO):get())
	self.rotation = Quaternion((transform and transform.rotation or Quaternion.IDENTITY):get())
	self.scale = Vector3((transform and transform.scale or Vector3.ONE):get())
end

function Bone:getParent()
    return self.parent
end

function Bone:getID()
    return self.id
end

function Bone:getName()
    return self.name
end

function Bone:getIndex()
    return self.index
end

function Bone:getInverseBindPoseTransform()
    return self.inverseBindPoseTransform
end

function Bone:getTransform()
    return self.transform
end

function Bone:getTranslation()
    return self.translation
end

function Bone:getRotation()
    return self.rotation
end

function Bone:getScale()
    return self.scale
end

do
    local workingTransform = love.math.newTransform()

    --- @param transform love.Transform
    function Bone:composeTransform(transform)
        Transform.compose(self.translation, self.rotation, self.scale, workingTransform)

        transform:reset()
        transform:apply(self.transform)
        transform:apply(workingTransform)
    end
end

return Bone
