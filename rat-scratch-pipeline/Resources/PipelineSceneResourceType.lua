local Object = require("rat-scratch-common").Object
local GLTF = require("rat-scratch-gltf")
local PipelineParser = require("rat-scratch-pipeline.GLTF.PipelineParser")
local PipelineScene = require("rat-scratch-pipeline.Graphics3D.PipelineScene")
local ResourceType = require("rat-scratch-resource").ResourceType

--- @class RatScratch.Pipeline.Resources.PipelineSceneResourceType : RatScratch.Resource.ResourceType<RatScratch.Pipeline.Graphics3D.PipelineScene, RatScratch.Pipeline.Graphics3D.PipelineSceneDefinition>
--- @overload fun(): RatScratch.Resource.ResourceType<RatScratch.Pipeline.Graphics3D.PipelineScene, RatScratch.Pipeline.Graphics3D.PipelineSceneDefinition>
local PipelineResourceType = Object(ResourceType)

function PipelineResourceType:createDefaultResource()
	return {}
end

--- @param filename string
--- @return RatScratch.Pipeline.Graphics3D.PipelineSceneDefinition, string[]
function PipelineResourceType:loadDataFromFile(filename)
	local resolvedPath = self:resolvePath(filename)
	local parser = GLTF.loadFromFilesystem(resolvedPath)
	local pipelineParser = PipelineParser(nil, parser)
	return pipelineParser:loadSceneDefinition(), { resolvedPath }
end

--- @param resource RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineScene>
--- @param data RatScratch.Pipeline.Graphics3D.PipelineSceneDefinition
function PipelineResourceType:updateFromData(resource, data)
	resource:set(PipelineScene.fromDefinition(data))
	return resource
end

return PipelineResourceType
