local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local assert = require("rat-scratch-common").Debug.assert
local Polygon = require("rat-scratch-math.Geometry2D.Polygon")

--- @class RatScratch.Math.BSP2D.BSPNode : RatScratch.Common.BaseObject
--- @overload fun(polygon?: number[], parent?: RatScratch.Math.BSP2D.BSPNode): RatScratch.Math.BSP2D.BSPNode
--- @field private parent? RatScratch.Math.BSP2D.BSPNode
--- @field private children RatScratch.Math.BSP2D.BSPNode[]
--- @field private polygon number[]
--- @field private x number
--- @field private y number
--- @field private normalX number
--- @field private normalY number
local BSPNode = Object()

--- @private
BSPNode.CHILD_LEFT = 1

--- @private
BSPNode.CHILD_RIGHT = 2

--- @param polygon? number[]
--- @param parent? RatScratch.Math.BSP2D.BSPNode
function BSPNode:new(polygon, parent)
	self.parent = parent
	self.polygon = polygon and Table.clone(polygon) or {}
	self.children = {}
end

function BSPNode:getIsValid()
	return #self.polygon >= 6
end

function BSPNode:getParent()
	return self.parent
end

function BSPNode:getPolygon()
	return self.polygon
end

function BSPNode:getIsRoot()
	return not self.parent
end

function BSPNode:getIsLeaf()
	return #self.children == 0
end

function BSPNode:getLeft()
	return self.children[BSPNode.CHILD_LEFT]
end

function BSPNode:getRight()
	return self.children[BSPNode.CHILD_RIGHT]
end

--- @return fun(table: RatScratch.Math.BSP2D.BSPNode[], i?: integer): integer
--- @return RatScratch.Math.BSP2D.BSPNode[]
--- @return integer
function BSPNode:iterate()
	return ipairs(self.children)
end

--- @param x number
--- @param y number
--- @return RatScratch.Math.BSP2D.BSPNode?
function BSPNode:find(x, y)
	if self:getIsLeaf() then
		if Polygon.isPointInside(x, y, self.polygon) then
			return self
		else
			return nil
		end
	end

	for _, child in ipairs(self.children) do
		local result = child:find(x, y)
		if result then
			return result
		end
	end

	return nil
end

function BSPNode:clear()
	Table.clear(self.children)
end

--- @param x number
--- @param y number
--- @param normalX number
--- @param normalY number
--- @return boolean
function BSPNode:split(x, y, normalX, normalY)
	assert(self:getIsLeaf(), "BSP node is not leaf; cannot split")

	local success, left, right =
		Polygon.split(x, y, x + normalX, y + normalY, self.polygon)

	if not success then
		return false
	end

	self.x, self.y = x, y
	self.normalX, self.normalY = normalX, normalY

	self.children[BSPNode.CHILD_LEFT] = BSPNode(left, self)
	self.children[BSPNode.CHILD_RIGHT] = BSPNode(right, self)

	return true
end

--- @class RatScratch.Math.BSP2D.BSPNode.SerializedBSPNode
--- @field public polygon number[]
--- @field public normalX? number
--- @field public normalY? number
--- @field public x? number
--- @field public y? number
--- @field public left? RatScratch.Math.BSP2D.BSPNode.SerializedBSPNode
--- @field public right? RatScratch.Math.BSP2D.BSPNode.SerializedBSPNode
local SerializedBSPNode = {}

--- comment
--- @param node? RatScratch.Math.BSP2D.BSPNode.SerializedBSPNode
function BSPNode:serialize(node)
	node = node or { polygon = {} }
	Table.clear(node.polygon)

	for _, component in ipairs(self.polygon) do
		table.insert(node.polygon, component)
	end

	node.x, node.y = self.x, self.y
	node.normalX, node.normalY = self.normalX, self.normalY

	if not self:getIsLeaf() then
		node.left = self.children[BSPNode.CHILD_LEFT]:serialize(node.left)
		node.right = self.children[BSPNode.CHILD_RIGHT]:serialize(node.right)
	else
		node.left = nil
		node.right = nil
	end

	return node
end

--- @param node RatScratch.Math.BSP2D.BSPNode.SerializedBSPNode
function BSPNode:deserialize(node)
	assert(
		#node.polygon >= 6,
		"serialized node polygon must have at least 3 vertices; got %d",
		#node.polygon
	)

	assert(
		not (node.left or node.right) or (node.left and node.right),
		"must have no children or both children: left = %s, right = %s",
		node.left and "valid" or "missing",
		node.right and "valid" or "missing"
	)

	assert(
		not (node.left or node.right)
			or (node.normalX and node.normalY and node.x and node.y),
		"have children but missing complete normal (%s) and/or complete position (%s)",
		node.normalX and node.normalY and "valid" or "missing",
		node.x and node.y and "valid" or "missing"
	)

	Table.clear(self.polygon)
	for _, component in ipairs(self.polygon) do
		table.insert(self.polygon, component)
	end

	if node.left and node.right then
		if self:getIsLeaf() then
			self.children[BSPNode.CHILD_LEFT] = BSPNode()
			self.children[BSPNode.CHILD_RIGHT] = BSPNode()
		end

		self.children[BSPNode.CHILD_LEFT]:deserialize(node.left)
		self.children[BSPNode.CHILD_RIGHT]:deserialize(node.right)

		self.x = node.x
		self.y = node.y
		self.normalX = node.normalX
		self.normalY = node.normalY
	else
		self:clear()
	end

	return self
end

function BSPNode:clone()
	return BSPNode():deserialize(self:serialize())
end

return BSPNode
