local Object = require("rat-scratch-common").Object
local GLTF = require("rat-scratch-gltf")
local PipelineParser = require("rat-scratch-pipeline.GLTF.PipelineParser")
local PipelineScene = require("rat-scratch-pipeline.Graphics3D.PipelineScene")
local Resource = require("rat-scratch-resource").Resource

--- @class RatScratch.Pipeline.Resources.PipelineSceneResourceType : RatScratch.Resource.ResourceType<RatScratch.Pipeline.Graphics3D.PipelineScene, RatScratch.Pipeline.Graphics3D.PipelineSceneDefinition>
--- @overload fun(): RatScratch.Resource.ResourceType<RatScratch.Pipeline.Graphics3D.PipelineScene, RatScratch.Pipeline.Graphics3D.PipelineSceneDefinition>
local PipelineResourceType = Object()

function PipelineResourceType:createDefaultResource()
	return {}
end

--- @param filename string
--- @return RatScratch.Pipeline.Graphics3D.PipelineSceneDefinition
function PipelineResourceType:loadDataFromFile(filename)
	local parser = GLTF.loadFromFilesystem(self:resolvePath(filename))
	local pipelineParser = PipelineParser(nil, parser)
	return pipelineParser:loadSceneDefinition()
end

--- @param id integer
--- @param data RatScratch.Pipeline.Graphics3D.PipelineSceneDefinition
function PipelineResourceType:instantiateFromData(id, data)
	local resource = Resource(id)
	resource:set(PipelineScene.fromDefinition(data))

	return resource
end

return PipelineResourceType
