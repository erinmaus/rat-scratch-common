local Object = require("rat-scratch-common").Object
local AnimatorProvider =
	require("rat-scratch-graphics.Graphics3D.AnimatorProvider")

--- @class RatScratch.Pipeline.Graphics3D.ObjectHandleAnimatorProvider : RatScratch.Graphics.Graphics3D.AnimatorProvider
--- @overload fun(object: RatScratch.Pipeline.ObjectHandle): RatScratch.Pipeline.Graphics3D.ObjectHandleAnimatorProvider
--- @field private object RatScratch.Pipeline.ObjectHandle
local SkinnedModelAnimatorProvider = Object(AnimatorProvider)

--- @param object RatScratch.Pipeline.ObjectHandle
function SkinnedModelAnimatorProvider:new(object)
	self.object = object
end

--- @return string
function SkinnedModelAnimatorProvider:getName()
	return self.object:getName()
end

--- @return RatScratch.Graphics.Graphics3D.Skeleton
function SkinnedModelAnimatorProvider:getSkeleton()
	local skeletonResource = self.object:getSkeleton()
	local skeleton = skeletonResource and skeletonResource:get()

	--- @cast skeleton RatScratch.Graphics.Graphics3D.Skeleton
	return skeleton
end

--- @param animationKey number | string
--- @return RatScratch.Graphics.Graphics3D.Animation?
function SkinnedModelAnimatorProvider:getAnimation(animationKey)
	--- @cast animationKey integer
	local animation = self.object:getAnimation(animationKey)
	if animation then
		return animation
	end

	--- @cast animationKey string
	for i = 1, self.object:getAnimationCount() do
		local a = self.object:getAnimation(i)
		if a:getName() == animationKey then
			return a
		end
	end

	return nil
end

--- @return integer
function SkinnedModelAnimatorProvider:getAnimationCount()
	return self.object:getAnimationCount()
end

return SkinnedModelAnimatorProvider
