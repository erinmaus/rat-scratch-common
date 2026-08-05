local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Search = require("rat-scratch-common").Search
local Table = require("rat-scratch-common").Table
local TablePool = require("rat-scratch-common").TablePool
local Common = require("rat-scratch-math").Common
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")
local EventSource = require("rat-scratch-common.EventSource")
local Mesh = require("rat-scratch-graphics.Graphics3D.Mesh")
local PipelineBufferContextEvent =
	require("rat-scratch-graphics.Pipeline3D.PipelineBufferContextEvent")

--- @generic T
--- @class RatScratch.Graphics.Pipeline3D.PipelineBufferContext<T> : RatScratch.Common.BaseObject
--- @overload fun(count: integer): RatScratch.Graphics.Pipeline3D.PipelineBufferContext<T>
--- @field private instances any[][]
--- @field private indexCountByInstance table<T, number[]>
--- @field private tablePool RatScratch.Common.TablePool<table>
--- @field private freeInstancesByIndex number[][]
--- @field private freeInstancesByCount number[][]
--- @field private reservedCount integer
--- @field private count integer
--- @field private maxInstanceIndex integer
--- @field private isCompacted boolean
local PipelineBufferContext = Object()

--- @param count integer
function PipelineBufferContext:new(count)
	count = Common.nextPowerOfTwo(count)

	self.eventSource = EventSource(self)
	self.instances = {}
	self.indexCountByInstance = {}
	self.tablePool = TablePool()
	self.freeInstancesByIndex = {}
	self.freeInstancesByCount = {}
	self.reservedCount = count
	self.minInstanceIndex = 0
	self.maxInstanceIndex = 0
	self.count = 0
	self.isCompacted = true

	local freeInstance = self.tablePool:pop()
	freeInstance[1], freeInstance[2] = 1, count
	table.insert(self.freeInstancesByIndex, freeInstance)
	table.insert(self.freeInstancesByCount, freeInstance)
end

PipelineBufferContext.listen, PipelineBufferContext.silence =
	EventSource.mixin("eventSource")

function PipelineBufferContext:getReservedCount()
	return self.reservedCount
end

function PipelineBufferContext:getCount()
	return self.count
end

--- @private
--- @param instance number[]
--- @param index number
--- @return RatScratch.Common.Search.CompareResult
function PipelineBufferContext._compareInstanceIndex(instance, index)
	local i = unpack(instance)

	return Common.zerosign(i - index)
end

--- @private
function PipelineBufferContext._compareInstanceCount(instance, count)
	local _, c = unpack(instance)

	-- we flip it since this array is sorted in descending order
	return -Common.zerosign(c - count)
end

--- @private
function PipelineBufferContext._lessInstanceCount(a, b)
	return a[2] > b[2]
end

--- @private
--- @param count integer
function PipelineBufferContext:_resize(count)
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

	local previousCount = self.reservedCount
	self.reservedCount = reservedCount

	self.eventSource:process(
		PipelineBufferContextEvent.fromResize(previousCount, reservedCount)
	)
end

function PipelineBufferContext:compact()
	if self.isCompacted then
		return
	end

	local n = 1
	for _, instanceInfo in ipairs(self.instances) do
		local index, count, instance = unpack(instanceInfo)
		instanceInfo[1] = n

		self.eventSource:process(
			PipelineBufferContextEvent.fromCompact(instance, n, index, count)
		)

		n = n + count
	end

	self:_recalculateCount()

	for _, freeInstance in ipairs(self.freeInstancesByIndex) do
		self.tablePool:free(freeInstance)
	end

	Table.clear(self.freeInstancesByCount)
	Table.clear(self.freeInstancesByIndex)

	local freeInstance = self.tablePool:pop()
	freeInstance[1], freeInstance[2] =
		self.maxInstanceIndex + 1, self.reservedCount - self.maxInstanceIndex

	table.insert(self.freeInstancesByCount, freeInstance)
	table.insert(self.freeInstancesByIndex, freeInstance)

	self.isCompacted = true
end

--- @private
--- @param i any
--- @param count any
function PipelineBufferContext:_freeInstance(i, count)
	local j = Search.lessThanEqual(
		self.freeInstancesByIndex,
		i,
		PipelineBufferContext._compareInstanceIndex
	)
	local k = j + 1

	local resultInstance

	local previousInstance = self.freeInstancesByIndex[j]
	if previousInstance then
		local pi, pc = unpack(previousInstance)
		if pi + pc == i then
			previousInstance[2] = pc + count
			resultInstance = previousInstance
		end
	end

	if not resultInstance then
		resultInstance = self.tablePool:pop()
		resultInstance[1], resultInstance[2] = i, count
		table.insert(self.freeInstancesByIndex, j + 1, resultInstance)
		table.insert(self.freeInstancesByCount, resultInstance)
		k = k + 1
	end

	local nextInstance = self.freeInstancesByIndex[k]
	if nextInstance then
		local ni, nc = unpack(nextInstance)
		if i + count == ni then
			nextInstance[2] = 0
			resultInstance[2] = resultInstance[2] + nc
		end
	end

	self:_cleanFreeList()

	return resultInstance
