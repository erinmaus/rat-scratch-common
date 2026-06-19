--- @class RatScratch.Common.Object
local Object = {}

--- @alias RatScratch.Common.ObjectDebugInfo {
---   lineNumber: integer,
---   filename: string,
---   shortName: string,
---   requireName: string,
--- }

--- @generic T
--- @param value T
--- @return boolean
function Object.isObject(value)
	return Object.getType(value) ~= nil
end

--- @generic T
--- @param value T
--- @return boolean
function Object.isType(value)
	local metatable = getmetatable(value) or false
	return metatable and metatable.__c == Object
end

--- @generic T
--- @param value T
--- @return RatScratch.Common.BaseObject | nil
function Object.getType(value)
	local metatable = getmetatable(value) or false
	local valueType = metatable and metatable.__type or false
	local metatableMetatable = valueType and getmetatable(valueType)

	return metatableMetatable and metatableMetatable.__c == Object and valueType or nil
end

--- @generic A
--- @generic B
--- @param parent A
--- @param child B
--- @return boolean
function Object.isDerived(parent, child)
	local t = child
	while t ~= nil do
		if t == parent then
			return true
		else
			t = getmetatable(t).__parent
		end
	end

	return false
end

--- @param obj RatScratch.Common.BaseObject
--- @return ... any
function Object.ABSTRACT(obj)
	if obj then
		local message = ("method is abstract in class %s"):format(obj:getDebugInfo().shortName)
		error(message)
	else
		error("method is abstract")
	end
end

--- @class RatScratch.Common.BaseObject
--- @field public _METATABLE metatable
--- @field public _PARENT RatScratch.Common.BaseObject | false
--- @field public _DEBUG RatScratch.Common.ObjectDebugInfo
local Common = {}

--- @param ... any
function Common:new(...) end

--- @param otherType RatScratch.Common.BaseObject
function Common:isType(otherType)
	return self:getType() == otherType
end

--- @param otherType RatScratch.Common.BaseObject
function Common:isDerived(otherType)
	return Object.isDerived(Object.getType(self), otherType)
end

--- @return RatScratch.Common.ObjectDebugInfo
function Common:getDebugInfo()
	return self:getType()._DEBUG
end

--- @generic T : RatScratch.Common.BaseObject
--- @param self T
--- @return T
function Common:getType()
	local result = Object.getType(self)

	--- @cast result RatScratch.Common.BaseObject
	return result
end

--- @return ... any
function Common:ABSTRACT()
	return Object.ABSTRACT(self)
end

--- @generic T : RatScratch.Common.BaseObject
--- @param self RatScratch.Common.Object
--- @param parent T
--- @param stack? integer
--- @return T, metatable
local function __call(self, parent, stack)
	local Type = { __index = parent or Common, __parent = parent, __c = Object }
	local Object = setmetatable({}, Type)
	local Metatable = { __index = Object, __type = Object }
	Object._METATABLE = Metatable
	Object._PARENT = parent or false
	Object._DEBUG = {}

	do
		local debug = require("debug")

		local info = debug.getinfo(2 + (stack or 0), "Sl")
		if info then
			local shortObjectName = (info.source:match("^@(.*).lua$") or info.source):gsub("/", ".")
			local lineNumber = info.currentline

			Object._DEBUG.lineNumber = lineNumber
			Object._DEBUG.filename = info.source
			Object._DEBUG.shortName = string.format("%s@%d", shortObjectName, lineNumber)
			Object._DEBUG.requireName = shortObjectName
		end
	end

	if parent then
		setmetatable(Metatable, { __index = parent._METATABLE })
	end

	function Type.__call(_self, ...)
		local result = setmetatable({}, Metatable)

		if Object.new then
			Object.new(result, ...)
		end

		return result
	end

	return Object, Metatable
end

--- @type RatScratch.Common.Object
--- @overload fun<T>(parent?: T, stack?: integer): table
local ObjectProxy = setmetatable({}, { __call = __call, __index = Object })

return ObjectProxy
