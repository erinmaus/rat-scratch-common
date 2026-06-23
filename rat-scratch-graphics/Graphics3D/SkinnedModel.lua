local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Model = require("rat-scratch-graphics.Graphics3D.Model")

--- @class RatScratch.Graphics.Graphics3D.SkinnedModel : RatScratch.Graphics.Graphics3D.Model
--- @overload fun(name: string, meshes: RatScratch.Graphics.Graphics3D.Mesh[], skeleton: RatScratch.Graphics.Graphics3D.Skeleton, animations: RatScratch.Graphics.Graphics3D.Animation[]): RatScratch.Graphics.Graphics3D.SkinnedModel
--- @field private skeleton RatScratch.Graphics.Graphics3D.Skeleton
--- @field private animations RatScratch.Graphics.Graphics3D.Animation[]
--- @field private animationsByName table<string, RatScratch.Graphics.Graphics3D.Animation[]>
local SkinnedModel = Object(Model)

--- @param inputAnimations? RatScratch.Graphics.Graphics3D.Mesh[]
--- @return RatScratch.Graphics.Graphics3D.Mesh[], table<string, RatScratch.Graphics.Graphics3D.Mesh>
function SkinnedModel.validateAnimations(inputAnimations)
    local animations = {}
    local animationsByName = {}

    if not inputAnimations then
        return animations, animationsByName
    end

    for _, animation in ipairs(inputAnimations) do
        local name = animation:getName()
        if name ~= "" then
            assert(not animationsByName[name], "animation with duplicate name: %s", name)
            animationsByName[name] = animation
        end

        table.insert(animations, animation)
    end

    return animations, animationsByName
end

--- @param name string
--- @param meshes RatScratch.Graphics.Graphics3D.Mesh[]
--- @param skeleton RatScratch.Graphics.Graphics3D.Skeleton
--- @param animations RatScratch.Graphics.Graphics3D.Animation[]
function SkinnedModel:new(name, meshes, skeleton, animations)
	Model.new(self, name, meshes)

    local outputAnimations, outputAnimationsByName = SkinnedModel.validateAnimations(animations)

    self.animations = outputAnimations
    self.animationsByName = outputAnimationsByName
    self.skeleton = skeleton
end

--- @param key number | string
--- @return RatScratch.Graphics.Graphics3D.Animation
function SkinnedModel:getAnimation(key)
    if type(key) == "number" then
        assert(self.animations[key] ~= nil, "no animation at index %d", key)
        return self.animations[key]
    elseif type(key) == "string" then
        assert(self.animationsByName[key] ~= nil, "no animation with given name: %s", key)
        return self.animationsByName[key]
    end

    error("expected \"number\" or \"string\" for parameter \"key\"")
end

function SkinnedModel:getAnimationCount()
    return #self.animations
end

function SkinnedModel:getSkeleton()
    return self.skeleton
end

return SkinnedModel
