local Object = require("rat-scratch-common").Object
local CameraEvent = require("rat-scratch-pipeline.CameraEvent")
local EventSource = require("rat-scratch-common.EventSource")

--- @class RatScratch.Pipeline.CameraView : RatScratch.Common.BaseObject
--- @field private eventSource RatScratch.Common.EventSource<RatScratch.Pipeline.CameraView>
--- @overload fun(): RatScratch.Pipeline.CameraView
local CameraView = Object()

function CameraView:new()
	self.eventSource = EventSource(self)
end

--- @protected
function CameraView:dirty()
	self.eventSource:process(CameraEvent.fromUpdate())
end

CameraView.listen, CameraView.silence = EventSource.mixin("eventSource")

--- @param transform? love.Transform
--- @return love.Transform
function CameraView:getView(transform)
	return self:ABSTRACT()
end

return CameraView