end

--- @private
function PipelineBufferContext:_cleanFreeList()
	table.sort(
		self.freeInstancesByCount,
		PipelineBufferContext._lessInstanceCount
	)

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
				PipelineBufferContext._compareInstanceIndex
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

				nextIndex = nextIndex + 1
			end
		end
	end
end

--- @private
--- @param count integer
function PipelineBufferContext:_popFreeInstance(count)
	local index = Search.lessThanEqual(
		self.freeInstancesByCount,
		count,
		PipelineBufferContext._compareInstanceCount
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

	local result = self.tablePool:pop()
	result[1], result[2] = i, count

	self:_recalculateCount()

	return result
end

--- @private
function PipelineBufferContext:_recalculateCount()
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
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBufferContext<T>
--- @param instance T
--- @return boolean
function PipelineBufferContext:has(instance)
	return self.indexCountByInstance[instance] ~= nil
end

--- @generic T
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBufferContext<T>
--- @param instance T
--- @param count integer
function PipelineBufferContext:registerOrResize(instance, count)
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
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBufferContext<T>
--- @param instance T
--- @param count integer
--- @return integer, integer
function PipelineBufferContext:register(instance, count)
	count = count or 1
	assert(count >= 1, "count must be >= 1; got %d", count)

	assert(
		not self.indexCountByInstance[instance],
		"instance is already registered with pipeline buffer"
	)

	local instanceInfo = self:_popFreeInstance(count)
	instanceInfo[3] = instance

	local instanceIndex = Search.greaterThanEqual(
		self.instances,
		instanceInfo[1],
		self._compareInstanceIndex
	)
	table.insert(self.instances, instanceIndex, instanceInfo)
	self:_recalculateCount()

	self.indexCountByInstance[instance] = instanceInfo

	self.count = self.count + count

	return self:getIndexCount(instance)
end

--- @generic T : RatScratch.Common.BaseObject
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBufferContext<T>
--- @param instance T
--- @param newCount integer
--- @return integer, integer
function PipelineBufferContext:resize(instance, newCount)
	local instanceInfo = self.indexCountByInstance[instance]

	--- @cast instance RatScratch.Common.BaseObject
	assert(instanceInfo, "instance not registered with pipeline buffer")
	assert(newCount >= 1, "count must be >= 1; got %d", newCount)

	local i, count = unpack(instanceInfo)
	if newCount < count then
		self.isCompacted = false
		instanceInfo[2] = newCount
		self:_freeInstance(i + newCount, count - newCount)
		return self:getIndexCount(instance)
	end

	local nextIndex = Search.greaterThanEqual(
		self.freeInstancesByIndex,
		i + count,
		PipelineBufferContext._compareInstanceIndex
	)

	local freeInstance = self.freeInstancesByIndex[nextIndex]
	local j = freeInstance and freeInstance[1]
	local c = freeInstance and freeInstance[2]
	if not freeInstance or j ~= i + count or c < (newCount - count) then
		self:unregister(instance)
		self:register(instance, newCount)
	else
		freeInstance[1], freeInstance[2] = i + newCount, c - (newCount - count)
		instanceInfo[2] = newCount
	end

	self.count = self.count + (newCount - count)
	return self:getIndexCount(instance)
end

--- @generic T : RatScratch.Common.BaseObject
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBufferContext<T>
--- @param instance T
function PipelineBufferContext:unregister(instance)
	local instanceInfo = self.indexCountByInstance[instance]

	--- @cast instance RatScratch.Common.BaseObject
	assert(instanceInfo, "instance not registered with pipeline buffer")

	local i, count = unpack(instanceInfo)
	self:_freeInstance(i, count)

	local index = Search.first(
		self.instances,
		i,
		PipelineBufferContext._compareInstanceIndex
	)
	assert(
		index and self.instances[index] == instanceInfo,
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
--- @param self RatScratch.Graphics.Pipeline3D.PipelineBufferContext<T>
--- @param instance T
--- @return integer, integer
--- @overload fun(): integer, integer
function PipelineBufferContext:getIndexCount(instance)
	if not instance then
		return self.minInstanceIndex,
			self.maxInstanceIndex - self.minInstanceIndex + 1
	end

	local instanceInfo = self.indexCountByInstance[instance]

	--- @cast instance RatScratch.Common.BaseObject
	assert(instanceInfo, "instance not registered with pipeline buffer")

	return instanceInfo[1], instanceInfo[2]
end

return PipelineBufferContext
