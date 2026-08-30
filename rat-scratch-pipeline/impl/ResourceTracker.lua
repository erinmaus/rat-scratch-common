local Object = require("rat-scratch-common").Object
local EventSource = require("rat-scratch-common").EventSource
local Table = require("rat-scratch-common").Table
local ResourceEvent = require("rat-scratch-resource").ResourceEvent
local ResourceTrackerEvent =
	require("rat-scratch-pipeline.impl.ResourceTrackerEvent")

--- @generic T
--- @class RatScratch.Pipeline.ResourceTracker<T> : RatScratch.Common.BaseObject
--- @field private resources table<RatScratch.Resource.Resource<T>, integer>
--- @field private resourceValue table<RatScratch.Resource.Resource<T>, T>
--- @field private objectsByResource table<RatScratch.Resource.Resource<T>, table<RatScratch.Pipeline.ObjectHandle, true>>
--- @field private dirtyResources table<RatScratch.Resource.Resource<T>, boolean>
--- @field private dirtyResourcesByIndex RatScratch.Resource.Resource<T>[]
--- @field private dirtyResourcePreviousValue table<RatScratch.Resource.Resource<T>, T>
--- @field private eventSource RatScratch.Common.EventSource<RatScratch.Pipeline.ResourceTracker<T>>
--- @overload fun(): RatScratch.Pipeline.ResourceTracker
local ResourceTracker = Object()

function ResourceTracker:new()
	self.resources = {}
	self.resourceValue = {}
	self.objectsByResource = {}
	self.eventSource = EventSource(self)

	self.dirtyResources = {}
	self.dirtyResourcesByIndex = {}
	self.dirtyResourcePreviousValue = {}
end

ResourceTracker.listen, ResourceTracker.silence =
	EventSource.mixin("eventSource")

--- @param resource RatScratch.Resource.Resource
function ResourceTracker:has(resource)
	return self.resources[resource] ~= nil
end

--- @param resource RatScratch.Resource.Resource
--- @param object RatScratch.Pipeline.ObjectHandle
function ResourceTracker:add(resource, object)
	local isNew = not self:has(resource)

	local count = (self.resources[resource] or 0) + 1
	self.resources[resource] = count

	local objects = self.objectsByResource[resource]
	if not objects then
		objects = {}
		self.objectsByResource[resource] = objects
	end
	objects[object] = true

	if isNew then
		self.objectsByResource[resource] = {}

		self.eventSource:process(
			ResourceTrackerEvent.fromAdd(resource, objects)
		)
		resource:listen(ResourceEvent.MODIFY, self._onResourceUpdate, self)
	end

	self.resourceValue[resource] = resource:get()
		or self.resourceValue[resource]
end

--- @param resource RatScratch.Resource.Resource
--- @param object RatScratch.Pipeline.ObjectHandle
function ResourceTracker:remove(resource, object)
	if not self:has(resource) then
		return
	end

	self.resources[resource] = math.max(self.resources[resource] - 1, 0)

	local objects = self.objectsByResource[resource]
	if objects then
		objects[object] = nil
	end
end

--- @private
--- @param event RatScratch.Resource.ResourceEvent
--- @param resource RatScratch.Resource.Resource
function ResourceTracker:_onResourceUpdate(event, resource)
	if not self.dirtyResources[resource] then
		self.dirtyResources[resource] = true
		self.dirtyResourcePreviousValue[resource] = event:getPreviousValue()
		table.insert(self.dirtyResourcesByIndex, resource)
	end

	self.resourceValue[resource] = resource:get()
		or self.resourceValue[resource]
end

function ResourceTracker:flush()
	for resource, count in pairs(self.resources) do
		if count <= 0 then
			resource:silence(ResourceEvent.MODIFY, self._onResourceUpdate, self)

			self.eventSource:process(
				ResourceTrackerEvent.fromRemove(
					resource,
					self.resourceValue[resource]
				)
			)
			self.resources[resource] = nil
			self.resourceValue[resource] = nil
			self.objectsByResource[resource] = nil

			if self.dirtyResources[resource] then
				table.remove(self.dirtyResourcesByIndex, resource)
				self.dirtyResources[resource] = nil
			end
		end
	end

	for _, resource in ipairs(self.dirtyResourcesByIndex) do
		self.dirtyResources[resource] = nil
		self.eventSource:process(
			ResourceTrackerEvent.fromUpdate(
				resource,
				self.dirtyResourcePreviousValue[resource],
				self.objectsByResource[resource]
			)
		)
	end

	Table.clear(self.dirtyResources)
end

return ResourceTracker
