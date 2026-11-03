local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local BVHNode = require("rat-scratch-graphics.BVHNode")
local Table = require("rat-scratch-common").Table
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")
local Common = require("rat-scratch-math").Common
local Vector3 = require("rat-scratch-math").Vector3
local AABB = require("rat-scratch-math").Geometry3D.AABB

--- @class RatScratch.Graphics.BVH : RatScratch.Common.BaseObject
--- @field private nodeCount integer
--- @field private nodes RatScratch.Graphics.BVHNode[]
--- @field private readonlyNodes RatScratch.Graphics.BVHNode[]
--- @field private data number[]
--- @field private objectCount integer
--- @field private objectIndices integer[]
--- @overload fun(): RatScratch.Graphics.BVH
local BVH = Object()

--- @param nodeCount? integer
--- @param objectCount? integer
function BVH:new(nodeCount, objectCount)
	nodeCount = math.max(nodeCount or 0, 0)
	objectCount = math.max(objectCount or 0, 0)

	self.nodeCount = nodeCount
	self.nodes = Table.new(nodeCount, 0)
	self.readonlyNodes = Table.new(nodeCount, 0)
	self.data = Table.new(
		nodeCount * BVHNode.NODE_FORMAT_INSTANCE:getComponentCount(),
		0
	)

	for i = 1, nodeCount do
		local node = BVHNode(i)

		table.insert(self.nodes, node)
		table.insert(self.readonlyNodes, BVHNode.makeReadOnly(node))

		BufferFormat.resetValue(
			BVHNode.NODE_FORMAT_INSTANCE,
			self.data,
			Table.indexToStride(
				i,
				BVHNode.NODE_FORMAT_INSTANCE:getComponentCount()
			) - 1
		)
	end

	self.objectCount = objectCount
	self.objectIndices = objectCount > 0 and Table.new(objectCount, 0) or {}
	for i = 1, objectCount do
		self.objectIndices[i] = i
	end
end

--- @param index integer
--- @return RatScratch.Graphics.BVHNode
function BVH:getNode(index)
	return self.readonlyNodes[index]
end

--- @protected
--- @param index integer
function BVH:newNode(index)
	self.nodeCount = self.nodeCount + 1
	assert(
		index == self.nodeCount,
		"expected to create node %d, got %d instead",
		index,
		self.nodeCount
	)

	local node = self.nodes[self.nodeCount]
	if not node then
		node = BVHNode(self.nodeCount)
		self.nodes[self.nodeCount] = node
		self.readonlyNodes[self.nodeCount] = BVHNode.makeReadOnly(node)

		BufferFormat.resetValue(
			BVHNode.NODE_FORMAT_INSTANCE,
			self.data,
			Table.indexToStride(
				self.nodeCount,
				BVHNode.NODE_FORMAT_INSTANCE:getComponentCount()
			) - 1
		)
	else
		node:reset(self.nodeCount)
	end

	return node
end

--- @protected
--- @param index integer
--- @return RatScratch.Graphics.BVHNode
function BVH:getProtectedNode(index)
	return self.nodes[index]
end

function BVH:getObjectCount()
	return self.objectCount
end

--- @param objectIndex integer
--- @return RatScratch.Math.Vector3, RatScratch.Math.Vector3
function BVH:getObjectBounds(objectIndex)
	return self:ABSTRACT()
end

--- @param objectIndex integer
--- @return RatScratch.Math.Vector3
function BVH:getObjectCenter(objectIndex)
	return self:ABSTRACT()
end

--- @param objectIndex integer
--- @param origin RatScratch.Math.Vector3
--- @param direction RatScratch.Math.Vector3
--- @return boolean, number
function BVH:raycastObject(objectIndex, origin, direction)
	return self:ABSTRACT()
end

