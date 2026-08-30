local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local assert = require("rat-scratch-common").Debug.assert

--- @class RatScratch.Resource.ResourceLoader : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Resource.ResourceLoader
local ResourceLoader = Object()

ResourceLoader.INPUT_CHANNEL = love.thread.newChannel()
ResourceLoader.OUTPUT_CHANNEL = love.thread.newChannel()

function ResourceLoader.initialize()
	local processorCount = math.max(love.system.getProcessorCount() - 2, 4)

	--- @type love.Thread[]
	local threads = {}
	for i = 1, processorCount do
		local thread =
			love.thread.newThread("Inkfright/Data/ResourceLoaderThread.lua")
		thread:start(
			ResourceLoader.OUTPUT_CHANNEL,
			ResourceLoader.INPUT_CHANNEL,
			i
		)

		table.insert(threads, thread)
	end

	local handle = newproxy(true)
	getmetatable(handle).__gc = function()
		for _ = 1, #threads do
			ResourceLoader.OUTPUT_CHANNEL:push({ type = "quit" })
		end

		for _, thread in ipairs(threads) do
			thread:wait()
		end
	end

	ResourceLoader.HANDLE = handle
end

function ResourceLoader.update()
	if not ResourceLoader.HANDLE then
		ResourceLoader.initialize()
	end

	local channel = ResourceLoader.INPUT_CHANNEL

	local event
	repeat
		event = channel:pop()

		if event then
			if event.type == "load" then
				--- @type integer
				local id = event.resourceID

				--- @type any
				local data = event.resourceData

				--- @type table<string, number>
				local modifiedTimes = event.modifiedTimes

				local resource = ResourceLoader.RESOURCE_ID_TO_RESOURCE[id]
				if resource then
					local resources = ResourceLoader.RESOURCES[resource.type]
					local success, result = pcall(
						resources.instance.instantiateFromData,
						resources.instance,
						id,
						data
					)
					if not success then
						result = resources.instance:instantiateFromData(
							id,
							resources.instance:createDefaultResource()
						)
					end

					ResourceLoader._loadResource(
						resource,
						result,
						modifiedTimes
					)
				end
			elseif event.type == "reload" then
				local resource =
					ResourceLoader.RESOURCE_ID_TO_RESOURCE[event.resourceID]
				resource.reloading = resource.reloading + 1

				ResourceLoader.OUTPUT_CHANNEL:push({
					type = "load",
					resource = resource.type._DEBUG.requireName,
					filename = resource.filename,
					resourceID = resource.id,
				})
			elseif event.type == "dependency" then
				local resource =
					ResourceLoader.RESOURCE_ID_TO_RESOURCE[event.resourceID]

				local resourceType = require(event.resourceType)

				local otherResource =
					ResourceLoader._tryLoad(resourceType, event.filename)
				if not otherResource then
					otherResource =
						ResourceLoader._newLoad(resourceType, event.filename)
				end

				ResourceLoader.DEPENDENCY_ID_TO_RESOURCE[event.dependencyID] =
					otherResource
				ResourceLoader._addDependency(resource, otherResource)
			end
		end
	until not event

	for _, resource in pairs(ResourceLoader.RESOURCE_ID_TO_RESOURCE) do
		if resource.reloading == 0 then
			ResourceLoader.OUTPUT_CHANNEL:push({
				type = "peek",
				resourceID = resource.id,
				modifiedTimes = resource.modifiedTimes,
			})
		end
	end
end

ResourceLoader.NEXT_ID = 1

--- @alias RatScratch.Resource.ResourceLoader.Resource {
---   id: integer,
---   type: RatScratch.Resource.ResourceType,
---   filename: string,
---   resource: RatScratch.Resource.Resource,
---   parents: table<RatScratch.Resource.ResourceLoader.Resource, true>,
---   modifiedTimes: table<string, number>,
---   reloading: integer,
---   dependencies: table<RatScratch.Resource.ResourceLoader.Resource, true>,
--- }

--- @private
--- @param id integer
--- @param resourceType RatScratch.Resource.ResourceType
--- @param filename string
--- @return RatScratch.Resource.ResourceLoader.Resource
function ResourceLoader._newResource(id, resourceType, filename)
	return {
		id = id,
		type = resourceType,
		filename = filename,
		modifiedTimes = {},
		reloading = 0,
		dependencies = {},
		parents = {},
	}
end

--- @private
--- @param resource RatScratch.Resource.ResourceLoader.Resource
--- @param modifiedTimes table<string, integer>
function ResourceLoader._addResourceModifiedTimes(resource, modifiedTimes)
	for key, time in pairs(modifiedTimes) do
		resource.modifiedTimes[key] = time
	end

	for parent in pairs(resource.parents) do
		ResourceLoader._addResourceModifiedTimes(parent, modifiedTimes)
	end
end

