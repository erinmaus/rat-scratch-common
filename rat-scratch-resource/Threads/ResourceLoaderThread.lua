local Object = require("rat-scratch-common").Object
local ResourceLoaderTask = require("rat-scratch-resource.ResourceLoaderTask")

--- @type love.Channel, love.Channel
local inputChannel, outputChannel, threadID = ...

ResourceLoaderTask.initialize(threadID)

--- @type table<string, RatScratch.Resource.ResourceType>
local resourceTypes = {}

local isRunning = true
while isRunning do
	local event = inputChannel:demand()
	if event.type == "quit" then
		isRunning = false
	elseif event.type == "load" then
		local resourceType = resourceTypes[event.resource]
		if not resourceType then
			resourceType = require(event.resource)
			resourceType = resourceType()
		end

		local data, dependencies, otherResources
		local success, a, b, c =
			pcall(resourceType.loadDataFromFile, resourceType, event.filename)
		if not success then
			print(">>> a", a)
			-- TODO: log error message somehow ("a")
			data = resourceType:createDefaultResource()
			dependencies = { resourceType:resolvePath(event.filename) }
		else
			data, dependencies, otherResources = a, b, c
		end

		local modifiedTimes = {}
		for _, dependency in ipairs(dependencies) do
			local info = love.filesystem.getInfo(dependency)
			modifiedTimes[dependency] = info and info.modtime or 0
		end

		if otherResources then
			for _, otherResource in ipairs(otherResources) do
				local resourceTypeName
				if Object.isType(otherResource.resourceType) then
					resourceTypeName =
						otherResource.resourceType._DEBUG.requireName
				elseif type(otherResource.resourceType) == "string" then
					resourceTypeName = otherResource.resourceType
				end

				if resourceTypeName then
					outputChannel:push({
						type = "dependency",
						resourceID = event.resourceID,
						dependencyID = otherResource.dependencyID,
						resourceType = resourceTypeName,
						filename = otherResource.filename,
					})
				end
			end
		end

		outputChannel:push({
			type = "load",
			resourceID = event.resourceID,
			resourceData = data,
			modifiedTimes = modifiedTimes,
		})
	elseif event.type == "peek" then
		for dependency, time in pairs(event.modifiedTimes) do
			local info = love.filesystem.getInfo(dependency)
			local currentTime = info and info.modtime or 0
			if time ~= currentTime then
				outputChannel:push({
					type = "reload",
					resourceID = event.resourceID,
				})

				break
			end
		end
	end
end
