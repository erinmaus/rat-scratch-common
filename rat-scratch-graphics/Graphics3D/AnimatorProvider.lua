local Object = require("rat-scratch-common").Object

--- @class RatScratch.Graphics.Graphics3D.AnimatorProvider : RatScratch.Common.BaseObject
local AnimatorProvider = Object()

--- @return string
function AnimatorProvider:getName()
	return self:ABSTRACT()
end

--- @return RatScratch.Graphics.Graphics3D.Skeleton
function AnimatorProvider:getSkeleton()
	return self:ABSTRACT()
end

--- @param animationKey number | string
--- @return RatScratch.Graphics.Graphics3D.Animation?
function AnimatorProvider:getAnimation(animationKey)
	return self:ABSTRACT()
end

--- @return integer
function AnimatorProvider:getAnimationCount()
	return self:ABSTRACT()
end

return AnimatorProvider
