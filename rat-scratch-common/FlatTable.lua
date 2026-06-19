local Table = require("rat-scratch-common.Table")
local Debug = require("rat-scratch-common.Debug")

--- @generic T
--- @class RatScratch.Common.FlatTable<T>
--- @field private array T[]
--- @field private stride integer
--- @field private length integer
local FlatTable = {}
local FlatTableMetatable = { __index = FlatTable }

--- @generic T
--- @param t T[] | number
--- @param stride integer
--- @param value? T
--- @return RatScratch.Common.FlatTable<T>
function FlatTable.wrap(t, stride, value)
	local array, length
	if type(t) == "number" then
		local n = t * stride
		array = Table.new(n, 0)
		length = t

		value = value or 0
		for i = 1, n do
			array[i] = value
		end
	else
		array = Table.clone(t)
		length = Table.strideToIndex(#t, stride)
	end

	return setmetatable({
		stride = stride,
		length = length,
		array = array,
	}, FlatTableMetatable)
end

--- @generic T
--- @param source T[]
--- @param destination RatScratch.Common.FlatTable<T>
--- @return RatScratch.Common.FlatTable<T>
function FlatTable.copy(source, destination)
	Debug.assert(
		#source % destination.stride == 0,
		"source array length (%d) must be multiple of stride (%d)",
		#source,
		destination.stride
	)

	for i = 1, #source do
		destination.array[i] = source[i]
	end

	destination.length = math.ceil(#source / destination.stride)

	return destination
end

--- @generic T
--- @param self? RatScratch.Common.FlatTable<T>
--- @param t T[]
--- @param length? integer
--- @param stride? number
--- @return RatScratch.Common.FlatTable<T>
function FlatTable:intrude(t, length, stride)
	if not self then
		Debug.assert(stride and stride >= 1, "stride must be >= 1; got %d", stride)

		return setmetatable({
			stride = stride,
			length = length,
			array = t,
		}, FlatTableMetatable)
	end

	Debug.assert(not length or (#t % (stride or self.stride) == 0), "table length (%d) must be multiple of stride (%d)", #t, stride or self.stride)

	self.stride = stride or self.stride
	self.length = length or math.ceil(#t / self.stride)
	self.array = t

	return self
end

--- @return integer
function FlatTable:getLength()
	return self.length
end

--- @generic T
--- @param self RatScratch.Common.FlatTable<T>
--- @return T[]
function FlatTable:getArray()
	return self.array
end

--- @generic T
--- @param self RatScratch.Common.FlatTable<T>
--- @param index any
--- @return T ...
function FlatTable:get(index)
	local wrappedIndex = Table.wrapIndex(index, self.length)
	local i = Table.indexToStride(wrappedIndex, self.stride)

	return unpack(self.array, i, i + self.stride - 1)
end

--- @generic T
--- @param self RatScratch.Common.FlatTable<T>
--- @param index integer
--- @param ... T
function FlatTable:set(index, ...)
	local wrappedIndex = Table.wrapIndex(index, self.length)
	local i = Table.indexToStride(wrappedIndex, self.stride)
	local n = math.min(self.stride, select("#", ...))

	Table.copy(self.array, i, i + n - 1, ...)
end

--- @generic T
--- @param self RatScratch.Common.FlatTable<T>
--- @param zero? T
function FlatTable:zero(index, zero)
	zero = zero or 0

	local wrappedIndex = Table.wrapIndex(index, self.length)
	local i = Table.indexToStride(wrappedIndex, self.stride)
	local j = i + self.stride - 1

	for k = i, j do
		self.array[k] = zero
	end
end

return FlatTable
