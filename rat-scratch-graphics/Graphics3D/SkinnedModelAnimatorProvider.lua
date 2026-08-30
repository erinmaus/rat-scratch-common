local Object = require("rat-scratch-common").Object
local AnimatorProvider =
	require("rat-scratch-graphics.Graphics3D.AnimatorProvider")

--- @class RatScratch.Graphics.Graphics3D.SkinnedModelAnimatorProvider : RatScratch.Graphics.Graphics3D.AnimatorProvider
--- @overload fun(model: RatScratch.Graphics.Graphics3D.SkinnedModel): RatScratch.Graphics.Graphics3D.SkinnedModelAnimatorProvider
--- @field private model RatScratch.Graphics.Graphics3D.SkinnedModel
local SkinnedModelAnimatorProvider = Object(AnimatorProvider)

--- @param model RatScratch.Graphics.Graphics3D.SkinnedModel
function SkinnedModelAnimatorProvider:new(model)
	self.model = model
end

--- @return string
function SkinnedModelAnimatorProvider:getName()
	return self.model:getName()
end

--- @return RatScratch.Graphics.Graphics3D.Skeleton
function SkinnedModelAnimatorProvider:getSkeleton()
	return self.model:getSkeleton()
end

--- @param animationKey number | string
--- @return RatScratch.Graphics.Graphics3D.Animation
function SkinnedModelAnimatorProvider:getAnimation(animationKey)
	return self.model:getAnimation(animationKey)
end

--- @return integer
function SkinnedModelAnimatorProvider:getAnimationCount()
	return self.model:getAnimationCount()
end

return SkinnedModelAnimatorProvider
