local Object = require("rat-scratch-common").Object
local ObjectPool = require("rat-scratch-common").ObjectPool
local Table = require("rat-scratch-common").Table
local Common = require("rat-scratch-math.Common")

--- @alias RatScratch.Math.RatScratch.Math.KDTreeNode.DistanceFunc

--- @generic T
--- @class RatScratch.Math.KDTreeNode<T> : RatScratch.Common.BaseObject
--- @overload fun<T>(value: T, axis: RatScratch.Math.KDTree.Axis): RatScratch.Math.KDTreeNode<T>
--- @field private tree RatScratch.Math.KDTree<T>
--- @field private value T
--- @field private axis RatScratch.Math.KDTree.Axis
--- @field private left? RatScratch.Math.KDTreeNode
--- @field private right? RatScratch.Math.KDTreeNode
local KDTreeNode = Object()

--- @generic T
--- @param self RatScratch.Math.KDTreeNode<T>
--- @param tree RatScratch.Math.KDTree<T>
--- @param value RatScratch.Math.Vector3
--- @param axis RatScratch.Math.KDTree.Axis
function KDTreeNode:new(tree, value, axis)
	self.tree = tree
	self.value = value
	self.axis = axis
end

--- @generic T
--- @param self RatScratch.Math.KDTreeNode<T>
--- @return T
function KDTreeNode:getValue()
	return self.value
end

function KDTreeNode:getAxis()
	return self.axis
end

--- @generic T
--- @param self RatScratch.Math.KDTreeNode<T>
--- @param left? RatScratch.Math.KDTreeNode<T>
--- @param right? RatScratch.Math.KDTreeNode<T>
function KDTreeNode:setChildren(left, right)
	self.left = left
	self.right = right
end

function KDTreeNode:getLeft()
	return self.left
end

function KDTreeNode:getRight()
	return self.right
end

function KDTreeNode:getIsLeaf()
	return not (self.left or self.right)
end

--- @alias RatScratch.Math.KDTreeNode.SearchFunc fun(value: RatScratch.Math.KDTreeNode): boolean

--- @private
--- @param target RatScratch.Math.Vector3
--- @param best? RatScratch.Math.KDTreeNode
--- @param bestFastDistance number
--- @param searchFunc RatScratch.Math.KDTreeNode.SearchFunc
--- @return RatScratch.Math.KDTreeNode?, number
--- @overload fun(self: RatScratch.Math.KDTreeNode, target: RatScratch.Math.Vector3, best: RatScratch.Math.KDTreeNode, bestFastDistance: number): RatScratch.Math.KDTreeNode, number
function KDTreeNode:_search(target, best, bestFastDistance, searchFunc)
	local currentFastDistance = self.tree:fastDistance(self.value, target)
	if
		currentFastDistance < bestFastDistance
		and (not searchFunc or searchFunc(self))
	then
		bestFastDistance = currentFastDistance
		best = self
	end

	local side = self.tree:compare(self.axis, target, self.value)
	local difference = self.tree:difference(self.axis, target, self.value)

	local near = side < 0 and self.left or self.right
	local far = side < 0 and self.right or self.left

	if near then
		best, bestFastDistance =
			near:_search(target, best, bestFastDistance, searchFunc)
	end

	if far and (difference ^ 2) < bestFastDistance then
		best, bestFastDistance =
			far:_search(target, best, bestFastDistance, searchFunc)
	end

	return best, bestFastDistance
end

--- @param target RatScratch.Math.Vector3
--- @return RatScratch.Math.KDTreeNode, number
function KDTreeNode:nearest(target)
	return self:_search(
		target,
		self,
		self.tree:fastDistance(self.value, target)
	)
end

--- @param target RatScratch.Math.Vector3
--- @param func RatScratch.Math.KDTreeNode.SearchFunc
--- @return RatScratch.Math.KDTreeNode?, number
function KDTreeNode:search(target, func)
	local best = func(self) and self or nil
	local bestFastDistance = best and self.tree:fastDistance(self.value, target)
		or math.huge
	return self:_search(target, best, bestFastDistance, func)
end

