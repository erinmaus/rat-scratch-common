local Object = require("rat-scratch-common").Object
local Search = require("rat-scratch-common").Search
local TablePool = require("rat-scratch-common.TablePool")

--- @class RatScratch.Resource.ResourceArguments : RatScratch.Common.BaseObject
--- @overload fun(args?: table): RatScratch.Resource.ResourceArguments
local ResourceArguments = Object()

--- @private
--- @type RatScratch.Resource.ResourceArguments[]
ResourceArguments._POOL = {}

local _argumentCompare, _argumentsCompare

--- @param a table
--- @param b table
--- @return integer
_argumentCompare = function(a, b)
	local tk1 = type(a.key)
	local tk2 = type(b.key)

	if tk1 ~= tk2 then
		return tk1 < tk2 and -1 or 1
	end

	local tv1 = type(a.value)
	local tv2 = type(b.value)

	if tv1 ~= tv2 then
		return tv1 < tv2 and -1 or 1
	end

	if a.key ~= b.key then
		if tk1 == "table" then
			local r = _argumentsCompare(a.key, b.key)
			if r ~= 0 then
				return r
			end
		else
			return a.key < b.key and -1 or 1
		end
	end

	if b.value ~= a.value then
		if tv1 == "table" then
			local r = _argumentsCompare(a.value, b.value)
			if r ~= 0 then
				return r
			end
		else
			return a.value < b.value and -1 or 1
		end
	end

	return 0
end

--- @param a table
--- @param b table
--- @return integer
_argumentsCompare = function(a, b)
	if #a ~= #b then
		return #a - #b
	end

	for i = 1, #a do
		local r = _argumentCompare(a[i], b[i])
		if r ~= 0 then
			return r
		end
	end

	return 0
end

--- @param a table
--- @param b table
--- @return boolean
local function _argumentLess(a, b)
	return _argumentCompare(a, b) < 0
end

local function _toArgs(p, args)
	if type(args) ~= "table" then
		return args
	end

	local result = p:pop()
	for k, v in pairs(args) do
		local a = p:pop()
		a.key = _toArgs(p, k)
		a.value = _toArgs(p, v)

		table.insert(result, a)
	end

	table.sort(result, _argumentLess)

	return result
end

function ResourceArguments:new(args)
	self.pool = self.pool or TablePool()

	self.pool:reset()
	self.arguments = _toArgs(self.pool, args)
end

do
	local _cachedArg = ResourceArguments({})

	--- @param args string | table
	function ResourceArguments.get(args)
		if type(args) == "string" then
			return args
		end

		if Object.isDerived(ResourceArguments, Object.getType(args)) then
			return args
		end

		local arg = _cachedArg
		arg:new(args)

		local i = Search.lessThanEqual(
			ResourceArguments._POOL,
			arg,
			ResourceArguments.compare
		)

		local otherArg = i >= 1 and ResourceArguments._POOL[i]
		if otherArg and ResourceArguments.compare(otherArg, arg) == 0 then
			return otherArg
		end

		local result = ResourceArguments(args)
		table.insert(ResourceArguments._POOL, i + 1, result)

		return result
	end
end

--- @param args string | RatScratch.Resource.ResourceArguments
function ResourceArguments.free(args)
	if type(args) ~= "table" then
		return
	end

	local i =
		Search.first(ResourceArguments._POOL, args, ResourceArguments.compare)
	if i then
		table.remove(ResourceArguments._POOL, i)
	end
end

--- @param a RatScratch.Resource.ResourceArguments
--- @param b RatScratch.Resource.ResourceArguments
--- @return integer
function ResourceArguments.compare(a, b)
	return _argumentsCompare(a.arguments, b.arguments)
end

--- @param a RatScratch.Resource.ResourceArguments
--- @param b RatScratch.Resource.ResourceArguments
--- @return boolean
function ResourceArguments.less(a, b)
	return ResourceArguments.compare(a, b) < 0
end

--- @param args RatScratch.Resource.ResourceArguments | string
--- @return table | string
function ResourceArguments.serialize(args)
	if type(args) == "string" then
		return args
	end

	if Object.isDerived(ResourceArguments, Object.getType(args)) then
		return args.arguments
	end

	return args
end

local function _fromArgs(args)
	if type(args) ~= "table" then
		return args
	end

	local result = {}
	for i = 1, #args do
		result[_fromArgs(args[i].key)] = _fromArgs(args[i].value)
	end

	return result
end

--- @param args table | RatScratch.Resource.ResourceArguments
--- @return any
function ResourceArguments.decompress(args)
	if Object.isDerived(ResourceArguments, Object.getType(args)) then
		--- @cast args RatScratch.Resource.ResourceArguments
		return _fromArgs(args.arguments)
	end

	return _fromArgs(args)
end

return ResourceArguments
