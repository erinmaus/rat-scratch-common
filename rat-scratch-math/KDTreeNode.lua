local Object = require("rat-scratch-common").Object
local ObjectPool = require("rat-scratch-common").ObjectPool
local Table = require("rat-scratch-common").Table
local Common = require("rat-scratch-math.Common")

--- @alias RatScratch.Math.KDTreeNode.Axis "x" | "y" | "z"
--- @alias RatScratch.Math.KDTreeNode.Dimension 1 | 2 | 3

--- @class RatScratch.Math.KDTreeNode : RatScratch.Common.BaseObject
--- @overload fun(point: RatScratch.Math.Vector3, axis: RatScratch.Math.KDTreeNode.Axis, dimension: RatScratch.Math.KDTreeNode.Dimension): RatScratch.Math.KDTreeNode
--- @field private point RatScratch.Math.Vector3
--- @field private axis RatScratch.Math.KDTreeNode.Axis
--- @field private dimension RatScratch.Math.KDTreeNode.Dimension
--- @field private left? RatScratch.Math.KDTreeNode
--- @field private right? RatScratch.Math.KDTreeNode
local KDTreeNode = Object()

KDTreeNode.AXIS = {
	"x",
	"y",
	"z",
}

KDTreeNode.DIMENSION = {
	x = 1,
	y = 2,
	z = 3,
}

--- @type table<RatScratch.Math.KDTreeNode.Axis, RatScratch.Common.Search.CompareFunc<RatScratch.Math.Vector3, RatScratch.Math.Vector3>>
KDTreeNode.COMPARE_FUNCS = {
	x = function(a, b)
		return Common.zerosign(a.x - b.x)
	end,
	y = function(a, b)
		return Common.zerosign(a.y - b.y)
	end,
	z = function(a, b)
		return Common.zerosign(a.z - b.z)
	end,
}

--- @param point RatScratch.Math.Vector3
--- @param axis RatScratch.Math.KDTreeNode.Axis
--- @param dimensions RatScratch.Math.KDTreeNode.Dimension
function KDTreeNode:new(point, axis, dimensions)
	self.point = point
	self.axis = axis
	self.dimensions = dimensions
end

function KDTreeNode:getPoint()
	return self.point
end

function KDTreeNode:getAxis()
	return self.axis
end

function KDTreeNode:getDimension()
	return self.dimensions
end

--- @package
--- @param left? RatScratch.Math.KDTreeNode
--- @param right? RatScratch.Math.KDTreeNode
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

--- @alias RatScratch.Math.KDTreeNode.SearchFunc fun(point: RatScratch.Math.KDTreeNode): boolean

--- @private
--- @param target RatScratch.Math.Vector3
--- @param best? RatScratch.Math.KDTreeNode
--- @param bestDistanceSquared number
--- @param searchFunc RatScratch.Math.KDTreeNode.SearchFunc
--- @return RatScratch.Math.KDTreeNode?, number
--- @overload fun(self: RatScratch.Math.KDTreeNode, target: RatScratch.Math.Vector3, best: RatScratch.Math.KDTreeNode, bestDistanceSquared: number): RatScratch.Math.KDTreeNode, number
function KDTreeNode:_search(target, best, bestDistanceSquared, searchFunc)
	local currentDistanceSquared = self.point:distanceSquared(target)
	if
		currentDistanceSquared < bestDistanceSquared
		and (not searchFunc or searchFunc(self))
	then
		bestDistanceSquared = currentDistanceSquared
		best = self
	end

	local compareFunc = KDTreeNode.COMPARE_FUNCS[self.axis]
	local side = compareFunc(target, self.point)
	local difference = target[self.axis] - self.point[self.axis]

	local near = side < 0 and self.left or self.right
	local far = side < 0 and self.right or self.left

	if near then
		best, bestDistanceSquared =
			near:_search(target, best, bestDistanceSquared, searchFunc)
	end

	if far and (difference ^ 2) < bestDistanceSquared then
		best, bestDistanceSquared =
			far:_search(target, best, bestDistanceSquared, searchFunc)
	end

	return best, bestDistanceSquared
