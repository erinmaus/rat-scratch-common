local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Vector3 = require("rat-scratch-math").Vector3
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")

--- @class RatScratch.Graphics.BVHNode : RatScratch.Common.BaseObject
--- @field private parent RatScratch.Graphics.BVHNode | false
--- @field private nodeIndex integer
--- @field private depth integer
--- @field private axis integer
--- @field private minBounds RatScratch.Math.Vector3
--- @field private maxBounds RatScratch.Math.Vector3
--- @field private centerMinBounds RatScratch.Math.Vector3
--- @field private centerMaxBounds RatScratch.Math.Vector3
--- @field private leftNode RatScratch.Graphics.BVHNode | false
--- @field private rightNode RatScratch.Graphics.BVHNode | false
--- @field private index integer
--- @field private count integer
--- @field private tag integer
--- @overload fun(nodeIndex?: integer): RatScratch.Graphics.BVHNode
local BVHNode = Object()

BVHNode.NODE_FORMAT = {
	{ location = 0, name = "boundsMin", format = "floatvec3" },
	{ location = 1, name = "boundsMax", format = "floatvec3" },
	{ location = 2, name = "indexCount", format = "uint32vec2" },
	{ location = 3, name = "tag", format = "uint32" },
}

BVHNode.NODE_FORMAT_INSTANCE = BufferFormat.get(BVHNode.NODE_FORMAT)

function BVHNode:new(nodeIndex)
	self.parent = false

	self.nodeIndex = nodeIndex or 1
	self.depth = 1
	self.axis = 1

	self.minBounds = Vector3()
	self.maxBounds = Vector3()

	self.centerMinBounds = Vector3()
	self.centerMaxBounds = Vector3()

	self.leftNode = false
	self.rightNode = false

	self.index = 1
	self.count = 0

	self.tag = 0
end

--- @param node RatScratch.Graphics.BVHNode
--- @return RatScratch.Graphics.BVHNode
function BVHNode.makeReadOnly(node)
	if node.parent then
		return node
	end

	local result = BVHNode()
	result.parent = node

	return result
end

function BVHNode:getIsReadOnly()
	return not not self.parent
end

--- @param data number[]
--- @param offset? integer
function BVHNode:toData(data, offset)
	BufferFormat.resetValue(BVHNode.NODE_FORMAT_INSTANCE, data, offset)

	local minBounds, maxBounds = self:getBounds()
	BufferFormat.setValue(
		BVHNode.NODE_FORMAT_INSTANCE,
		data,
		"boundsMin",
		offset,
		minBounds:get()
	)

	BufferFormat.setValue(
		BVHNode.NODE_FORMAT_INSTANCE,
		data,
		"boundsMax",
		offset,
		maxBounds:get()
	)

	if self:getIsLeaf() then
		local index, count = self:getIndexCount()

		BufferFormat.setValue(
			BVHNode.NODE_FORMAT_INSTANCE,
			data,
			"indexCount",
			offset,
			index - 1,
			count
		)
	else
		local left, right = self:getLeftNode(), self:getRightNode()

		if left and right then
			BufferFormat.setValue(
				BVHNode.NODE_FORMAT_INSTANCE,
				data,
				"indexCount",
				offset,
				left:getNodeIndex() - 1,
				0
			)
		else
			BufferFormat.setValue(
				BVHNode.NODE_FORMAT_INSTANCE,
				data,
				"indexCount",
				offset,
				-1,
				0
			)
		end
	end

	BufferFormat.setValue(
		BVHNode.NODE_FORMAT_INSTANCE,
		data,
		"tag",
		offset,
		self.tag
	)
end

--- @return RatScratch.Math.Vector3, RatScratch.Math.Vector3
function BVHNode:getBounds()
	return self.parent and self.parent.minBounds or self.minBounds,
		self.parent and self.parent.minBounds or self.maxBounds
end

--- @param axis integer | RatScratch.Math.Vector3.Axis
--- @return number, number
function BVHNode:getBoundsAxis(axis)
	local minBounds, maxBounds = self:getBounds()
	return minBounds:getAxis(axis), maxBounds:getAxis(axis)
end

--- @param min RatScratch.Math.Vector3
--- @param max RatScratch.Math.Vector3
function BVHNode:setBounds(min, max)
	assert(not self.parent, "node is read-only")

	self.minBounds:from(min:get())
	self.maxBounds:from(max:get())
end

--- @return RatScratch.Math.Vector3, RatScratch.Math.Vector3
function BVHNode:getCenterBounds()
	return self.parent and self.parent.centerMinBounds or self.centerMinBounds,
		self.parent and self.parent.centerMaxBounds or self.centerMaxBounds
end

--- @param axis integer | RatScratch.Math.Vector3.Axis
--- @return number, number
function BVHNode:getCenterBoundsAxis(axis)
	local centerMinBounds, centerMaxBounds = self:getCenterBounds()
	return centerMinBounds:getAxis(axis), centerMaxBounds:getAxis(axis)
end

--- @param min RatScratch.Math.Vector3
--- @param max RatScratch.Math.Vector3
function BVHNode:setCenterBounds(min, max)
	assert(not self.parent, "node is read-only")

	self.centerMinBounds:from(min:get())
	self.centerMaxBounds:from(max:get())
end

--- @return RatScratch.Graphics.BVHNode?
function BVHNode:getLeftNode()
	return self.leftNode or nil
end

--- @return RatScratch.Graphics.BVHNode?
function BVHNode:getRightNode()
	return self.rightNode or nil
end

--- @param left RatScratch.Graphics.BVHNode
--- @param right RatScratch.Graphics.BVHNode
--- @overload fun()
function BVHNode:setChildren(left, right)
	assert(not self.parent, "node is read-only")

	local isValid = left and right

	assert(
		not isValid or left:getNodeIndex() + 1 == right:getNodeIndex(),
		"right node index (got %d, expected %d) must be adjacent to left node index (%d)",
		right:getNodeIndex(),
		left:getNodeIndex() + 1,
		left:getNodeIndex()
	)

	assert(
		not isValid or left:getNodeIndex() > self.nodeIndex,
		"left node index (got %d) must be greater than self node index (%d)",
		left:getNodeIndex(),
		self.nodeIndex
	)

	assert(
		not isValid or right:getNodeIndex() > self.nodeIndex,
		"right node index (got %d) must be greater than self node index (%d)",
		right:getNodeIndex(),
		self.nodeIndex
	)

	self.leftNode = isValid and left or false
	self.rightNode = isValid and right or false
end

function BVHNode:getNodeIndex()
	return self.parent and self.parent.nodeIndex or self.nodeIndex
end

function BVHNode:getDepth()
	return self.parent and self.parent.depth or self.depth
end

--- @param value integer
function BVHNode:setDepth(value)
	assert(not self.parent, "node is read-only")
	self.depth = value
end

function BVHNode:getAxis()
	return self.parent and self.parent.axis or self.axis
end

--- @param value integer
function BVHNode:setAxis(value)
	assert(not self.parent, "node is read-only")
	self.axis = value
end

function BVHNode:getIsLeaf()
	return not (self.leftNode or self.rightNode)
end

function BVHNode:getIndexCount()
	if not self:getIsLeaf() then
		return 0, 0
	end

	return self.index, self.count
end

--- @param index integer
--- @param count integer
function BVHNode:setIndexCount(index, count)
	assert(not self.parent, "node is read-only")
	assert(self:getIsLeaf(), "can only set index/count on leaf nodes")

	self.index = math.max(index, 1)
	self.count = math.max(count, 0)
end

return BVHNode
