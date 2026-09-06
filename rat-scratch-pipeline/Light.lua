local Object = require("rat-scratch-common").Object
local LinearColor = require("rat-scratch-graphics").LinearColor
local Color = require("rat-scratch-graphics").Color
local EventSource = require("rat-scratch-common").EventSource
local LightEvent = require("rat-scratch-pipeline.LightEvent")

--- @class RatScratch.Pipeline.Light : RatScratch.Common.BaseObject
--- @field private color RatScratch.Graphics.LinearColor
--- @overload fun(): RatScratch.Pipeline.Light
local Light = Object()

function Light:new()
	self.color = LinearColor()
	self.isShadowCaster = false
	self.eventSource = EventSource(self)
	self.isDirty = false
end

Light.listen, Light.silence = EventSource.mixin("eventSource")

--- @protected
function Light:dirty()
	if not self.isDirty then
		self.isDirty = true
		self.eventSource:process(LightEvent.fromUpdate())
	end
end

function Light:update(deltaTime)
	self.isDirty = false
end

--- @return RatScratch.Graphics.LinearColor
function Light:getColor()
	return self.color
end

--- @param color RatScratch.Graphics.Color
function Light:setColor(color)
	Color.convert(color, self.color)
	self:dirty()
end

--- @return boolean
function Light:getIsShadowCaster()
	return self.isShadowCaster
end

--- @param value boolean
function Light:setIsShadowCaster(value)
	self.isShadowCaster = not not value
	self:dirty()
end

return Light
