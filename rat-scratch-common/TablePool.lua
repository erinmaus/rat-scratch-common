local Object = require("rat-scratch-common.Object")
local Table = require("rat-scratch-common.Table")

--- @generic T
--- @class RatScratch.Common.TablePool<T> : RatScratch.Common.BaseObject
--- @overload fun<T>(): RatScratch.Common.TablePool<T>
--- @field private freeList T[]
--- @field private usedList T[]
local TablePool = Object()

function TablePool:new()
	self.freeList = {}
	self.usedList = {}
end

--- @generic T
--- @param self RatScratch.Common.TablePool<T>
--- @return T
function TablePool:pop()
	local result = table.remove(self.freeList)
	if result == nil then
		result = self:allocate()
		table.insert(self.usedList, result)
	else
		self:clear(result)
	end

	return result
end

--- @generic T
--- @param self RatScratch.Common.TablePool<T>
--- @return T
function TablePool:allocate()
	return {}
end

--- @generic T
--- @param self RatScratch.Common.TablePool<T>
--- @param value T
--- @return T
function TablePool:clear(value)
	Table.clear(value)
	return value
end

function TablePool:reset()
	self.freeList, self.usedList = self.usedList, self.freeList
end

return TablePool
