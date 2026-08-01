local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Search = require("rat-scratch-common").Search
local Table = require("rat-scratch-common").Table
local TablePool = require("rat-scratch-common").TablePool
local Common = require("rat-scratch-math").Common
local Mesh = require("rat-scratch-graphics.Graphics3D.Mesh")

--- @generic T
--- @class RatScratch.Graphics.Pipeline3D.PipelineBuffer<T> : RatScratch.Common.BaseObject
--- @overload fun(format: RatScratch.Graphics.Graphics3D.MeshFormatAttribute[], flags: table, count?: integer): RatScratch.Graphics.Pipeline3D.PipelineBuffer<T>
--- @field private format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @field private componentCount number
--- @field private flags table
--- @field private instances any[][]
--- @field private indexCountByInstance table<T, number[]>
--- @field private tablePool RatScratch.Common.TablePool<table>
--- @field private freeInstancesByIndex number[][]
--- @field private freeInstancesByCount number[][]
--- @field private reservedCount integer
--- @field private count integer
--- @field private maxInstanceIndex integer
--- @field private bufferData number[][]
--- @field private buffer love.GraphicsBuffer
--- @field private isCompacted boolean
--- @field private dirtyInstances number[][]
local PipelineBuffer = Object()

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @param flags table
--- @param count? integer
function PipelineBuffer:new(format, flags, count)
	count = Common.nextPowerOfTwo(count or 1024)

	self.format = format
	self.componentCount = Mesh.getComponentCount(self.format)
	self.flags = flags
	self.instances = {}
	self.indexCountByInstance = {}
	self.tablePool = TablePool()
	self.freeInstancesByIndex = {}
	self.freeInstancesByCount = {}
	self.reservedCount = count
	self.minInstanceIndex = 0
	self.maxInstanceIndex = 0
	self.count = 0
	self.bufferData = Table.new(count * self.componentCount, 0)
	self.buffer =
		love.graphics.newBuffer(self.format, self.reservedCount, self.flags)
	self.isCompacted = true
	self.dirtyInstances = {}

	local freeInstance = self.tablePool:pop()
	freeInstance[1], freeInstance[2] = 1, count
	table.insert(self.freeInstancesByIndex, freeInstance)
	table.insert(self.freeInstancesByCount, freeInstance)
end

function PipelineBuffer:getBuffer()
	return self.buffer
end

function PipelineBuffer:getIsDirty()
	return #self.dirtyInstances >= 1
end

function PipelineBuffer:getCount()
	return self.count
end

--- @private
function PipelineBuffer:_getIndexCount()
	return self.minInstanceIndex,
		self.maxInstanceIndex - self.minInstanceIndex + 1
end

--- @private
--- @param instance number[]
--- @param index number
--- @return RatScratch.Common.Search.CompareResult
function PipelineBuffer._compareInstanceIndex(instance, index)
	local i = unpack(instance)

	return Common.zerosign(i - index)
end

function PipelineBuffer._compareInstanceCount(instance, count)
	local _, c = unpack(instance)

	-- we flip it since this array is sorted in descending order
	return -Common.zerosign(c - count)
end

function PipelineBuffer._lessInstanceCount(a, b)
	return a[2] > b[2]
end

