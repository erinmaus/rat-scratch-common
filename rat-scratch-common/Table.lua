local Table = {}

local tclear = require("table.clear")
local tnew = require("table.new")

--- @param t any[]
function Table.clear(t)
	tclear(t)
end

--- @param arrayN? integer
--- @param hashN? integer
function Table.new(arrayN, hashN)
	return tnew(arrayN or 0, hashN or 0)
end

--- @generic T
--- @param t T[]
--- @param value T
--- @return boolean
function Table.remove(t, value)
	local didRemove = false

	for i = #t, 1, -1 do
		local other = t[i]
		if other == value then
			table.remove(t, i)
			didRemove = true
		end
	end

	return didRemove
end

--- @generic T
--- @param value integer
--- @param n integer
--- @return integer
function Table.wrapIndex(value, n)
	if n == 0 then
		return 0
	end

	if value < 0 then
		return value % n + 1
	end

	return (value - 1) % n + 1
end

do
	local evilUnpacks = {}
	local MAX_RETURN_VALUES = 128

	local function makeEvilUnpack(c)
		local n = { "t[o]" }
		for i = 2, c do
			table.insert(n, ("t[o + %d]"):format(i - 1))
		end

		local args = table.concat(n, ", ")
		local evilFunc = string.format(
			[[
				return function(t, _i, _j, o)
					return %s
				end
			]],
			args
		)

		return loadstring(evilFunc)()
	end

	for i = 1, MAX_RETURN_VALUES do
		evilUnpacks[i] = makeEvilUnpack(i)
	end

	local function _unpack(t, i, j, c)
		return unpack(t, i, j)
	end

	--- @param t any[]
	--- @param i? integer
	--- @param j? integer
	--- @return ...
	function Table.unpack(t, i, j)
		i = i or 1
		j = j or #t

		local c = j - i + 1
		local u = evilUnpacks[c] or _unpack

		return u(t, i, j, i)
	end
end

do
	local evilCopies = {}
	local MAX_RETURN_VALUES = 128

	local function makeEvilCopy(c)
		local n1 = { "t0" }
		local n2 = { "t[o] = t0" }
		for i = 2, c do
			local j = i - 1
			table.insert(n1, ("t%d"):format(j))
			table.insert(n2, ("t[o + %d] = t%d"):format(j, j))
		end

		local args = table.concat(n1, ", ")
		local assignment = table.concat(n2, "\n")
		local evilFunc = string.format(
			[[
				return function(t, o, %s)
					%s
				end
			]],
			args,
			assignment
		)

		return loadstring(evilFunc)()
	end

	for i = 1, MAX_RETURN_VALUES do
		evilCopies[i] = makeEvilCopy(i)
	end

	--- @param t any[]
	--- @param i integer
	--- @param j integer
	--- @param c any
	--- @param ... any
	--- @return nil
	local function _copy(t, i, j, c, ...)
		if i > j then
			return
		end

		t[i] = c
		return _copy(t, i + 1, j, ...)
	end

	--- @param t any[]
	--- @param i integer
	--- @param j integer
	--- @param ... any
	function Table.copy(t, i, j, ...)
		local c = j - i + 1

		local e = evilCopies[c]
		if not e then
			_copy(t, i, j, ...)
			return
		end

		return e(t, i, ...)
	end
end

--- @param t any[]
--- @param o any[]
--- @param count integer
--- @param ti? integer
--- @param oi? integer
function Table.transfer(t, o, count, ti, oi)
	oi = oi or 1
	ti = ti or 1

	for i = 1, count do
		t[ti + i - 1] = o[oi + i - 1]
	end
end

