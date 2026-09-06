local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert

--- @class RatScratch.Resource.ResourceLoaderTask : RatScratch.Common.BaseObject
--- @overload fun(): RatScratch.Resource.ResourceLoaderTask
local ResourceLoaderTask = Object()

--- @private
ResourceLoaderTask.THREAD_ID = 0

--- @private
ResourceLoaderTask.NEXT_DEPENDENCY_ID = 1

function ResourceLoaderTask.initialize(threadID)
	ResourceLoaderTask.THREAD_ID = threadID
end

function ResourceLoaderTask.newDependencyID()
	assert(
		ResourceLoaderTask.THREAD_ID > 0,
		"resource loader task not initialized"
	)

	local dependencyID = string.format(
		"%s::%s",
		ResourceLoaderTask.THREAD_ID,
		ResourceLoaderTask.NEXT_DEPENDENCY_ID
	)
	ResourceLoaderTask.NEXT_DEPENDENCY_ID = ResourceLoaderTask.NEXT_DEPENDENCY_ID
		+ 1

	return dependencyID
end

return ResourceLoaderTask
