local Object = require("rat-scratch-common.Object")
local Table = require("rat-scratch-common.Table")

--- @generic T : RatScratch.Common.BaseObject
--- @class RatScratch.Common.ObjectPool<T> : RatScratch.Common.BaseObject
--- @overload fun<T>(objectType: T | unknown): RatScratch.Common.ObjectPool<T>
--- @field private freeList T[]
--- @field private usedList T[]
local ObjectPool = Object()

--- @generic T : RatScratch.Common.BaseObject
--- @param self RatScratch.Common.ObjectPool<T>
--- @param objectType T | unknown
function ObjectPool:new(objectType)
	self.objectType = objectType
	self.freeList = {}
	self.usedList = {}
end

--- @generic T
--- @param self RatScratch.Common.ObjectPool<T>
--- @return T
function ObjectPool:pop(...)
	local result = table.remove(self.freeList)
	if result == nil then
		result = self:allocate(...)
		table.insert(self.usedList, result)
	else
		self:clear(result)
		self:new(...)
	end

	return result
end

--- @generic T
--- @param self RatScratch.Common.ObjectPool<T>
function ObjectPool:free(value)
	table.insert(self.freeList, self:clear(value))
end

--- @generic T
--- @param self RatScratch.Common.ObjectPool<T>
--- @return T
function ObjectPool:allocate(...)
	return self.objectType(...)
end

--- @generic T
--- @param self RatScratch.Common.ObjectPool<T>
--- @param value T
--- @return T
function ObjectPool:clear(value)
	Table.clear(value)
	return value
end

--- @generic T
--- @param self RatScratch.Common.ObjectPool<T>
--- @return RatScratch.Common.ObjectPool<T>
function ObjectPool:reset()
	self.freeList, self.usedList = self.usedList, self.freeList
	return self
end

return ObjectPool
