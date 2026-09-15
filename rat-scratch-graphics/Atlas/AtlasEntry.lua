local Object = require("rat-scratch-common").Object

--- @class RatScratch.Graphics.Atlas.AtlasEntry : RatScratch.Common.BaseObject
--- @overload fun(handle: RatScratch.Graphics.Atlas.AtlasHandle, layer: integer, x: integer, y: integer, width: integer, height: integer): RatScratch.Graphics.Atlas.AtlasEntry
--- @field private handleWrapper { handle: RatScratch.Graphics.Atlas.AtlasHandle }
--- @field private layer integer
--- @field private x integer
--- @field private y integer
--- @field private width integer
--- @field private height integer
--- @field private eventIDs table<RatScratch.Common.EventScope, integer>
local AtlasEntry = Object()

function AtlasEntry:new(handle, layer, x, y, width, height)
	self.handleWrapper = setmetatable({ handle = handle }, { __mode = "v" })
	self.layer = layer
	self.x = x
	self.y = y
	self.width = width
	self.height = height
	self.eventIDs = {}
end

--- @param scope RatScratch.Common.EventScope
--- @param id? integer
function AtlasEntry:setEventID(scope, id)
	if self.eventIDs[scope] then
		self.handleWrapper.handle:silence(self.eventIDs[scope])
		self.eventIDs[scope] = nil
	end

	if id then
		self.eventIDs[scope] = id
	end
end

--- @param scope RatScratch.Common.EventScope
function AtlasEntry:clearEventID(scope)
	self:setEventID(scope, nil)
end

function AtlasEntry:getTextureHandle()
	return self.handleWrapper.handle
end

function AtlasEntry:getLayer()
	return self.layer
end

function AtlasEntry:getX()
	return self.x
end

function AtlasEntry:getY()
	return self.y
end

function AtlasEntry:getPosition()
	return self.x, self.y
end

function AtlasEntry:getWidth()
	return self.width
end

function AtlasEntry:getHeight()
	return self.height
end

return AtlasEntry
