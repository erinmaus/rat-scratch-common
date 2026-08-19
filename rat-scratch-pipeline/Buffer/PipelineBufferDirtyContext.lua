local Object = require("rat-scratch-common").Object
local Search = require("rat-scratch-common").Search
local Table = require("rat-scratch-common").Table
local TablePool = require("rat-scratch-common").TablePool
local Common = require("rat-scratch-math").Common

--- @class RatScratch.Pipeline.Buffer.PipelineBufferDirtyContext : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Pipeline.Buffer.PipelineBufferDirtyContext
--- @field private tablePool RatScratch.Common.TablePool
--- @field private dirtyInstances number[][]
local PipelineBufferDirtyContext = Object()

function PipelineBufferDirtyContext:new()
	self.tablePool = TablePool()
	self.dirtyInstances = {}
end

function PipelineBufferDirtyContext:getIsDirty()
	return #self.dirtyInstances >= 1
end

function PipelineBufferDirtyContext:getDirtyRangeCount()
	return #self.dirtyInstances
end

--- @param index integer
--- @return integer, integer
function PipelineBufferDirtyContext:getDirtyRangeIndexCount(index)
	local i, count = unpack(self.dirtyInstances[index])
	return i, count
end

--- @private
--- @param instance number[]
--- @param index number
--- @return RatScratch.Common.Search.CompareResult
function PipelineBufferDirtyContext._compareInstanceIndex(instance, index)
	local i = unpack(instance)

	return Common.zerosign(i - index)
end

--- @param i integer
--- @param count integer
function PipelineBufferDirtyContext:dirty(i, count)
	local j1 = Search.lessThanEqual(
		self.dirtyInstances,
		i,
		PipelineBufferDirtyContext._compareInstanceIndex
	)
	local j2 = Search.lessThanEqual(
		self.dirtyInstances,
		i + count,
		PipelineBufferDirtyContext._compareInstanceIndex
	)

	local leftInstance, rightInstance =
		self.dirtyInstances[j1], self.dirtyInstances[j2]
	if not leftInstance or leftInstance[1] + leftInstance[2] < i then
		j1 = j1 + 1
		leftInstance = self.dirtyInstances[j1]
	end

	local realI, realCount
	if leftInstance and j1 <= j2 then
		realI = math.min(i, leftInstance[1])
		realCount = math.max(i + count, rightInstance[1] + rightInstance[2])
			- realI

		for j = j2, j1, -1 do
			local value = table.remove(self.dirtyInstances, j)
			self.tablePool:free(value)
		end
	else
		realI = i
		realCount = count
	end

	local resultInstance = self.tablePool:pop()
	resultInstance[1], resultInstance[2] = realI, realCount

	local j = Search.lessThan(
		self.dirtyInstances,
		realI,
		PipelineBufferDirtyContext._compareInstanceIndex
	)

	table.insert(self.dirtyInstances, j + 1, resultInstance)
end

function PipelineBufferDirtyContext:clear()
	while #self.dirtyInstances > 0 do
		local instance = table.remove(self.dirtyInstances)
		self.tablePool:free(instance)
	end
end

return PipelineBufferDirtyContext
