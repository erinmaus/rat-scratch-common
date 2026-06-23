local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object

--- @class RatScratch.Graphics.Graphics3D.AnimationChannel : RatScratch.Common.BaseObject
--- @overload fun(bone: RatScratch.Graphics.Graphics3D.Bone, keyedProperties: RatScratch.Graphics.Graphics3D.KeyFrames[]): RatScratch.Graphics.Graphics3D.AnimationChannel
--- @field private duration number
--- @field private bone RatScratch.Graphics.Graphics3D.Bone
--- @field private keyedProperties RatScratch.Graphics.Graphics3D.KeyFrames[]
--- @field private keyedPropertiesByName table<string, RatScratch.Graphics.Graphics3D.KeyFrames>
local AnimationChannel = Object()

--- @param inputKeyedProperties RatScratch.Graphics.Graphics3D.KeyFrames[]
--- @return RatScratch.Graphics.Graphics3D.KeyFrames[], table<string, RatScratch.Graphics.Graphics3D.KeyFrames>, number
function AnimationChannel.validateKeyedProperties(inputKeyedProperties)
    local keyedProperties = {}
    local keyedPropertiesByName = {}
    local duration = 0

    for _, keyedProperty in ipairs(inputKeyedProperties) do
        local name = keyedProperty:getProperty()
        assert(keyedPropertiesByName[name] == nil, "multiple keyed properties of the same name: %s", name)

        keyedPropertiesByName[name] = keyedProperty
        table.insert(keyedProperties, keyedProperty)

        duration = math.max(duration, keyedProperty:getDuration())
    end

    return keyedProperties, keyedPropertiesByName, duration
end

--- @param bone RatScratch.Graphics.Graphics3D.Bone
--- @param keyedProperties RatScratch.Graphics.Graphics3D.KeyFrames[]
function AnimationChannel:new(bone, keyedProperties)
    local outputKeyedProperties, outputKeyedPropertiesByName, duration = AnimationChannel.validateKeyedProperties(keyedProperties)

	self.bone = bone
	self.duration = duration
	self.keyedProperties = outputKeyedProperties
	self.keyedPropertiesByName = outputKeyedPropertiesByName
end

function AnimationChannel:getBone()
    return self.bone
end

function AnimationChannel:getDuration()
    return self.duration
end

function AnimationChannel:getKeyedPropertyCount()
    return #self.keyedProperties
end

--- @param key number | string
function AnimationChannel:getKeyedProperty(key)
    if type(key) == "number" then
        assert(self.keyedProperties[key] ~= nil, "no keyed properties at index: %d", key)
        return self.keyedProperties[key]
    elseif type(key) == "string" then
        assert(self.keyedPropertiesByName[key] ~= nil, "no keyed properties with property name: %s", key)
        return self.keyedPropertiesByName[key]
    end

    error("expected \"number\" or \"string\" for parameter \"key\"")
end

--- @type table<RatScratch.Graphics.Graphics3D.KeyFramePropertyType, fun(bone: RatScratch.Graphics.Graphics3D.BoneInstance): RatScratch.Graphics.Graphics3D.KeyFrameValue>
local PROPERTY_GETTER = {
    position = function(bone)
        return bone:getTranslation()
    end,

    rotation = function(bone)
        return bone:getRotation()
    end,

    scale = function(bone)
        return bone:getScale()
    end,
}

--- @param time number
--- @param boneInstance RatScratch.Graphics.Graphics3D.BoneInstance
function AnimationChannel:computePropertiesAtTime(boneInstance, time)
    for _, property in ipairs(self.keyedProperties) do
        local getterFunc = PROPERTY_GETTER[property:getProperty()]
        property:computeValueAtTime(time, getterFunc(boneInstance))
    end
end

return AnimationChannel
