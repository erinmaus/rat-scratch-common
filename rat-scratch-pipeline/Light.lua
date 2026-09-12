local Object = require("rat-scratch-common").Object
local LinearColor = require("rat-scratch-graphics").LinearColor
local Color = require("rat-scratch-graphics").Color
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local EventSource = require("rat-scratch-common").EventSource
local LightEvent = require("rat-scratch-pipeline.LightEvent")

--- @class RatScratch.Pipeline.Light : RatScratch.Common.BaseObject
--- @field private color RatScratch.Graphics.LinearColor
--- @field private ultraviolet number
--- @field private eventSource RatScratch.Common.EventSource<RatScratch.Pipeline.Light>
--- @field private isShadowCaster boolean
--- @field private isDirty boolean
--- @overload fun(): RatScratch.Pipeline.Light
local Light = Object()

Light.LIGHT_FORMAT = {
	{ location = 0, name = "color", format = "floatvec4" },
	{ location = 1, name = "direction", format = "floatvec2" },
	{ location = 2, name = "position", format = "floatvec4" },
	{ location = 3, name = "attenuation", format = "floatvec2" },
	{ location = 4, name = "shadowTextureIndexCount", format = "uint32vec2" },
}

Light.LIGHT_FORMAT_INSTANCE = BufferFormat.get(Light.LIGHT_FORMAT)

function Light:new()
	self.color = LinearColor()
	self.ultraviolet = 0
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

--- @param data number[]
--- @param offset? integer
function Light:toData(data, offset)
	local r, g, b = self.color:get()

	BufferFormat.resetValue(Light.LIGHT_FORMAT_INSTANCE, data, offset)
	BufferFormat.setValue(
		Light.LIGHT_FORMAT_INSTANCE,
		data,
		"color",
		offset,
		r,
		g,
		b,
		self.ultraviolet
	)
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

function Light:setUltraviolet(value)
	self.ultraviolet = value
end

function Light:getUltraviolet()
	return self.ultraviolet
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

--- @return integer
function Light:getCameraCount()
	return 1
end

--- @param index integer
--- @return RatScratch.Pipeline.Camera
function Light:getCamera(index)
	return self:ABSTRACT()
end

return Light
