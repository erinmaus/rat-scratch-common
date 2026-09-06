local Object = require("rat-scratch-common").Object

--- @class RatScratch.Pipeline.Camera : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Pipeline.Camera
local Camera = Object()

--- @param transform? love.Transform
--- @return love.Transform
function Camera:getProjection(transform)
	return self:ABSTRACT()
end

--- @param transform? love.Transform
--- @return love.Transform
function Camera:getView(transform)
	return self:ABSTRACT()
end

return Camera
