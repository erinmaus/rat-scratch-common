local Table = {}

Table.clear = require("table.clear")
Table.new = require("table.new")

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
--- @param t T[] | number
--- @return integer
function Table.wrapIndex(value, t)
	local n
	if type(t) == "number" then
		n = t
	else
		n = #t
	end

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

return Table
