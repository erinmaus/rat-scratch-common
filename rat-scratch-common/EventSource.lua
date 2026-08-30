local Event = require("rat-scratch-common.Event")
local Object = require("rat-scratch-common.Object")

--- @alias RatScratch.Common.EventSourceCallback fun(event: RatScratch.Common.Event) | fun<S>(event: RatScratch.Common.Event, eventSource: S) | fun<T, S>(self: T, event: RatScratch.Common.Event) | fun<T, S>(self: T, event: RatScratch.Common.Event, eventSource: S)

--- @alias RatScratch.Common.impl.EventSourceCallbackMeta {
---   callback: RatScratch.Common.EventSourceCallback,
---   id: integer,
---   self: any,
--- }

--- @alias RatScratch.Common.impl.EventSourceCallbacks table<RatScratch.Common.EventScope, RatScratch.Common.impl.EventSourceCallbackMeta[]>

--- @generic T : RatScratch.Common.BaseObject
--- @class RatScratch.Common.EventSource<T> : RatScratch.Common.BaseObject
--- @overload fun<T>(source?: T | any): RatScratch.Common.EventSource<T>
--- @field private listeners RatScratch.Common.impl.EventSourceCallbacks
--- @field private idToCallback table<integer, RatScratch.Common.EventScope>
local EventSource = Object()

--- @generic T : RatScratch.Common.BaseObject
--- @param self RatScratch.Common.EventSource<T>
--- @param source? T | any
function EventSource:new(source)
	self.source = source
	self.currentID = 0
	self.listeners = {}
	self.idToCallback = {}
end

--- @param event RatScratch.Common.Event
function EventSource:process(event)
	local callbacks = self.listeners[event:getScope()]
	if callbacks then
		for i = #callbacks, 1, -1 do
			local callback = callbacks[i]
			if callback.self ~= nil then
				callback.callback(callback.self, event, self.source or self)
			else
				callback.callback(event, self.source or self)
			end
		end
	end

	Event.free(event)
end

--- @generic T
--- @param scope RatScratch.Common.EventScope
--- @param callback RatScratch.Common.EventSourceCallback
--- @param otherSelf? T
--- @return integer
function EventSource:listen(scope, callback, otherSelf)
	self.currentID = self.currentID + 1

	local c = {
		id = self.currentID,
		callback = callback,
		self = otherSelf or nil,
	}

	local callbacks = self.listeners[scope]
	if not callbacks then
		callbacks = {}
		self.listeners[scope] = callbacks
	end

	table.insert(callbacks, 1, c)
	self.idToCallback[self.currentID] = scope

	return self.currentID
end

--- @generic T
--- @overload fun<T>(self: RatScratch.Common.EventSource<T>, scope: RatScratch.Common.EventScope, callback: RatScratch.Common.EventSourceCallback, otherSelf: table)
--- @overload fun<T>(self: RatScratch.Common.EventSource<T>, id: integer)
function EventSource:silence(a, b, c)
	local callbacks
	if a and b and c then
		callbacks = self.listeners[a]
	else
		local scope = self.idToCallback[a]
		assert(scope, "no callback found with ID %d", a)

		callbacks = self.listeners[scope]
		assert(
			callbacks,
			"no callbacks found with event scope %s",
			scope:getName()
		)
	end

	for i = #callbacks, 1, -1 do
		local callback = callbacks[i]
		if
			(a and b and c and b == callback.callback and callback.self == c)
			or callback.id == a
		then
			self.idToCallback[callback.id] = nil
			table.remove(callbacks, i)
			break
		end
	end
end

--- @param field string
function EventSource.mixin(field)
	--- @generic T
	--- @generic O
	--- @param self table
	--- @param event RatScratch.Common.EventScope
	--- @param callback RatScratch.Common.EventSourceCallback
	--- @param otherSelf? O
	--- @return integer id
	local listen = function(self, event, callback, otherSelf)
		--- @type RatScratch.Common.EventSource
		local listener = self[field]

		return listener:listen(event, callback, otherSelf)
	end

	--- @param self table
	--- @overload fun(self: table, scope: RatScratch.Common.EventScope, callback: RatScratch.Common.EventSourceCallback, otherSelf: table)
	--- @overload fun(self: table, id: integer)
	local silence = function(self, a, b, c)
		--- @type RatScratch.Common.EventSource
		local listener = self[field]

		listener:silence(a, b, c)
	end

	return listen, silence
end

return EventSource
