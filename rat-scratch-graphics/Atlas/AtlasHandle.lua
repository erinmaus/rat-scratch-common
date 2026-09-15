local Object = require("rat-scratch-common").Object
local EventSource = require("rat-scratch-common").EventSource
local AtlasEvent = require("rat-scratch-graphics.Atlas.AtlasEvent")

--- @class RatScratch.Graphics.Atlas.AtlasHandle : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Graphics.Atlas.AtlasHandle
--- @field private eventSource RatScratch.Common.EventSource<RatScratch.Graphics.Atlas.AtlasHandle>
--- @field private proxy userdata
local AtlasHandle = Object()

function AtlasHandle:new()
	self.eventSource = EventSource(self)
	self.proxy = newproxy(true)

	local metatable = getmetatable(self.proxy)
	metatable.__gc = AtlasHandle._collect
	metatable.handle = self
end

function AtlasHandle._collect(userdata)
	local metatable = getmetatable(userdata)

	local self = metatable.handle
	self:fireFree()
end

--- @protected
function AtlasHandle:fireFree()
	self.eventSource:process(AtlasEvent.fromFree())
end

--- @protected
function AtlasHandle:fireModify()
	self.eventSource:process(AtlasEvent.fromModify())
end

AtlasHandle.listen, AtlasHandle.silence = EventSource.mixin("eventSource")

--- @return integer
function AtlasHandle:getWidth()
	return self:ABSTRACT()
end

--- @return integer
function AtlasHandle:getHeight()
	return self:ABSTRACT()
end

--- @param texture love.Texture
--- @param layer integer
--- @param x integer
--- @param y integer
--- @param width integer
--- @param height integer
--- @return boolean
function AtlasHandle:apply(texture, layer, x, y, width, height)
	return self:ABSTRACT()
end

return AtlasHandle
