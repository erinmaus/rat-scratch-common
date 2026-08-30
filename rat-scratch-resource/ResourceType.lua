local Object = require("rat-scratch-common").Object
local Path = require("rat-scratch-common").Path

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
	return not love.graphics
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
--- @param data D
--- @return T
function ResourceType:instantiateFromData(id, data)
	return self:ABSTRACT()
end

return ResourceType