--- @private
--- @param resource RatScratch.Resource.ResourceLoader.Resource
--- @param value RatScratch.Resource.Resource
--- @param modifiedTimes table<string, integer>
function ResourceLoader._loadResource(resource, value, modifiedTimes)
	if resource.resource then
		resource.resource:release()
	end

	resource.resource = value
	resource.reloading = math.max(resource.reloading - 1, 0)

	Table.clear(resource.modifiedTimes)
	ResourceLoader._addResourceModifiedTimes(resource, modifiedTimes)

	for parent in pairs(resource.parents) do
		parent.reloading = math.max(parent.reloading - 1, 0)
	end
end

--- @private
--- @param resource RatScratch.Resource.ResourceLoader.Resource
--- @param otherResource RatScratch.Resource.ResourceLoader.Resource
function ResourceLoader._addDependency(resource, otherResource)
	assert(
		not ResourceLoader._hasParent(resource, otherResource),
		'resource "%s" is already dependent on other resource "%s"',
		resource.filename,
		otherResource.filename
	)
	assert(
		resource ~= otherResource,
		'resource "%s" cannot have itself as a dependency',
		resource.filename
	)

	resource.dependencies[otherResource] = true
	otherResource.parents[resource] = true
	resource.reloading = resource.reloading + 1
end

--- @private
--- @param resource RatScratch.Resource.ResourceLoader.Resource
--- @param parent RatScratch.Resource.ResourceLoader.Resource
function ResourceLoader._hasParent(resource, parent)
	for otherParent in pairs(resource.parents) do
		if
			otherParent == parent
			or ResourceLoader._hasParent(otherParent, parent)
		then
			return true
		end
	end

	return false
end

--- @alias RatScratch.Resource.ResourceLoader.Resources {
---   type: RatScratch.Resource.ResourceType,
---   instance: RatScratch.Resource.ResourceType,
---   resources: table<string, RatScratch.Resource.ResourceLoader.Resource>,
--- }

--- @type table<RatScratch.Resource.ResourceType, RatScratch.Resource.ResourceLoader.Resources>
ResourceLoader.RESOURCES = {}

--- @type table<integer, RatScratch.Resource.ResourceLoader.Resource>
ResourceLoader.RESOURCE_ID_TO_RESOURCE = setmetatable({}, { __mode = "v" })

--- @type table<string, RatScratch.Resource.ResourceLoader.Resource>
ResourceLoader.DEPENDENCY_ID_TO_RESOURCE = setmetatable({}, { __mode = "v" })

--- @private
--- @param resourceType RatScratch.Resource.ResourceType
--- @return RatScratch.Resource.ResourceLoader.Resources
function ResourceLoader._getResources(resourceType)
	local resources = ResourceLoader.RESOURCES[resourceType]
	if not resources then
		resources = {
			type = resourceType,
			instance = resourceType(),
			resources = setmetatable({}, { __mode = "v" }),
		}

		ResourceLoader.RESOURCES[resourceType] = resources
	end

	return resources
end

--- @private
--- @param resourceType RatScratch.Resource.ResourceType
--- @param filename string
--- @return RatScratch.Resource.ResourceLoader.Resource
function ResourceLoader._tryLoad(resourceType, filename)
	local resources = ResourceLoader._getResources(resourceType)
	return resources.resources[filename]
end

--- @private
--- @param resourceType RatScratch.Resource.ResourceType
--- @param filename string
--- @return RatScratch.Resource.ResourceLoader.Resource
function ResourceLoader._newLoad(resourceType, filename)
	local resources = ResourceLoader._getResources(resourceType)

	local id = ResourceLoader.newID()
	local resource = ResourceLoader._newResource(id, resourceType, filename)

	resources.resources[filename] = resource
	ResourceLoader.RESOURCE_ID_TO_RESOURCE[id] = resource

	ResourceLoader.OUTPUT_CHANNEL:push({
		type = "load",
		resource = resourceType._DEBUG.requireName,
		filename = filename,
		resourceID = id,
	})

	return resource
end

--- @return integer
function ResourceLoader.newID()
	local id = ResourceLoader.NEXT_ID
	ResourceLoader.NEXT_ID = ResourceLoader.NEXT_ID + 1

	return id
end

--- @param resourceType RatScratch.Resource.ResourceType
--- @param filename string
--- @return integer
function ResourceLoader.load(resourceType, filename)
	local resource = ResourceLoader._tryLoad(resourceType, filename)
	if not resource then
		resource = ResourceLoader._newLoad(resourceType, filename)
	end

	return resource.id
end

--- @param id integer | string
--- @return RatScratch.Resource.Resource | nil
function ResourceLoader.get(id)
	local resource = ResourceLoader.RESOURCE_ID_TO_RESOURCE[id]
		or ResourceLoader.DEPENDENCY_ID_TO_RESOURCE[id]
	return resource and resource.resource or nil
end

function ResourceLoader.ready(id)
	return ResourceLoader.get(id) ~= nil
end

return ResourceLoader
