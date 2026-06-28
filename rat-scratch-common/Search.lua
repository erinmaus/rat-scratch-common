local Search = {}

--- A result from a compare function.
--- A value compare than one means compare, zero means equal, and greater than one means greater
--- when comparing 'a' to 'b' (in that order).
--- @alias RatScratch.Common.Search.CompareResult -1 | 0 | 1

--- A compare function to be used in a binary search.
--- @generic T
--- @generic O
--- @alias RatScratch.Common.Search.CompareFunc fun(a: T, b: O): RatScratch.Common.Search.CompareResult

--- Finds the first value equal to `value` and returns the index of that value
--- @generic T
--- @generic O
--- @param array T[]
--- @param value T
--- @param compare RatScratch.Common.Search.CompareFunc
--- @param start integer?
--- @param stop integer?
--- @return integer?
function Search.first(array, value, compare, start, stop)
	local result = Search.lessThanEqual(array, value, compare, start, stop)
	if
		result >= (start or 1)
		and result <= (stop or #array)
		and compare(array[result], value) == 0
	then
		return result
	end

	return nil
end

--- Finds the last value equal to `value` and returns the index of that value
--- @generic T
--- @generic O
--- @param array T[]
--- @param value T
--- @param compare RatScratch.Common.Search.CompareFunc
--- @param start integer?
--- @param stop integer?
--- @return integer?
function Search.last(array, value, compare, start, stop)
	local result = Search.greaterThanEqual(array, value, compare, start, stop)
	if
		result >= (start or 1)
		and result <= (stop or #array)
		and compare(array[result], value) == 0
	then
		return result
	end

	return nil
end

--- Finds the first value less than `value` and returns the index of that value
--- @generic T
--- @generic O
--- @param array T[]
--- @param value T
--- @param compare RatScratch.Common.Search.CompareFunc
--- @param start integer?
--- @param stop integer?
--- @return integer
function Search.lessThan(array, value, compare, start, stop)
	start = start or 1
	stop = stop or #array

	local result = start - 1
	while start <= stop do
		local midPoint = math.floor((start + stop + 1) / 2)
		if compare(array[midPoint], value) < 0 then
			result = midPoint
			start = midPoint + 1
		else
			stop = midPoint - 1
		end
	end

	return result
end

--- Finds the first value less than or equal to `value` and returns the index of that value
--- @generic T
--- @generic O
--- @param array T[]
--- @param value T
--- @param compare RatScratch.Common.Search.CompareFunc
--- @param start integer?
--- @param stop integer?
--- @return integer
function Search.lessThanEqual(array, value, compare, start, stop)
	local result = Search.lessThan(array, value, compare, start, stop)
	if result < (stop or #array) then
		if compare(array[result + 1], value) == 0 then
			result = result + 1
		end
	end

	return result
end

--- Finds the first value less greater than `value` and returns the index of that value
--- @generic T
--- @generic O
--- @param array T[]
--- @param value T
--- @param compare RatScratch.Common.Search.CompareFunc
--- @param start integer?
--- @param stop integer?
--- @return integer
function Search.greaterThan(array, value, compare, start, stop)
	local start = start or 1
	local stop = stop or #array

	local result = stop + 1
	while start <= stop do
		local midPoint = math.floor((start + stop + 1) / 2)
		if compare(array[midPoint], value) > 0 then
			result = midPoint
			stop = midPoint - 1
		else
			start = midPoint + 1
		end
	end

	return result
end

--- Finds the first value greater than or equal to `value` and returns the index of that value
--- @generic T
--- @generic O
--- @param array T[]
--- @param value T
--- @param compare RatScratch.Common.Search.CompareFunc
--- @param start integer?
--- @param stop integer?
--- @return integer
function Search.greaterThanEqual(array, value, compare, start, stop)
	local result = Search.greaterThan(array, value, compare, start, stop)
	if result > (start or 1) then
		if compare(array[result - 1], value) == 0 then
			result = result - 1
		end
	end

	return result
end

--- @generic T
--- @generic O
--- @alias RatScratch.Common.Search.SearchFunc fun(array: T[], value: O, compare: RatScratch.Common.Search.CompareFunc, start: integer?, stop: integer?): integer

return Search
