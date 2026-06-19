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

--- comment
--- @param t any[]
--- @param i integer
--- @param j integer
--- @param c any
--- @param ... any
--- @return nil
local function _copy(t, i, j, c, ...)
	if i > j or c == nil then
		return nil
	end

	t[i] = c
	return _copy(t, i + 1, j, ...)
end

--- @param t any[]
--- @param i integer
--- @param j integer
--- @param ... any
function Table.copy(t, i, j, ...)
	_copy(t, i, j, ...)
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
