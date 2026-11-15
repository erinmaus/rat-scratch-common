local Object = require("rat-scratch-common").Object
local FlatTable = require("rat-scratch-common").FlatTable
local assert = require("rat-scratch-common").Debug.assert
local Vector3 = require("rat-scratch-math").Vector3
local AABB = require("rat-scratch-math.Geometry3D.AABB")
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")
local Common = require("rat-scratch-math.Common")
local Mesh = require("rat-scratch-graphics.Graphics3D.Mesh")
local Table = require("rat-scratch-common.Table")
local ffi = require("ffi")

--- @class RatScratch.Graphics.AccelerationStructure : RatScratch.Common.BaseObject
--- @field private nodes RatScratch.Common.FlatTable<number>
--- @field private indices integer[]
--- @overload fun(count: integer): RatScratch.Graphics.AccelerationStructure
local AccelerationStructure = Object()

AccelerationStructure.NODE_FORMAT = {
	{ location = 0, name = "minX", format = "float" },
	{ location = 1, name = "minY", format = "float" },
	{ location = 2, name = "minZ", format = "float" },
	{ location = 3, name = "maxX", format = "float" },
	{ location = 4, name = "maxY", format = "float" },
	{ location = 5, name = "maxZ", format = "float" },
	{ location = 6, name = "offset", format = "uint32" },
	{ location = 7, name = "count", format = "uint32" },
}

AccelerationStructure.NODE_FORMAT_INSTANCE =
	BufferFormat.get(AccelerationStructure.NODE_FORMAT)

--- @param count integer
function AccelerationStructure:new(count)
	self.nodes = FlatTable.wrap(
		count * 2 - 1,
		AccelerationStructure.NODE_FORMAT_INSTANCE:getComponentCount()
	)
	self.indices = Table.new(count)
end

--- @param index integer
--- @param min? RatScratch.Math.Vector3
--- @param max? RatScratch.Math.Vector3
--- @return RatScratch.Math.Vector3, RatScratch.Math.Vector3
function AccelerationStructure:extractNodeBounds(index, min, max)
	local ix, iy, iz, jx, jy, jz = self.nodes:get(index)

	min = (min or Vector3()):from(ix, iy, iz)
	max = (max or Vector3()):from(jx, jy, jz)

	return min, max
end

--- @param index integer
--- @return boolean
function AccelerationStructure:extractNodeIsLeaf(index)
	local _, _, _, _, _, _, _, count = self.nodes:get(index)

	return bit.rshift(count, 31) == 1
end

--- @param index integer
--- @return integer, integer
function AccelerationStructure:extractNodeIndexCount(index)
	local _, _, _, _, _, _, i, count = self.nodes:get(index)

	return i, bit.band(count, 0x0FFFFFFF)
end

function AccelerationStructure:getNodes()
	return self.nodes:getArray()
end

function AccelerationStructure:getNodeCount()
	return self.nodes:getLength()
end

function AccelerationStructure:getIndices()
	return self.indices
end

function AccelerationStructure:getIndexCount()
	return #self.indices
end

--- @param nodeData? love.ByteData
--- @param indexData? love.ByteData
--- @return love.ByteData, love.ByteData
function AccelerationStructure:toData(nodeData, indexData)
	local expectedNodeSize = (self:getNodeCount() + 1)
		* AccelerationStructure.NODE_FORMAT_INSTANCE:getStride()
	nodeData = nodeData or love.data.newByteData(expectedNodeSize)

	local expectedIndexSize = self:getIndexCount() * ffi.sizeof("uint32_t")
	indexData = indexData or love.data.newByteData(expectedIndexSize)

	assert(
		nodeData:getSize() >= expectedNodeSize,
		"expected a minimum of %d bytes for node data, got %d bytes total",
		expectedNodeSize,
		nodeData:getSize()
	)

	assert(
		indexData:getSize() >= expectedIndexSize,
		"expected a minimum of %d bytes for index data, got %d bytes total",
		expectedNodeSize,
		indexData:getSize()
	)

	BufferFormat.copyFromFlatTableToByteData(
		AccelerationStructure.NODE_FORMAT_INSTANCE,
		1,
		AccelerationStructure.NODE_FORMAT_INSTANCE:getStride(),
		self:getNodeCount(),
		self.nodes:getArray(),
		nodeData
	)

	BufferFormat.copyFromFlatTableToByteData(
		Mesh.INDEX_FORMAT,
		1,
		0,
		self:getIndexCount(),
		self.indices,
		indexData
	)

	return nodeData, indexData
end