do
	local _currentMin, _currentMax = Vector3(), Vector3()
	local _currentCenterMin, _currentCenterMax = Vector3(), Vector3()

	--- @private
	--- @param node RatScratch.Graphics.BVHNode
	function BVH:_refreshNodeFromObjects(node)
		local index, count = node:getIndexCount()

		if count == 0 then
			local nodeMin, nodeMax = node:getBounds()
			local isDirty = nodeMin:getLengthSquared() > 0
				or nodeMax:getLengthSquared() > 0

			node:setBounds(Vector3.ZERO, Vector3.ZERO)

			local nodeCenterMin, nodeCenterMax = node:getCenterBounds()
			local isDirty = isDirty
				or nodeCenterMin:getLengthSquared() > 0
				or nodeCenterMax:getLengthSquared() > 0

			node:setCenterBounds(Vector3.ZERO, Vector3.ZERO)

			return isDirty
		end

		local currentMin, currentMax =
			_currentMin:from(math.huge), _currentMax:from(-math.huge)
		local currentCenterMin, currentCenterMax =
			_currentCenterMin:from(math.huge),
			_currentCenterMax:from(-math.huge)

		local j = index + count - 1
		for i = index, j do
			local objectIndex = self.objectIndices[i]
			local objectMin, objectMax = self:getObjectBounds(objectIndex)
			local objectCenter = self:getObjectCenter(objectIndex)

			AABB.union(currentMin, currentMax, objectMin, objectMax)
			AABB.expand(currentCenterMin, currentCenterMax, objectCenter)
		end

		local nodeMin, nodeMax = node:getBounds()
		local nodeCenterMin, nodeCenterMax = node:getCenterBounds()
		if
			not (currentMin:equal(nodeMin) and currentMax:equal(nodeMax))
			or not (
				currentCenterMin:equal(nodeCenterMin)
				and currentCenterMax:equal(nodeCenterMax)
			)
		then
			node:setBounds(currentMin, currentMax)
			node:setCenterBounds(currentCenterMin, currentCenterMax)
			return true
		end

		return false
	end

	--- @private
	--- @param node RatScratch.Graphics.BVHNode
	function BVH:_refreshNodeFromChildren(node)
		local left, right = node:getLeftNode(), node:getRightNode()
		assert(left and right, "a child node is nil")

		local leftMin, leftMax = left:getBounds()
		local currentMin = _currentMin:from(leftMin:get())
		local currentMax = _currentMax:from(leftMax:get())

		local rightMin, rightMax = right:getBounds()
		AABB.union(currentMin, currentMax, rightMin, rightMax)

		local nodeMin, nodeMax = node:getBounds()
		if not (currentMin:equal(nodeMin) and currentMax:equal(nodeMax)) then
			node:setBounds(currentMin, currentMax)
			return true
		end
	end

	function BVH:_refreshNode(node)
		if node:getIsLeaf() then
			return self:_refreshNodeFromObjects(node)
		end

		return self:_refreshNodeFromChildren(node)
	end
end

function BVH:flush()
	for i = 1, self.nodeCount do
		local node = self.nodes[i]

		node:toData(
			self.data,
			Table.indexToStride(
				i,
				BVHNode.NODE_FORMAT_INSTANCE:getComponentCount()
			) - 1
		)
	end
end

function BVH:refresh()
	local wasDirty = false

	for i = self.nodeCount, 1, -1 do
		local node = self.nodes[i]

		if self:_refreshNode(node) then
			node:toData(
				self.data,
				Table.indexToStride(
					i,
					BVHNode.NODE_FORMAT_INSTANCE:getComponentCount()
				) - 1
			)

			wasDirty = true
		end
	end

	return wasDirty
end

--- @alias RatScratch.Graphics.BVH.BuildStrategy RatScratch.Graphics.BVH.StacklessBuildStrategy | RatScratch.Graphics.BVH.SAHBuildStrategy

--- @class RatScratch.Graphics.BVH.StacklessBuildStrategy
--- @field public strategy "stackless"
local StacklessBuildStrategy = {}

local DEFAULT_STACKLESS_BUILD_STRATEGY = {
	strategy = "stackless",
}

--- @type RatScratch.Graphics.BVH.StacklessBuildStrategy
StacklessBuildStrategy.DEFAULT_STACKLESS_BUILD_STRATEGY =
	DEFAULT_STACKLESS_BUILD_STRATEGY

--- @class RatScratch.Graphics.BVH.SAHBuildStrategy
--- @field public strategy "sah"
--- @field public maxDepth? integer
--- @field public minObjectCount? integer
--- @field public maxObjectCount? integer
--- @field public binCount? integer
local SAHBuildStrategy = {}

local DEFAULT_SAH_BUILD_STRATEGY = {
	strategy = "sah",
	maxDepth = 32,
	minObjectCount = 1,
	maxObjectCount = 8,
	binCount = 8,
}

--- @type RatScratch.Graphics.BVH.SAHBuildStrategy
BVH.DEFAULT_SAH_BUILD_STRATEGY = DEFAULT_SAH_BUILD_STRATEGY