--- @private
--- @param count integer
function PipelineBuffer:_resize(count)
	local reservedCount = Common.nextPowerOfTwo(count)

	local freeInstance = self.freeInstancesByIndex[#self.freeInstancesByIndex]
	local i = freeInstance and freeInstance[1]

	if i and i > self.maxInstanceIndex then
		freeInstance[2] = freeInstance[2] + (reservedCount - self.reservedCount)
	else
		local newFreeInstance = self.tablePool:pop()
		newFreeInstance[1], newFreeInstance[2] =
			self.maxInstanceIndex + 1, reservedCount - self.reservedCount
		table.insert(self.freeInstancesByIndex, newFreeInstance)
		table.insert(self.freeInstancesByCount, newFreeInstance)
		self:_cleanFreeList()
	end

	self.reservedCount = reservedCount
	self.buffer =
		love.graphics.newBuffer(self.format, self.reservedCount, self.flags)

	self:compact()
end

function PipelineBuffer:compact()
	if self.isCompacted then
		return
	end

	local n = 1

	local newBufferData = Table.new(self.count * self.componentCount, 0)
	for _, instanceInfo in ipairs(self.instances) do
		local index, count = unpack(instanceInfo)

		for i = 1, count do
			local inputOffset = ((index - 1) + (i - 1)) * self.componentCount
			local outputOffset = ((n - 1) + (i - 1)) * self.componentCount
			for j = 1, self.componentCount do
				newBufferData[outputOffset + j] =
					self.bufferData[inputOffset + j]
			end
		end

		instanceInfo[1] = n
		n = n + count
	end

	self.tablePool:free(self.bufferData)
	self.bufferData = newBufferData

	self:_makeEntireBufferDirty()
	self.isCompacted = true
end

--- @private
function PipelineBuffer:_makeEntireBufferDirty()
	for _, dirtyInstance in ipairs(self.dirtyInstances) do
		self.tablePool:free(dirtyInstance)
	end

	Table.clear(self.dirtyInstances)

	if #self.bufferData == 0 then
		return
	end

	local dirtyInstance = self.tablePool:pop()
	dirtyInstance[1], dirtyInstance[2] = 1, self.maxInstanceIndex
	table.insert(self.dirtyInstances, dirtyInstance)
end

--- @private
--- @param instances number[][]
--- @param i integer
--- @param count integer
function PipelineBuffer:_expandOrInsert(instances, i, count)
	local j =
		Search.lessThan(instances, i, PipelineBuffer._compareInstanceIndex)

	local didMergePrevious = false

	local previousInstance = instances[j]
	if previousInstance then
		local k, c = unpack(previousInstance)
		k = k + c

		if k == i then
			previousInstance[2] = previousInstance[2] + count
			didMergePrevious = true
		end
	end

	if not didMergePrevious then
		local instance = self.tablePool:pop()
		instance[1], instance[2] = i, count

		table.insert(instances, j + 1, instance)
		j = j + 1

		previousInstance = instance
	end

	local nextInstance = instances[j + 1]
	if nextInstance then
		local ni, nc = unpack(nextInstance)
		local pi, pc = unpack(previousInstance)

		if pi + pc == ni then
			self.tablePool:free(table.remove(instances, j + 1))
			previousInstance[2] = previousInstance[2] + nc
		end
	end

	return previousInstance
end

--- @private
function PipelineBuffer:_makeDirty(i, count)
	self:_expandOrInsert(self.dirtyInstances, i, count)
end

--- @private
function PipelineBuffer:_cleanFreeList()
	table.sort(self.freeInstancesByCount, PipelineBuffer._lessInstanceCount)

	while
		#self.freeInstancesByCount > 0
		and (
			not next(self.freeInstancesByCount[#self.freeInstancesByCount])
			or self.freeInstancesByCount[#self.freeInstancesByCount][2] <= 0
		)
	do
		local freeInstance = table.remove(self.freeInstancesByCount)
		local i, count = unpack(freeInstance)

		assert(
			count == nil or count == 0,
			"free list at %d has negative count (%d)",
			i,
			count
		)

		if i and count then
			local nextIndex = Search.first(
				self.freeInstancesByIndex,
				i,
				PipelineBuffer._compareInstanceIndex
			)
			while
				self.freeInstancesByIndex[nextIndex]
				and self.freeInstancesByIndex[nextIndex][1] == i
			do
				local nextInstance = self.freeInstancesByIndex[nextIndex]
				if nextInstance == freeInstance then
					table.remove(self.freeInstancesByIndex, nextIndex)
					break
				end
			end
		end
	end
end

--- @private
--- @param count integer
function PipelineBuffer:_popFreeInstance(count)
	local index = Search.lessThanEqual(
		self.freeInstancesByCount,
		count,
		PipelineBuffer._compareInstanceCount
	)
	local freeInstance = self.freeInstancesByCount[index]
	if freeInstance then
		local result = self.tablePool:pop()

		local j, c = unpack(freeInstance)
		result[1], result[2] = j, count
		freeInstance[1], freeInstance[2] = j + count, c - count

		self:_cleanFreeList()

		return result
	end

	self:_resize(self.reservedCount + count)

	local freeInstance = self.freeInstancesByIndex[#self.freeInstancesByIndex]

	local i, c = unpack(freeInstance)
	freeInstance[1], freeInstance[2] = i + count, c - count

	local result = self:_expandOrInsert(self.instances, i, count)
	self:_recalculateCount()

	return result
end

--- @private
function PipelineBuffer:_recalculateCount()
	local firstInstanceInfo = self.instances[1]
	local lastInstanceInfo = self.instances[#self.instances]

	if firstInstanceInfo then
		self.minInstanceIndex = firstInstanceInfo[1]
	else
		self.minInstanceIndex = 0
	end

	if lastInstanceInfo then
		local i, c = unpack(lastInstanceInfo)
		self.maxInstanceIndex = i + c - 1
	else
		self.maxInstanceIndex = 0
	end
end

--- @generic T
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBuffer<T>
--- @param instance T
--- @return boolean
function PipelineBuffer:has(instance)
	return self.indexCountByInstance[instance] ~= nil
end

--- @generic T
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBuffer<T>
--- @param instance T
--- @param count integer
function PipelineBuffer:registerOrResize(instance, count)
	if self:has(instance) then
		local _, currentCount = self:getIndexCount(instance)
		if count ~= currentCount then
			self:resize(instance, count)
		end
	else
		self:register(instance, count)
	end
end

--- @generic T
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBuffer<T>
--- @param instance T
--- @param count integer
function PipelineBuffer:register(instance, count)
	count = count or 1
	assert(count >= 1, "count must be >= 1; got %d", count)

	assert(
		not self.indexCountByInstance[instance],
		"instance is already registered with pipeline buffer"
	)

	local instanceInfo = self:_popFreeInstance(count)
	instanceInfo[3] = instance

	for i = 1, count do
		local j = instanceInfo[1] + i - 1
		local index = (j - 1) * self.componentCount

		Mesh.resetVertex(self.format, self.bufferData, index)
	end

	local instanceIndex = Search.greaterThanEqual(
		self.instances,
		instanceInfo[1],
		self._compareInstanceIndex
	)
	table.insert(self.instances, instanceIndex, instanceInfo)

	self.indexCountByInstance[instance] = instanceInfo

	self.count = self.count + count
end

--- @generic T : RatScratch.Common.BaseObject
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBuffer<T>
--- @param instance T
--- @param newCount integer
function PipelineBuffer:resize(instance, newCount)
	local instanceInfo = self.indexCountByInstance[instance]

	--- @cast instance RatScratch.Common.BaseObject
	assert(instanceInfo, "instance not registered with pipeline buffer")
	assert(newCount >= 1, "count must be >= 1; got %d", newCount)

	local i, count = unpack(instanceInfo)
	if newCount < count then
		self.isCompacted = false

		local instance = self:_expandOrInsert(
			self.freeInstancesByIndex,
			i + newCount,
			count - newCount
		)
		table.insert(self.freeInstancesByCount, instance)
		self:_cleanFreeList()
		return
	end

	local nextIndex = Search.greaterThanEqual(
		self.freeInstancesByIndex,
		i + count,
		PipelineBuffer._compareInstanceIndex
	)

	local freeInstance = self.freeInstancesByIndex[nextIndex]
	local j = freeInstance and freeInstance[1]
	local c = freeInstance and freeInstance[2]
	if not freeInstance or j ~= i + count or c < (newCount - count) then
		self:unregister(instance)
		self:register(instance, count)
	else
		freeInstance[1], freeInstance[2] = i + newCount, c - (newCount - count)
		instanceInfo[2] = newCount

		for k = i + count, i + newCount - 1 do
			local offset = (k - 1) * self.componentCount
			Mesh.resetVertex(self.format, self.bufferData, offset)
		end

		self:_expandOrInsert(self.dirtyInstances, i + count, newCount - count)
	end

	self.count = self.count + (count - newCount)
end

--- @generic T : RatScratch.Common.BaseObject
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBuffer<T>
--- @param instance T
function PipelineBuffer:unregister(instance)
	local instanceInfo = self.indexCountByInstance[instance]

	--- @cast instance RatScratch.Common.BaseObject
	assert(instanceInfo, "instance not registered with pipeline buffer")

	local i, count = unpack(instanceInfo)
	local freeInstance =
		self:_expandOrInsert(self.freeInstancesByIndex, i, count)
	table.insert(self.freeInstancesByCount, freeInstance)
	self:_cleanFreeList()

	local index =
		Search.first(self.instances, i, PipelineBuffer._compareInstanceIndex)
	assert(
		index,
		"instance with index %d (count %d) not found in instance list",
		i,
		count
	)

	self.tablePool:free(table.remove(self.instances, index))
	self.indexCountByInstance[instance] = nil

	self.count = self.count - count
	self.isCompacted = false
end

--- @generic T : RatScratch.Common.BaseObject
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBuffer<T>
--- @param instance T
--- @return integer, integer
--- @overload fun(): integer, integer
function PipelineBuffer:getIndexCount(instance)
	if not instance then
		return self:_getIndexCount()
	end

	local instanceInfo = self.indexCountByInstance[instance]

	--- @cast instance RatScratch.Common.BaseObject
	assert(instanceInfo, "instance not registered with pipeline buffer")

	return instanceInfo[1], instanceInfo[2]
end

--- @generic T : RatScratch.Common.BaseObject
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBuffer<T>
--- @param instance T
--- @param index integer
--- @param ... number
function PipelineBuffer:set(instance, index, ...)
	local instanceInfo = self.indexCountByInstance[instance]

	--- @cast instance RatScratch.Common.BaseObject
	assert(instanceInfo, "instance not registered with pipeline buffer")
	assert(
		select("#", ...) == self.componentCount,
		"expected %d vararg parameters; got %d",
		self.componentCount,
		select("#", ...)
	)

	local i, count = unpack(instanceInfo)
	assert(
		index <= count and index >= 1,
		"index %d out of range; must be >= 1 and <= %d",
		index,
		count
	)

	local elementIndex = i + index - 1
	local componentIndex = (elementIndex - 1) * self.componentCount + 1

	Table.copy(
		self.bufferData,
		componentIndex,
		componentIndex + select("#", ...) - 1,
		...
	)

	self:_makeDirty(elementIndex, 1)
end

function PipelineBuffer:flush()
	for _, dirtyInstance in ipairs(self.dirtyInstances) do
		local i, count = unpack(dirtyInstance)

		if count > 0 then
			self.buffer:setArrayData(self.bufferData, i, i, count)
		end

		self.tablePool:free(dirtyInstance)
	end

	Table.clear(self.dirtyInstances)
end

return PipelineBuffer
