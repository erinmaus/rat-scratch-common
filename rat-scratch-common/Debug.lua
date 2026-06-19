local Debug = {}

--- @param condition any
--- @param str string
--- @param ... any
function Debug.assert(condition, str, ...)
	if not condition then
		error(string.format("assertion failed: %s", string.format(str, ...)), 2)
	end
end

return Debug
