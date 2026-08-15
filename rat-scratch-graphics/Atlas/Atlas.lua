local AtlasEntry = require("rat-scratch-graphics.Atlas.AtlasEntry")
local AtlasPackingNode = require("rat-scratch-graphics.Atlas.AtlasPackingNode")
local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local AtlasEvent = require("rat-scratch-graphics.Atlas.AtlasEvent")

--- @class RatScratch.Graphics.Atlas : RatScratch.Common.BaseObject
--- @overload fun(width: integer, height: integer, maxLayers?: integer): RatScratch.Graphics.Atlas
--- @field private width integer
--- @field private height integer
--- @field private layers integer
--- @field private canvas? love.Texture
--- @field private entries table<RatScratch.Graphics.Atlas.AtlasHandle, RatScratch.Graphics.Atlas.AtlasEntry>
--- @field private roots RatScratch.Graphics.Atlas.AtlasPackingNode[]
local Atlas = Object()

--- @param width number
--- @param height number
--- @param maxLayers? integer
function Atlas:new(width, height, maxLayers)
	self.width = width
	self.height = height
	self.layers = 0
	self.maxLayers = maxLayers or math.huge

	self.entries = setmetatable({}, { __mode = "k" })
	self.roots = {}
end

function Atlas:hasTexture()
	return self.canvas ~= nil
end

function Atlas:getTexture()
	return self.canvas
end

--- @private
function Atlas:_allocateLayer()
	assert(
		self.layers < self.maxLayers,
		"adding a layer (%d) would exceed max number of layers (%d)",
		self.layers + 1,
		self.maxLayers
	)

	self.layers = self.layers + 1

	local newCanvas = love.graphics.newTexture(
		self.width,
		self.height,
		self.layers,
		{ format = "rgba8", canvas = true, mipmaps = true, readable = true }
	)

	local oldCanvas = self.canvas
	if oldCanvas then
		love.graphics.push("all")
		do
			love.graphics.origin()
			love.graphics.resetProjection()
			love.graphics.setScissor()

			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.setBlendState("add", "one", "zero")

			for i = 1, oldCanvas:getLayerCount() do
				love.graphics.setCanvas(newCanvas, i)

				love.graphics.clear(0, 0, 0, 0)
				love.graphics.drawLayer(oldCanvas, i)
			end
		end
		love.graphics.pop()

		oldCanvas:release()
	end

	self.canvas = newCanvas

	table.insert(self.roots, AtlasPackingNode(0, 0, self.width, self.height))
end

--- @private
--- @param width integer
--- @param height integer
--- @return integer?, RatScratch.Graphics.Atlas.AtlasPackingNode?
function Atlas:_findTargetLayerNode(width, height)
	for index, root in ipairs(self.roots) do
		local node = root:insert(width, height)
		if node then
			return index, node
		end
	end

	return nil, nil
end

