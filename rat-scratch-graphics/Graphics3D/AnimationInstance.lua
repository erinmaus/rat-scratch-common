local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-math").Vector3
local Quaternion = require("rat-scratch-math").Quaternion
local BoneInstance = require "rat-scratch-graphics.Graphics3D.BoneInstance"

--- @class RatScratch.Graphics.Graphics3D.AnimationInstance : RatScratch.Common.BaseObject
--- @overload fun(skeleton: RatScratch.Graphics.Graphics3D.Skeleton): RatScratch.Graphics.Graphics3D.AnimationInstance
--- @field private skeleton RatScratch.Graphics.Graphics3D.Skeleton
--- @field private boneInstances RatScratch.Graphics.Graphics3D.BoneInstance[]
local AnimationInstance = Object()

--- @param skeleton? RatScratch.Graphics.Graphics3D.Skeleton
--- @return RatScratch.Graphics.Graphics3D.BoneInstance[]
function AnimationInstance.generateBoneInstances(skeleton)
    local boneInstances = {}

    if not skeleton then
        return boneInstances
    end

    for i = 1, skeleton:getBoneCount() do
        local bone = skeleton:getBone(i)
        local boneInstance = BoneInstance(bone)

        boneInstance:setTranslation(bone:getTranslation())
        boneInstance:setRotation(bone:getRotation())
        boneInstance:setScale(bone:getScale())

        table.insert(boneInstances, boneInstance)
    end

    return boneInstances
end

--- @param skeleton RatScratch.Graphics.Graphics3D.Skeleton
function AnimationInstance:new(skeleton)
	self.skeleton = skeleton
	self.boneInstances = AnimationInstance.generateBoneInstances(skeleton)
end

--- @param key string | number | RatScratch.Graphics.Graphics3D.Bone name, index, or bone
--- @return RatScratch.Graphics.Graphics3D.BoneInstance
function AnimationInstance:getBoneInstance(key)
    local bone
    if type(key) == "string" or type(key) == "number" then
        bone = self.skeleton:getBone(key)
    else
        bone = key
    end

    local index = self.skeleton:getBoneIndex(bone)
    return self.boneInstances[index]
end

function AnimationInstance:reset()
    for _, boneInstance in ipairs(self.boneInstances) do
        local bone = boneInstance:getBone()
        boneInstance:setTranslation(bone:getTranslation())
        boneInstance:setRotation(bone:getRotation())
        boneInstance:setScale(bone:getScale())
    end
end

function AnimationInstance:identity()
    for _, boneInstance in ipairs(self.boneInstances) do
        boneInstance:setTranslation(Vector3.ZERO)
        boneInstance:setRotation(Quaternion.IDENTITY)
        boneInstance:setScale(Vector3.ONE)
    end
end

function AnimationInstance:zero()
    for _, boneInstance in ipairs(self.boneInstances) do
        boneInstance:setTranslation(Vector3.ZERO)
        boneInstance:setRotation(Quaternion.ZERO)
        boneInstance:setScale(Vector3.ZERO)
    end
end

do
    local weightedRotation = Quaternion()
    local weightedVector = Vector3()

    --- @param weight number
    --- @param otherAnimationInstance RatScratch.Graphics.Graphics3D.AnimationInstance
    --- @param animation? RatScratch.Graphics.Graphics3D.Animation
    function AnimationInstance:blend(weight, otherAnimationInstance, animation)
        assert(#self.boneInstances == #otherAnimationInstance.boneInstances)
        assert(weight >= 0, "weight must be greater than or equal to zero; got %f", weight)

        for i, boneInstance in ipairs(self.boneInstances) do
            local translation, rotation, scale
            if not (animation and animation:hasBone(boneInstance:getBone())) then
                translation = boneInstance:getBone():getTranslation()
                rotation = boneInstance:getBone():getRotation()
                scale = boneInstance:getBone():getScale()
            else
                translation = boneInstance:getTranslation()
                rotation = boneInstance:getRotation()
                scale = boneInstance:getScale()
            end

            translation:scale(weight, weightedVector):add(otherAnimationInstance.boneInstances[i]:getTranslation(), otherAnimationInstance.boneInstances[i]:getTranslation())
            rotation:scale(weight, weightedRotation):add(otherAnimationInstance.boneInstances[i]:getRotation(), otherAnimationInstance.boneInstances[i]:getRotation())
            scale:scale(weight, weightedVector):add(otherAnimationInstance.boneInstances[i]:getScale(), otherAnimationInstance.boneInstances[i]:getScale())
        end
    end
end

return AnimationInstance
