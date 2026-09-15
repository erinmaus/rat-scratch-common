local assert = require("rat-scratch-common.Debug").assert
local Object = require("rat-scratch-common.Object")
local Table = require("rat-scratch-common.Table")

--- @class RatScratch.Common.Event : RatScratch.Common.BaseObject
--- @overload fun(scope: RatScratch.Common.EventScope): RatScratch.Common.Event
--- @field private scope RatScratch.Common.EventScope
local Event = Object()

--- @type table<RatScratch.Common.Event, RatScratch.Common.Event[]>
Event.POOL = {}

--- @param scope RatScratch.Common.EventScope
function Event:new(scope)
	self.scope = scope
end

--- @generic T : RatScratch.Common.Event
--- @param type T | RatScratch.Common.Event | unknown
--- @param scope RatScratch.Common.EventScope
--- @return T
function Event.get(type, scope, ...)
	local pool = Event.POOL[type]
	if not pool then
		assert(
			Object.isDerived(Event, type),
			"type '%s' is not event",
			type and type._DEBUG and type._DEBUG.shortName or "???"
		)

		pool = {}
		Event.POOL[type] = pool
	end

	local event = table.remove(pool)
	if not event then
		event = type(scope)
	else
		Table.clear(event)
		event:new(scope, ...)
	end

	return event
end

--- @generic T : RatScratch.Common.Event
--- @param event T | RatScratch.Common.Event
function Event.free(event)
	local type = event:getType()

	local pool = Event.POOL[type]
	assert(
		pool ~= nil,
		"event '%s' was not pooled",
		event:getDebugInfo().shortName
	)

	table.insert(pool, event)
end

function Event:getScope()
	return self.scope
end

--- @generic T : RatScratch.Common.Event
--- @param self T | RatScratch.Common.Event
--- @return T
function Event:keep()
	local result = self:getType()(self.scope)
	for key, value in pairs(self) do
		result[key] = value
	end
	return result
end

--- @param scope RatScratch.Common.EventScope
--- @return boolean
function Event:is(scope)
	return self.scope:is(scope)
end

return Event
