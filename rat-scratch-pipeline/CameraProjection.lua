local Object = require("rat-scratch-common").Object
local CameraEvent = require("rat-scratch-pipeline.CameraEvent")
local EventSource = require("rat-scratch-common.EventSource")

--- @class RatScratch.Pipeline.CameraProjection : RatScratch.Common.BaseObject
--- @field private eventSource RatScratch.Common.EventSource<RatScratch.Pipeline.CameraProjection>
--- @overload fun(): RatScratch.Pipeline.CameraProjection
local CameraProjection = Object()

function CameraProjection:new()
	self.eventSource = EventSource(self)
end

--- @protected
function CameraProjection:dirty()
	self.eventSource:process(CameraEvent.fromUpdate())
end

CameraProjection.listen, CameraProjection.silence =
	EventSource.mixin("eventSource")

--- @param transform? love.Transform
--- @return love.Transform
function CameraProjection:getProjection(transform)
	return self:ABSTRACT()
end

return CameraProjection
