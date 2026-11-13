local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local AABB = require("rat-scratch-math").Geometry3D.AABB
local BVH = require("rat-scratch-graphics.BVH")
local Vector3 = require("rat-scratch-math").Vector3

--- @class RatScratch.Graphics.BLASInstanceBVH : RatScratch.Graphics.BVH
--- @field private blasInstances RatScratch.Graphics.BLASInstance[]
--- @overload fun(nodeCount?: integer, objectCount?: integer): RatScratch.Graphics.BLASInstanceBVH
local BLASInstanceBVH = Object(BVH)

--- @param nodeCount? integer
--- @param objectCount? integer
function BLASInstanceBVH:new(nodeCount, objectCount)
	BVH.new(self, nodeCount, objectCount)

	self.blasInstances = Table.new(nodeCount)
	self.blasCenter = setmetatable({}, { __mode = "k" })
end

function BLASInstanceBVH:getObjectBounds(objectIndex)
	local blas = self.blasInstances[objectIndex]
	return blas:getBounds()
end

function BLASInstanceBVH:getBLASInstance(objectIndex)
	return self.blasInstances[objectIndex]
end

--- @param result? RatScratch.Graphics.BLASInstance[]
--- @return RatScratch.Graphics.BLASInstance[]
function BLASInstanceBVH:shuffleBLASInstances(result)
	result = result or {}
	Table.clear(result)

	for i = 1, self:getObjectCount() do
		local index = self:getObjectIndex(i)
		table.insert(result, self.blasInstances[i])
	end

	return result
end

do
	local _size = Vector3()
	local _halfSize = Vector3()

	function BLASInstanceBVH:getObjectCenter(objectIndex)
		local blas = self.blasInstances[objectIndex]
		local min, max = blas:getBounds()

		local size = max:subtract(min, _size)
		local halfSize = size:scale(0.5, _halfSize)
		local center = min:add(halfSize, self.blasCenter[blas] or Vector3())

		self.blasCenter[blas] = center
		return center
	end
end

--- @param objectIndex integer
--- @param origin RatScratch.Math.Vector3
--- @param direction RatScratch.Math.Vector3
--- @return boolean, number
function BLASInstanceBVH:raycastObject(objectIndex, origin, direction)
	local blas = self.blasInstances[objectIndex]
	local minBounds, maxBounds = blas:getBounds()

	return AABB.raycast(minBounds, maxBounds, origin, direction)
end

function BLASInstanceBVH.fromBLASInstances(strategy, blasInstances)
	local count = #blasInstances

	local bvh = BLASInstanceBVH(2 * count - 1, count)
	Table.transfer(bvh.blasInstances, blasInstances, #blasInstances)

	bvh:rebuild(strategy)

	return bvh
end

return BLASInstanceBVH
