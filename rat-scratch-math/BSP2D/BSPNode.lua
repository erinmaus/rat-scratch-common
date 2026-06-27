local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Polygon = require("rat-scratch-math.Geometry2D.Polygon")

--- @class RatScratch.Math.BSP2D.BSPNode : RatScratch.Common.BaseObject
--- @overload fun(polygon: number[], parent?: RatScratch.Math.BSP2D.BSPNode): RatScratch.Math.BSP2D.BSPNode
--- @field private parent? RatScratch.Math.BSP2D.BSPNode
--- @field private children RatScratch.Math.BSP2D.BSPNode[]
--- @field private polygon number[]
--- @field private normalX number
--- @field private normalY number
--- @field private x number
--- @field private y number
local BSPNode = Object()

--- @private
BSPNode.CHILD_LEFT = 1

--- @private
BSPNode.CHILD_RIGHT = 2

--- @param polygon number[]
--- @param parent RatScratch.Math.BSP2D.BSPNode
function BSPNode:new(polygon, parent)
	self.parent = parent
	self.polygon = polygon
	self.children = {}
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

--- @param x number
--- @param y number
--- @param normalX number
--- @param normalY number
--- @return boolean
function BSPNode:split(x, y, normalX, normalY)
	assert(self:getIsLeaf(), "BSP node is not leaf; cannot split")

	local success, left, right = Polygon.split(
		x,
		y,
		x + normalX,
		y + normalY,
		self.polygon
	)

	if not success then
		return false
	end

	self.x, self.y = x, y
	self.normalX, self.normalY = normalX, normalY

	self.children[BSPNode.CHILD_LEFT] = BSPNode(left, self)
	self.children[BSPNode.CHILD_RIGHT] = BSPNode(right, self)

	return true
end

return BSPNode