do
	local _minBins = {}
	local _maxBins = {}
	local _countBins = {}
	local _leftArea = {}
	local _rightArea = {}
	local _leftMin, _leftMax = Vector3(), Vector3()
	local _rightMin, _rightMax = Vector3(), Vector3()

	--- @param strategy RatScratch.Graphics.BVH.SAHBuildStrategy
	--- @param node RatScratch.Graphics.BVHNode
	--- @param axis integer | RatScratch.Math.Vector3.Axis
	--- @return number, integer
	function BVH:_tryFindBestSplitPlane(strategy, node, axis)
		local binCount = strategy.binCount
			or DEFAULT_SAH_BUILD_STRATEGY.binCount

		local index, count = node:getIndexCount()
		if count == 0 then
			return math.huge, 2
		end

		local minSpan, maxSpan = node:getCenterBoundsAxis(axis)
		if minSpan == maxSpan then
			return math.huge, 2
		end

		local minBins, maxBins, countBins = _minBins, _maxBins, _countBins
		local leftArea, rightArea = _leftArea, _rightArea
		for i = 1, binCount do
			minBins[i] = minBins[i] or Vector3()
			minBins[i]:from(math.huge)

			maxBins[i] = maxBins[i] or Vector3()
			maxBins[i]:from(-math.huge)

			countBins[i] = 0

			leftArea[i] = 0
			rightArea[i] = 0
		end

		local inverseScale = binCount / (maxSpan - minSpan)
		local startIndex, stopIndex = index, index + count - 1
		for i = startIndex, stopIndex do
			local objectIndex = self.objectIndices[i]
			local objectMin, objectMax = self:getObjectBounds(objectIndex)
			local objectCenter = self:getObjectCenter(objectIndex)
			local objectCenterAxis = objectCenter:getAxis(axis)

			local binIndex = Common.clamp(
				math.floor((objectCenterAxis - minSpan) * inverseScale) + 1,
				1,
				binCount
			)

			countBins[binIndex] = countBins[binIndex] + 1
			AABB.union(
				minBins[binIndex],
				maxBins[binIndex],
				objectMin,
				objectMax
			)
		end

		local leftMin, leftMax =
			_leftMin:from(math.huge), _leftMax:from(-math.huge)
		local rightMin, rightMax =
			_rightMin:from(math.huge), _rightMax:from(-math.huge)

		local leftSum, rightSum = 0, 0
		for i = 1, binCount - 1 do
			local leftIndex, rightIndex = i, binCount - i + 1

			leftSum = leftSum + countBins[leftIndex]
			AABB.union(leftMin, leftMax, minBins[leftIndex], maxBins[leftIndex])
			leftArea[leftIndex] = leftSum
				* AABB.calculateSurfaceArea(leftMin, leftMax)

			rightSum = rightSum + countBins[rightIndex]
			AABB.union(
				rightMin,
				rightMax,
				minBins[rightIndex],
				maxBins[rightIndex]
			)
			rightArea[rightIndex - 1] = rightSum
				* AABB.calculateSurfaceArea(rightMin, rightMax)
		end

		local bestCost, bestBin = math.huge, 1
		for i = 1, binCount - 1 do
			local currentCost = leftArea[i] + rightArea[i]
			if currentCost < bestCost then
				bestCost = currentCost
				bestBin = i + 1
			end
		end

		return bestCost, bestBin
	end

	--- @param strategy RatScratch.Graphics.BVH.SAHBuildStrategy
	--- @param node RatScratch.Graphics.BVHNode
	function BVH:_findBestSplitPlane(strategy, node)
		local bestCost = math.huge
		local bestAxis, bestSplit = 1, 2
		for axis = 1, Vector3.AXIS_COUNT do
			local cost, split =
				self:_tryFindBestSplitPlane(strategy, node, axis)
			if cost < bestCost then
				bestCost = cost
				bestAxis = axis
				bestSplit = split
			end
		end

		return bestAxis, bestSplit, bestCost
	end

	--- @param strategy RatScratch.Graphics.BVH.SAHBuildStrategy
	--- @param node RatScratch.Graphics.BVHNode
	--- @return RatScratch.Graphics.BVHNode?, RatScratch.Graphics.BVHNode?
	function BVH:_subdivide(strategy, node)
		local maxDepth = strategy.maxDepth
			or DEFAULT_SAH_BUILD_STRATEGY.maxDepth
		local minObjectCount = strategy.minObjectCount
			or DEFAULT_SAH_BUILD_STRATEGY.minObjectCount
		local maxObjectCount = strategy.maxObjectCount
			or DEFAULT_SAH_BUILD_STRATEGY.maxObjectCount
		local binCount = strategy.binCount
			or DEFAULT_SAH_BUILD_STRATEGY.binCount

		if node:getDepth() >= maxDepth then
			return
		end

		local objectIndex, objectCount = node:getIndexCount()
		if objectCount <= minObjectCount then
			return nil, nil
		end

		local splitAxis, splitBinIndex, splitCost =
			self:_findBestSplitPlane(strategy, node)
		local inverseScale, minSpan, maxSpan = 1, 0, 0
		do
			local nodeMin, nodeMax = node:getBounds()
			local nodeCost = AABB.calculateSurfaceArea(nodeMin, nodeMax)
				* objectCount

			if objectCount <= maxObjectCount and splitCost >= nodeCost then
				return nil, nil
			end

			minSpan, maxSpan = node:getCenterBoundsAxis(splitAxis)
			inverseScale = binCount / (maxSpan - minSpan)
		end

		local i, j = objectIndex, objectIndex + objectCount - 1
		while i <= j do
			local objectCenter = self:getObjectCenter(self.objectIndices[i])
			local objectCenterAxis = objectCenter:getAxis(splitAxis)

			local binIndex = Common.clamp(
				math.floor((objectCenterAxis - minSpan) * inverseScale) + 1,
				1,
				binCount
			)

			if binIndex < splitBinIndex then
				i = i + 1
			else
				self.objectIndices[i], self.objectIndices[j] =
					self.objectIndices[j], self.objectIndices[i]
				j = j - 1
			end
		end

		local leftCount = i - objectIndex
		local leftIndex = objectIndex
		if leftCount == 0 or leftCount == objectCount then
			return nil, nil
		end

		local rightCount = objectCount - leftCount
		local rightIndex = i

		if rightCount > leftCount then
			leftCount, rightCount = rightCount, leftCount
			leftIndex, rightIndex = rightIndex, leftIndex
		end

		local leftChildIndex = self.nodeCount + 1
		local rightChildIndex = leftChildIndex + 1

		local leftNode = self:newNode(leftChildIndex)
		leftNode:setDepth(node:getDepth() + 1)
		leftNode:setAxis(splitAxis)
		leftNode:setIndexCount(leftIndex, leftCount)
		self:_refreshNodeFromObjects(leftNode)

		local rightNode = self:newNode(rightChildIndex)
		rightNode:setDepth(node:getDepth() + 1)
		rightNode:setAxis(splitAxis)
		rightNode:setIndexCount(rightIndex, rightCount)
		self:_refreshNodeFromObjects(rightNode)

		node:setChildren(leftNode, rightNode)

		return leftNode, rightNode
	end

	local _queue = {}

	--- @param strategy RatScratch.Graphics.BVH.SAHBuildStrategy
	--- @param rootNode RatScratch.Graphics.BVHNode
	function BVH:_rebuildSAH(strategy, rootNode)
		local queue = _queue

		rootNode:setChildren()
		rootNode:setIndexCount(1, self.objectCount)
		self:_refreshNodeFromObjects(rootNode)

		table.insert(queue, rootNode)
		local head, tail = 1, 1

		while head <= tail do
			local node = queue[head]
			head = head + 1

			local left, right = self:_subdivide(strategy, node)
			if left and right then
				table.insert(queue, left)
				table.insert(queue, right)

				tail = tail + 2
			end
		end

		Table.clear(queue)
	end