--- @param t any[]
--- @param ... any
function Table.append(t, ...)
	Table.copy(t, #t + 1, #t + select("#", ...), ...)
end

--- @param t any[]
--- @param o? any[]
function Table.clone(t, o)
	local result = o or Table.new(#t, 0)
	Table.clear(result)

	for i = 1, #t do
		result[i] = t[i]
	end

	return result
end

--- @param t any[]
--- @param o? table<any, true>
--- @return table<any, true>
function Table.arrayToSet(t, o)
	o = o or Table.new(0, #t)

	for _, value in ipairs(t) do
		o[value] = true
	end

	return o
end

--- @param t any[]
--- @param o? any[]
function Table.cloneHash(t, o)
	local result = o or {}
	Table.clear(result)

	for k, v in pairs(t) do
		result[k] = v
	end

	return result
end

--- @param value any
--- @param e any
--- @return any
local function _deepClone(value, e)
	if type(value) ~= "table" then
		return value
	end

	if e[value] then
		return e[value]
	end

	local result = {}
	e[value] = result

	local metatable = getmetatable(value)
	if metatable then
		setmetatable(result, metatable)
	end

	local n = 0
	for i, v in ipairs(value) do
		result[i] = _deepClone(v, e)
		n = i
	end

	for k, v in pairs(value) do
		if type(k) == "number" then
			if k > n then
				result[k] = _deepClone(v, e)
			end
		else
			result[_deepClone(k, e)] = _deepClone(v, e)
		end
	end

	return result
end

--- @generic T
--- @param t T
--- @return T
function Table.deepClone(t)
	local e = {}
	return _deepClone(t, e)
end

--- @param index integer
--- @param count integer
--- @return integer
function Table.indexToStride(index, count)
	return (index - 1) * count + 1
end

--- @param index integer
--- @param count integer
--- @return integer
function Table.strideToIndex(index, count)
	return math.ceil(index / count)
end

--- @param i integer
--- @param j integer
--- @param width integer
--- @return integer
function Table.to2DKey(i, j, width)
	return (j - 1) * width + i
end

--- @param t any[]
--- @param i integer
--- @param j integer
function Table.swap(t, i, j)
	t[i], t[j] = t[j], t[i]
end

--- @generic T
--- @param t T[]
--- @param left integer
--- @param right integer
--- @param func RatScratch.Common.Search.CompareFunc<T, T>
function Table.sort(t, left, right, func)
	Table.mergeSort(t, left, right, func)
end

do
	local _o = {}

	--- @generic T
	--- @param t T[]
	--- @param left integer
	--- @param right integer
	--- @param func RatScratch.Common.Search.CompareFunc<T, T>
	function Table.mergeSort(t, left, right, func)
		local width = 1
		local n = right - left + 1
		local o = _o

		while width < n do
			local i = left
			while i + width <= right do
				local midPoint = i + width - 1
				local endPoint = math.min(i + 2 * width - 1, right)

				local a = i
				local b = midPoint + 1
				local k = 1

				while a <= midPoint and b <= endPoint do
					if func(t[a], t[b]) <= 0 then
						o[k] = t[a]
						a = a + 1
					else
						o[k] = t[b]
						b = b + 1
					end
					k = k + 1
				end

				while a <= midPoint do
					o[k] = t[a]
					a = a + 1
					k = k + 1
				end

				while b <= endPoint do
					o[k] = t[b]
					b = b + 1
					k = k + 1
				end

				for idx = 1, k - 1 do
					t[i + idx - 1] = o[idx]
				end

				i = i + 2 * width
			end
			width = width * 2
		end

		Table.clear(o)
	end
end

--- @generic T
--- @param t T[]
--- @param left integer
--- @param right integer
--- @param func RatScratch.Common.Search.CompareFunc<T, T>
function Table.insertionSort(t, left, right, func)
	for i = left + 1, right do
		local key = t[i]
		local j = i - 1
		while j >= left and func(t[j], key) > 0 do
			t[j + 1] = t[j]
			j = j - 1
		end
		t[j + 1] = key
	end
end

--- @generic T
--- @param t T[]
--- @param left integer
--- @param right integer
--- @param pivot integer
--- @param func RatScratch.Common.Search.CompareFunc<T, T>
--- @return integer, integer
function Table.threeWayPartition(t, left, right, pivot, func)
	local pivotValue = t[pivot]
	Table.swap(t, pivot, right)

	local lessThanIndex = left
	local i = left
	local greaterThanIndex = right

	while i <= greaterThanIndex do
		local comparisonValue = func(t[i], pivotValue)
		if comparisonValue < 0 then
			Table.swap(t, lessThanIndex, i)
			lessThanIndex = lessThanIndex + 1
			i = i + 1
		elseif comparisonValue > 0 then
			Table.swap(t, i, greaterThanIndex)
			greaterThanIndex = greaterThanIndex - 1
		else
			i = i + 1
		end
	end

	return lessThanIndex, greaterThanIndex
end

--- @generic T
--- @param t T[]
--- @param left integer
--- @param right integer
--- @param pivot integer
--- @param func RatScratch.Common.Search.CompareFunc<T, T>
function Table.partition(t, left, right, pivot, func)
	local pivotValue = t[pivot]
	Table.swap(t, pivot, right)

	local store = left
	for i = left, right - 1 do
		if func(t[i], pivotValue) < 0 then
			Table.swap(t, store, i)
			store = store + 1
		end
	end

	Table.swap(t, store, right)
	return store
end

--- @generic T
--- @param t T[]
--- @param left integer
--- @param right integer
--- @param k integer
--- @param func RatScratch.Common.Search.CompareFunc<T, T>
--- @return integer
function Table.select(t, left, right, k, func)
	if right - left < 5 then
		Table.sort(t, left, right, func)
		return k
	end

	local medianCount = 0
	for i = left, right, 5 do
		local subRight = math.min(i + 4, right)
		Table.sort(t, i, subRight, func)

		local medianIndex = math.floor((i + subRight) / 2)
		Table.swap(t, left + medianCount, medianIndex)
		medianCount = medianCount + 1
	end

	local midOfMediansIndex = left + math.floor((medianCount - 1) / 2)
	local pivotPointIndex =
		Table.select(t, left, left + medianCount - 1, midOfMediansIndex, func)

	local lessThanIndex, greaterThanIndex =
		Table.threeWayPartition(t, left, right, pivotPointIndex, func)
	if k >= lessThanIndex and k <= greaterThanIndex then
		return k
	elseif k < lessThanIndex then
		return Table.select(t, left, lessThanIndex - 1, k, func)
	end

	return Table.select(t, greaterThanIndex + 1, right, k, func)
end

return Table