--- @private
--- @param target RatScratch.Math.Vector3
--- @param best? RatScratch.Math.KDTreeNode
--- @param bestFastDistance number
--- @param E number
--- @return RatScratch.Math.KDTreeNode?, RatScratch.Math.KDTreeNode?, number
function KDTreeNode:_find(target, best, bestParent, parent, bestFastDistance, E)
	local currentFastDistance = self.tree:fastDistance(self.value, target)
	if currentFastDistance <= bestFastDistance then
		if
			(
				Common.equal(currentFastDistance, 0, E)
				and not Common.equal(bestFastDistance, 0, E)
			) or self.value == target
		then
			bestFastDistance = currentFastDistance
			bestParent = parent
			best = self
		end
	end

	local side = self.tree:compare(self.axis, target, self.value)
	local difference = self.tree:difference(self.axis, target, self.value)

	local near = side < 0 and self.left or self.right
	local far = side < 0 and self.right or self.left

	if near then
		best, bestParent, bestFastDistance =
			near:_find(target, best, bestParent, self, bestFastDistance, E)
	end

	if far and (difference ^ 2) <= bestFastDistance then
		best, bestParent, bestFastDistance =
			far:_find(target, best, bestParent, self, bestFastDistance, E)
	end

	return best, bestParent, bestFastDistance
end

--- @param target RatScratch.Math.Vector3
--- @param E? number
--- @return RatScratch.Math.KDTreeNode | nil, RatScratch.Math.KDTreeNode | nil
function KDTreeNode:find(target, E)
	E = (E or Common.EPSILON) ^ 2

	local result, parent, bestFastDistance =
		self:_find(target, nil, nil, nil, math.huge, E)
	if result and Common.equal(bestFastDistance, 0, E) then
		return result, parent
	end

	return nil, nil
end

--- @param value RatScratch.Math.Vector3
function KDTreeNode:add(value)
	local side = self.tree:compare(self.axis, self.value, value)

	if side < 0 then
		if self.left then
			self.left:add(value)
		else
			local nextAxis = self.tree:nextAxis(self.axis)
			self.left = KDTreeNode(value, nextAxis)
		end
	else
		if self.right then
			self.right:add(value)
		else
			local nextAxis = self.tree:nextAxis(self.axis)
			self.right = KDTreeNode(value, nextAxis)
		end
	end
end

--- @param value RatScratch.Math.Vector3
--- @param E? number
--- @return RatScratch.Math.KDTreeNode | nil, RatScratch.Math.Vector3?
function KDTreeNode:remove(value, E)
	local node, parent = self:find(value, E)
	if not node then
		return self, nil
	end

	if node == self and node:getIsLeaf() then
		return nil, node:getValue()
	end

	local removedPoint = node:getValue()
	node:_removeSelf(parent, E)

	return self, removedPoint
end

--- @private
--- @param parent? RatScratch.Math.KDTreeNode
--- @param E? number
function KDTreeNode:_removeSelf(parent, E)
	if self:getIsLeaf() then
		if not parent then
			return
		end

		if parent.left == self then
			parent.left = nil
		elseif parent.right == self then
			parent.right = nil
		end

		return
	end

	local nextNode
	if self.right then
		nextNode = self.right:_findMin(self.axis)
	elseif self.left then
		nextNode = self.left:_findMax(self.axis)
	end

	local value = nextNode.value
	self:remove(value)
	self.value = value
end

--- @private
--- @param targetAxis RatScratch.Math.KDTree.Axis
--- @return RatScratch.Math.KDTreeNode
function KDTreeNode:_findMax(targetAxis)
	if self.axis == targetAxis then
		local right = self.right and self.right:_findMax(targetAxis)
		if right and right.value[targetAxis] > self.value[targetAxis] then
			return right
		end

		return self
	end

	local left = self.left and self.left:_findMax(targetAxis)
	local right = self.right and self.right:_findMax(targetAxis)

	local max = self
	if left and left.value[targetAxis] > max.value[targetAxis] then
		max = left
	end

	if right and right.value[targetAxis] > max.value[targetAxis] then
		max = right
	end

	return max
end

--- @private
--- @param targetAxis RatScratch.Math.KDTree.Axis
--- @return RatScratch.Math.KDTreeNode
function KDTreeNode:_findMin(targetAxis)
	if self.axis == targetAxis then
		local left = self.left and self.left:_findMin(targetAxis)
		if left and left.value[targetAxis] < self.value[targetAxis] then
			return left
		end

		return self
	end

	local left = self.left and self.left:_findMin(targetAxis)
	local right = self.right and self.right:_findMin(targetAxis)

	local smallest = self
	if left and left.value[targetAxis] < smallest.value[targetAxis] then
		smallest = left
	end

	if right and right.value[targetAxis] < smallest.value[targetAxis] then
		smallest = right
	end

	return smallest
end

--- @param array? RatScratch.Math.Vector3[]
--- @return RatScratch.Math.Vector3[]
function KDTreeNode:collect(array)
	array = array or {}
	table.insert(array, self.value)

	if self.left then
		self.left:collect(array)
	end

	if self.right then
		self.right:collect(array)
	end

	return array
end

return KDTreeNode
