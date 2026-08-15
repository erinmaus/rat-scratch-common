local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table

--- @class RatScratch.Graphics.Atlas.AtlasPackingNode : RatScratch.Common.BaseObject
--- @overload fun(x: integer, y: integer, width: integer, height: integer): RatScratch.Graphics.Atlas.AtlasPackingNode
--- @field private x number
--- @field private y number
--- @field private width number
--- @field private height number
--- @field private isOccupied boolean
--- @field private children RatScratch.Graphics.Atlas.AtlasPackingNode[]
local AtlasPackingNode = Object()

function AtlasPackingNode:new(x, y, width, height)
	self.x = x
	self.y = y
	self.width = width
	self.height = height
	self.isOccupied = false
	self.children = {}
end

function AtlasPackingNode:getX()
	return self.x
end

function AtlasPackingNode:getY()
	return self.y
end

function AtlasPackingNode:getPosition()
	return self.x, self.y
end

function AtlasPackingNode:getWidth()
	return self.width
end

function AtlasPackingNode:getHeight()
	return self.height
end

function AtlasPackingNode:getSize()
	return self.width, self.height
end

--- @param x integer
--- @param y integer
--- @param width integer
--- @param height integer
--- @return boolean
function AtlasPackingNode:remove(x, y, width, height)
	if
		self.x == x
		and self.y == y
		and self.width == width
		and self.height == height
	then
		self:clear()
		return true
	end

	for _, child in ipairs(self.children) do
		if child:remove(x, y, width, height) then
			return true
		end
	end

	return false
end

--- @param width number
--- @param height number
--- @return RatScratch.Graphics.Atlas.AtlasPackingNode | nil
function AtlasPackingNode:insert(width, height)
	if self.isOccupied or #self.children > 0 then
		for _, child in ipairs(self.children) do
			local node = child:insert(width, height)
			if node then
				return node
			end
		end

		return nil
	end

	if width > self.width or height > self.height then
		return nil
	end

	if width == self.width and height == self.height then
		self.isOccupied = true
		return self
	end

	local dw = self.width - width
	local dh = self.height - height

	if dw > dh then
		table.insert(
			self.children,
			AtlasPackingNode(self.x, self.y, width, self.height)
		)
		table.insert(
			self.children,
			AtlasPackingNode(self.x + width, self.y, dw, self.height)
		)
	else
		table.insert(
			self.children,
			AtlasPackingNode(self.x, self.y, self.width, height)
		)
		table.insert(
			self.children,
			AtlasPackingNode(self.x, self.y + height, self.width, dh)
		)
	end

	local node = self.children[1]
	return node:insert(width, height)
end

function AtlasPackingNode:clear()
	self.isOccupied = false
	Table.clear(self.children)
end

return AtlasPackingNode