end

--- @param target RatScratch.Math.Vector3
--- @return RatScratch.Math.KDTreeNode, number
function KDTreeNode:nearest(target)
	return self:_search(target, self, self.point:distanceSquared(target))
end

--- @param target RatScratch.Math.Vector3
--- @param func RatScratch.Math.KDTreeNode.SearchFunc
--- @return RatScratch.Math.KDTreeNode?, number
function KDTreeNode:search(target, func)
	local best = func(self) and self or nil
	local bestDistanceSquared = best and self.point:distanceSquared(target)
		or math.huge
	return self:_search(target, best, bestDistanceSquared, func)
end

--- @private
--- @param target RatScratch.Math.Vector3
--- @param best? RatScratch.Math.KDTreeNode
--- @param bestDistanceSquared number
--- @param E number
--- @return RatScratch.Math.KDTreeNode?, RatScratch.Math.KDTreeNode?, number
function KDTreeNode:_find(
	target,
	best,
	bestParent,
	parent,
	bestDistanceSquared,
	E
)
	local currentDistanceSquared = self.point:distanceSquared(target)
	if currentDistanceSquared <= bestDistanceSquared then
		if
			(
				Common.equal(currentDistanceSquared, 0, E)
				and not Common.equal(bestDistanceSquared, 0, E)
			) or self.point == target
		then
			bestDistanceSquared = currentDistanceSquared
			bestParent = parent
			best = self
		end
	end

	local func = KDTreeNode.COMPARE_FUNCS[self.axis]
	local side = func(target, self.point)
	local difference = target[self.axis] - self.point[self.axis]

	local near = side < 0 and self.left or self.right
	local far = side < 0 and self.right or self.left

	if near then
		best, bestParent, bestDistanceSquared =
			near:_find(target, best, bestParent, self, bestDistanceSquared, E)
	end

	if far and (difference ^ 2) <= bestDistanceSquared then
		best, bestParent, bestDistanceSquared =
			far:_find(target, best, bestParent, self, bestDistanceSquared, E)
	end

	return best, bestParent, bestDistanceSquared
end

--- @param target RatScratch.Math.Vector3
--- @param E? number
--- @return RatScratch.Math.KDTreeNode | nil, RatScratch.Math.KDTreeNode | nil
function KDTreeNode:find(target, E)
	E = (E or Common.EPSILON) ^ 2

	local result, parent, bestDistanceSquared =
		self:_find(target, nil, nil, nil, math.huge, E)
	if result and Common.equal(bestDistanceSquared, 0, E) then
		return result, parent
	end

	return nil, nil
end

--- @param point RatScratch.Math.Vector3
function KDTreeNode:add(point)
	local func = KDTreeNode.COMPARE_FUNCS[self.axis]
	local side = func(point, self.point)

	if side < 0 then
		if self.left then
			self.left:add(point)
		else
			local nextAxis = KDTreeNode._nextAxis(self.axis, self.dimensions)
			self.left = KDTreeNode(point, nextAxis, self.dimensions)
		end
	else
		if self.right then
			self.right:add(point)
		else
			local nextAxis = KDTreeNode._nextAxis(self.axis, self.dimensions)
			self.right = KDTreeNode(point, nextAxis, self.dimensions)
		end
	end
end

--- @param point RatScratch.Math.Vector3
--- @param E? number
--- @return RatScratch.Math.KDTreeNode | nil, RatScratch.Math.Vector3?
function KDTreeNode:remove(point, E)
	local node, parent = self:find(point, E)
	if not node then
		return self, nil
	end

	if node == self and node:getIsLeaf() then
		return nil, node:getPoint()
	end

	local removedPoint = node:getPoint()
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

	local point = nextNode.point
	self:remove(point)
	self.point = point
end