--- @param as? RatScratch.Graphics.AccelerationStructure
--- @param bvh RatScratch.Graphics.BVH
function AccelerationStructure.fromBVH(as, bvh)
	if not as then
		as = AccelerationStructure(math.max(bvh:getObjectCount(), 1))
	else
		as.nodes:resize(math.max(bvh:getNodeCount(), 1))
		Table.clear(as.indices)
	end

	for nodeIndex = 1, as:getNodeCount() do
		local node = bvh:getNode(nodeIndex)

		local minBounds, maxBounds = node:getBounds()
		local index, count = node:getIndexCount()
		local isLeaf = node:getIsLeaf()

		local ix, iy, iz = minBounds:get()
		local jx, jy, jz = maxBounds:get()
		local i = index
		local c = bit.bor(isLeaf and 0x80000000 or 0x0, count)

		as.nodes:set(nodeIndex, ix, iy, iz, jx, jy, jz, i - 1, c)
	end

	for i = 1, bvh:getObjectCount() do
		as.indices[i] = bvh:getObjectIndex(i) - 1
	end

	return as
end

--- @param as? RatScratch.Graphics.AccelerationStructure
--- @param nodeData love.Data
--- @param indexData love.Data
function AccelerationStructure.fromData(as, nodeData, indexData)
	local count = math.floor(indexData:getSize() / ffi.sizeof("uint32_t"))

	if not as then
		as = AccelerationStructure(count)
	else
		as.nodes:resize(2 * count)
		Table.clear(as.indices)
	end

	BufferFormat.copyFromByteDataToFlatTable(
		AccelerationStructure.NODE_FORMAT_INSTANCE,
		AccelerationStructure.NODE_FORMAT_INSTANCE:getStride(),
		1,
		2 * count - 1,
		nodeData,
		as.nodes:getArray()
	)

	BufferFormat.copyFromByteDataToFlatTable(
		Mesh.INDEX_FORMAT,
		0,
		1,
		count,
		indexData,
		as.indices
	)

	return as
end

do
	local _minLeft, _maxLeft = Vector3(), Vector3()
	local _minRight, _maxRight = Vector3(), Vector3()

	--- @alias RatScratch.Graphics.RatScratch.Graphics.AccelerationStructure.HitCallback
	--- | fun(index: integer, origin: RatScratch.Math.Vector3, direction: RatScratch.Math.Vector3): boolean, number
	--- | fun<T>(T: self, index: integer, origin: RatScratch.Math.Vector3, direction: RatScratch.Math.Vector3): boolean, number

	--- @generic T
	--- @param origin RatScratch.Math.Vector3
	--- @param direction RatScratch.Math.Vector3
	--- @param hitFunc RatScratch.Graphics.RatScratch.Graphics.AccelerationStructure.HitCallback
	--- @param otherSelf? T
	--- @return boolean, number, integer
	function AccelerationStructure:raycast(
		origin,
		direction,
		hitFunc,
		otherSelf
	)
		local hitSuccess, hitT, hitIndex = false, math.huge, 0
		local minLeftBounds, maxLeftBounds = _minLeft, _maxLeft
		local minRightBounds, maxRightBounds = _minRight, _maxRight

		local nodeIndex = 1
		local trail = bit.lshift(1, Common.countMSB(nodeIndex) - 1)
		repeat
			local p = Common.countLSB(trail + 1) - 1

			local isLeaf = self:extractNodeIsLeaf(nodeIndex)
			if isLeaf then
				local index = self:extractNodeIndexCount(nodeIndex)
				local objectIndex = self.indices[index + 1]
				local success, t
				if otherSelf then
					success, t =
						hitFunc(otherSelf, objectIndex + 1, origin, direction)
				else
					success, t = hitFunc(objectIndex + 1, origin, direction)
				end

				if success and t < hitT then
					hitT = t
					hitIndex = objectIndex + 1
					hitSuccess = true
				end

				trail = bit.rshift(trail, p) + 1
				nodeIndex = bit.bxor(bit.rshift(nodeIndex, p), 1)
			else
				nodeIndex = bit.lshift(nodeIndex, 1)

				self:extractNodeBounds(nodeIndex, minLeftBounds, maxLeftBounds)
				self:extractNodeBounds(
					nodeIndex + 1,
					minRightBounds,
					maxRightBounds
				)

				local leftHitSuccess, leftHitT = AABB.raycast(
					minLeftBounds,
					maxLeftBounds,
					origin,
					direction
				)
				local rightHitSuccess, rightHitT = AABB.raycast(
					minRightBounds,
					maxRightBounds,
					origin,
					direction
				)

				local hits = 0
				do
					if leftHitSuccess and leftHitT < hitT then
						hits = hits + 1
					end

					if rightHitSuccess and rightHitT < hitT then
						hits = hits + 1

						if hits == 1 or rightHitT < leftHitT then
							nodeIndex = nodeIndex + 1
						end
					end
				end

				if hits > 0 then
					trail = bit.bor(bit.lshift(trail, 1), bit.band(hits, 1))
				else
					trail = bit.rshift(trail, p) + 1
					nodeIndex = bit.bxor(bit.rshift(nodeIndex, p + 1), 1)
				end
			end
		until trail <= 1

		return hitSuccess, hitT, hitIndex
	end
end

return AccelerationStructure