--- @private
--- @param width integer
--- @param height integer
--- @return integer, RatScratch.Graphics.Atlas.AtlasPackingNode
function Atlas:_newLayer(width, height)
	self:_allocateLayer()

	local root = self.roots[#self.roots]
	local node = root:insert(width, height)
	assert(
		node,
		"critical logic error: allocated new layer, but texture did not fit"
	)

	--- @cast node RatScratch.Graphics.Atlas.AtlasPackingNode
	return #self.roots, node
end

--- @private
--- @param texture RatScratch.Graphics.Atlas.AtlasHandle
--- @param entry RatScratch.Graphics.Atlas.AtlasEntry
function Atlas:_drawEntry(texture, entry)
	-- TODO: make this async

	local isDone = false
	repeat
		isDone = texture:apply(
			self.canvas,
			entry:getLayer(),
			entry:getX(),
			entry:getY(),
			entry:getWidth(),
			entry:getHeight()
		)
	until isDone
end

--- @param handle RatScratch.Graphics.Atlas.AtlasHandle
--- @return boolean
function Atlas:add(handle)
	if self.entries[handle] then
		return true
	end

	local width = handle:getWidth()
	local height = handle:getHeight()
	assert(
		width <= self.width and height <= self.height,
		"texture dimensions (%d, %d) are too big to fit in atlas (%d, %d)",
		width,
		height,
		self.width,
		self.height
	)

	local targetLayer, targetNode = self:_findTargetLayerNode(width, height)
	if not (targetLayer and targetNode) then
		if self.layers >= self.maxLayers then
			return false
		end

		targetLayer, targetNode = self:_newLayer(width, height)
	end

	local entry = AtlasEntry(
		handle,
		targetLayer,
		targetNode:getX(),
		targetNode:getY(),
		width,
		height
	)
	self.entries[handle] = entry
	self:_drawEntry(handle, entry)

	entry:setEventID(
		AtlasEvent.FREE,
		handle:listen(AtlasEvent.FREE, Atlas._onFreeTexture, self)
	)
	entry:setEventID(
		AtlasEvent.MODIFY,
		handle:listen(AtlasEvent.MODIFY, Atlas._onModifyTexture, self)
	)

	return true
end

--- @private
--- @param event RatScratch.Graphics.Atlas.AtlasEvent
--- @param handle RatScratch.Graphics.Atlas.AtlasHandle
function Atlas:_onFreeTexture(event, handle)
	self:remove(handle)
end

--- @private
--- @param event RatScratch.Graphics.Atlas.AtlasEvent
--- @param handle RatScratch.Graphics.Atlas.AtlasHandle
function Atlas:_onModifyTexture(event, handle)
	local entry = self.entries[handle]
	if
		handle:getWidth() <= entry:getWidth()
		and handle:getHeight() <= entry:getHeight()
	then
		self:_drawEntry(handle, entry)
	else
		self:remove(handle)
		self:add(handle)
	end
end

--- @private
--- @param handle RatScratch.Graphics.Atlas.AtlasHandle
function Atlas:_clearEvents(handle)
	local entry = self.entries[handle]
	if not entry then
		return
	end

	entry:clearEventID(AtlasEvent.FREE)
	entry:clearEventID(AtlasEvent.MODIFY)
end

--- @param handle RatScratch.Graphics.Atlas.AtlasHandle
function Atlas:remove(handle)
	local entry = self.entries[handle]
	if not entry then
		return
	end

	entry:clearEventID(AtlasEvent.FREE)
	entry:clearEventID(AtlasEvent.MODIFY)

	local root = self.roots[entry:getLayer()]
	root:remove(entry:getX(), entry:getY(), entry:getWidth(), entry:getHeight())

	self.entries[handle] = nil
end

--- @param handle RatScratch.Graphics.Atlas.AtlasHandle
function Atlas:has(handle)
	return self.entries[handle] ~= nil
end

--- @param handle RatScratch.Graphics.Atlas.AtlasHandle
--- @return number?, number?, number?, number?, number?
function Atlas:getTextureCoordinates(handle)
	local entry = self.entries[handle]
	if not entry then
		return nil, nil, nil, nil, nil
	end

	local left = entry:getX() / self.width
	local right = (entry:getX() + entry:getWidth()) / self.width
	local top = entry:getY() / self.height
	local bottom = (entry:getY() + entry:getHeight()) / self.height

	return left, right, top, bottom, entry:getLayer()
end

do
	--- @alias RatScratch.Graphics.Atlas.TextureEntryCache {
	---   texture: RatScratch.Graphics.Atlas.AtlasHandle,
	---   entry: RatScratch.Graphics.Atlas.AtlasEntry,
	--- }

	--- @type RatScratch.Graphics.Atlas.TextureEntryCache[]
	local textureEntries = {}

	--- @type RatScratch.Graphics.Atlas.TextureEntryCache[]
	local textureEntryPool = {}

	--- @param a RatScratch.Graphics.Atlas.TextureEntryCache
	--- @param b RatScratch.Graphics.Atlas.TextureEntryCache
	--- @return boolean
	local function _sort(a, b)
		return (a.entry:getWidth() * a.entry:getHeight())
			> (b.entry:getWidth() * b.entry:getHeight())
	end

	function Atlas:repack()
		Table.clear(textureEntries)

		for texture, entry in pairs(self.entries) do
			local t = table.remove(textureEntryPool)
			if not t then
				t = {}
			end

			t.texture = texture
			t.entry = entry

			table.insert(textureEntries, t)
			self:_clearEvents(texture)
		end

		Table.clear(self.entries)
		Table.clear(self.roots)

		self.layers = 0
		self.canvas:release()

		table.sort(textureEntries, _sort)

		for _, item in ipairs(textureEntries) do
			self:add(item.texture)
		end

		for _, t in ipairs(textureEntries) do
			Table.clear(t)
			table.insert(textureEntryPool, t)
		end
	end
end

return Atlas