--- @private
--- @param targetAxis RatScratch.Math.KDTreeNode.Axis
--- @return RatScratch.Math.KDTreeNode
function KDTreeNode:_findMax(targetAxis)
	if self.axis == targetAxis then
		local right = self.right and self.right:_findMax(targetAxis)
		if right and right.point[targetAxis] > self.point[targetAxis] then
			return right
		end

		return self
	end

	local left = self.left and self.left:_findMax(targetAxis)
	local right = self.right and self.right:_findMax(targetAxis)

	local max = self
	if left and left.point[targetAxis] > max.point[targetAxis] then
		max = left
	end

	if right and right.point[targetAxis] > max.point[targetAxis] then
		max = right
	end

	return max
end

--- @private
--- @param targetAxis RatScratch.Math.KDTreeNode.Axis
--- @return RatScratch.Math.KDTreeNode
function KDTreeNode:_findMin(targetAxis)
	if self.axis == targetAxis then
		local left = self.left and self.left:_findMin(targetAxis)
		if left and left.point[targetAxis] < self.point[targetAxis] then
			return left
		end

		return self
	end

	local left = self.left and self.left:_findMin(targetAxis)
	local right = self.right and self.right:_findMin(targetAxis)

	local smallest = self
	if left and left.point[targetAxis] < smallest.point[targetAxis] then
		smallest = left
	end

	if right and right.point[targetAxis] < smallest.point[targetAxis] then
		smallest = right
	end

	return smallest
end

--- @private
--- @param currentAxis RatScratch.Math.KDTreeNode.Axis
--- @param dimensions RatScratch.Math.KDTreeNode.Dimension
--- @return RatScratch.Math.KDTreeNode.Axis
function KDTreeNode._nextAxis(currentAxis, dimensions)
	local d = KDTreeNode.DIMENSION[currentAxis]
	return KDTreeNode.AXIS[Table.wrapIndex(d + 1, dimensions)]
end

--- @param array? RatScratch.Math.Vector3[]
--- @return RatScratch.Math.Vector3[]
function KDTreeNode:collect(array)
	array = array or {}
	table.insert(array, self.point)

	if self.left then
		self.left:collect(array)
	end

	if self.right then
		self.right:collect(array)
	end

	return array
end

do
	--- @type RatScratch.Math.Vector3[]
	local _cachedArray = {}

	--- @param points RatScratch.Math.Vector3[]
	--- @param left integer
	--- @param right integer
	--- @param depth integer
	--- @param n RatScratch.Math.KDTreeNode.Dimension
	--- @param pool RatScratch.Common.ObjectPool<RatScratch.Math.KDTreeNode>
	--- @return RatScratch.Math.KDTreeNode | nil
	local function _build(points, left, right, depth, n, pool)
		if left > right then
			return nil
		end

		local axis = KDTreeNode.AXIS[Table.wrapIndex(depth, n)]
		local func = KDTreeNode.COMPARE_FUNCS[axis]

		local mid = math.floor((left + right) / 2)
		Table.select(points, left, right, mid, func)

		local result = pool:pop(points[mid], axis, n)
		result:setChildren(
			_build(points, left, mid - 1, depth + 1, n, pool),
			_build(points, mid + 1, right, depth + 1, n, pool)
		)

		return result
	end

	--- @param points RatScratch.Math.Vector3[]
	--- @param dimensions? RatScratch.Math.KDTreeNode.Dimension
	--- @param pool? RatScratch.Common.ObjectPool<RatScratch.Math.KDTreeNode>
	--- @return RatScratch.Math.KDTreeNode
	function KDTreeNode.build(points, dimensions, pool)
		assert(#points >= 1, "expected at least one point")

		pool = pool or ObjectPool(KDTreeNode)
		dimensions = dimensions or #KDTreeNode.AXIS

		local t = Table.clone(points, _cachedArray)
		local result = _build(t, 1, #t, 1, dimensions, pool)
		Table.clear(t)

		--- @cast result RatScratch.Math.KDTreeNode
		return result
	end
end

return KDTreeNode
