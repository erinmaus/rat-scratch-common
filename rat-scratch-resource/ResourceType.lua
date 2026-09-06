local Object = require("rat-scratch-common").Object
local Path = require("rat-scratch-common").Path
local Resource = require("rat-scratch-resource.Resource")

--- @class RatScratch.Resource.ResourceDependency
--- @field public dependencyID string
--- @field public resourceType RatScratch.Resource.ResourceType | string
--- @field public filename string
local ResourceDependency = {}

--- @generic T
--- @generic D
--- @class RatScratch.Resource.ResourceType<T, D> : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Resource.ResourceType<T, D>
local ResourceType = Object()

function ResourceType:new()
	-- Nothing.
end

function ResourceType:isRenderThread()
	return love.graphics ~= nil
end

function ResourceType:isResourceThread()
	return love.graphics == nil
end

function ResourceType:getRootPath()
	return nil
end

function ResourceType:getRootPaths()
	return nil
end

--- @param filename string
--- @param parentPath? string
--- @return string
function ResourceType:resolvePath(filename, parentPath)
	return Path.resolve(
		parentPath or "",
		filename,
		self:getRootPath(),
		self:getRootPaths()
	)
end

--- @generic T
--- @generic D
--- @param self RatScratch.Resource.ResourceType<T, D>
--- @return D
function ResourceType:createDefaultResource()
	return self:ABSTRACT()
end

--- @generic T
--- @generic D
--- @param self RatScratch.Resource.ResourceType<T, D>
--- @param filename string
--- @return D, string[], RatScratch.Resource.ResourceDependency[]?
function ResourceType:loadDataFromFile(filename)
	return self:ABSTRACT()
end

--- @generic T
--- @generic D
--- @param self RatScratch.Resource.ResourceType<T, D>
--- @param id integer
--- @return RatScratch.Resource.Resource<T>
function ResourceType:newResource(id)
	return Resource(id)
end

--- @generic T
--- @generic D
--- @param self RatScratch.Resource.ResourceType<T, D>
--- @param id integer
--- @param data D
--- @return T
function ResourceType:instantiateFromData(id, data)
	local resource = Resource(id)
	self:updateFromData(resource, data)

	return resource
end

--- @generic T
--- @generic D
--- @param self RatScratch.Resource.ResourceType<T, D>
--- @param resource T
--- @param data D
--- @return T
function ResourceType:updateFromData(resource, data)
	return self:ABSTRACT()
end

return ResourceType
