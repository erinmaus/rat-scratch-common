local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local EventSource = require("rat-scratch-common").EventSource
local ResourceEvent = require("rat-scratch-resource.ResourceEvent")

--- @generic T
--- @class RatScratch.Resource.Resource<T> : RatScratch.Common.BaseObject
--- @overload fun(id: integer): RatScratch.Resource.Resource<T>
--- @field private id integer
--- @field private value T
--- @field private eventSource RatScratch.Common.EventSource
--- @field private gcHandle userdata
local Resource = Object()

--- @param id integer
function Resource:new(id)
	self.id = id
	self.eventSource = EventSource(self)
	self.gcHandle = newproxy(true)

	getmetatable(self.gcHandle).__gc = function()
		self:release()
		self:free()
	end
end

Resource.listen, Resource.silence = EventSource.mixin("eventSource")

function Resource:free()
	self.eventSource:process(ResourceEvent.fromFree())
end

function Resource:release()
	self.value = nil
	self.eventSource:process(ResourceEvent.fromRelease())
end

function Resource:getID()
	return self.id
end

function Resource:getIsReady()
	return self.value ~= nil
end

--- @generic T
--- @param self RatScratch.Resource.Resource<T>
--- @return T
function Resource:get()
	assert(self:getIsReady(), "resource is not ready")

	return self.value
end

--- @generic T
--- @param self RatScratch.Resource.Resource<T>
--- @param value T
function Resource:set(value)
	if value == nil then
		self:release()
	else
		local previousValue
		previousValue, self.value = self.value, value
		self.eventSource:process(ResourceEvent.fromModify(previousValue))
	end
end

return Resource