end

--- @param strategy RatScratch.Graphics.BVH.BuildStrategy
function BVH:rebuild(strategy)
	if strategy.strategy == "sah" then
		self.nodeCount = 0
		self:_rebuildSAH(strategy, self:newNode(1))
	elseif strategy.strategy == "stackless" then
		assert(false, "stackless strategy not-yet-implemented")
	end

	self:flush()
end

do
	--- @type RatScratch.Graphics.BVHNode[]
	local _queue = {}

	--- @param origin RatScratch.Math.Vector3
	--- @param direction RatScratch.Math.Vector3
	--- @return boolean, number, integer
	function BVH:raycast(origin, direction)
		if self.nodeCount == 0 then
			return false, 0, 0
		end

		local queue = _queue

		table.insert(queue, self.nodes[1])
		local head = 1
		local tail = 1

		local success, t, objectIndex = false, nil, 0
		while head <= tail do
			local node = queue[head]
			head = head + 1

			local nodeMin, nodeMax = node:getBounds()
			local nodeHitSuccess, nodeT =
				AABB.raycast(nodeMin, nodeMax, origin, direction)
			if nodeHitSuccess and nodeT < (t or math.huge) then
				if node:getIsLeaf() then
					local index, count = node:getIndexCount()
					local startIndex, stopIndex = index, index + count - 1
					for i = startIndex, stopIndex do
						local currentObjectIndex = self.objectIndices[i]
						local objectHitSuccess, objectT = self:raycastObject(
							currentObjectIndex,
							origin,
							direction
						)

						if objectHitSuccess and objectT < (t or math.huge) then
							success = true
							t = objectT
							objectIndex = currentObjectIndex
						end
					end
				else
					table.insert(queue, node:getLeftNode())
					table.insert(queue, node:getRightNode())

					tail = tail + 2
				end
			end
		end

		Table.clear(queue)

		return success, t or 0, objectIndex
	end
end

return BVH
