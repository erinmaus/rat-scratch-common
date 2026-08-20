local Object = require("rat-scratch-common").Object
local PipelineMesh = require("rat-scratch-pipeline.Graphics3D.PipelineMesh")

--- @class RatScratch.Pipeline.Graphics3D.PipelineModel : RatScratch.Common.BaseObject
--- @field private meshes RatScratch.Pipeline.Graphics3D.PipelineMesh[]
--- @field private transform love.Transform
--- @overload fun(meshes: RatScratch.Pipeline.Graphics3D.PipelineMesh[], transform?: love.Transform): RatScratch.Pipeline.Graphics3D.PipelineModel
local PipelineModel = Object()

--- @param meshes RatScratch.Pipeline.Graphics3D.PipelineMesh[]
--- @param transform? love.Transform
function PipelineModel:new(meshes, transform)
	self.meshes = meshes
	self.transform = transform or love.math.newTransform()
end

function PipelineModel:getMeshCount()
	return #self.meshes
end

function PipelineModel:getMesh(index)
	return self.meshes[index]
end

function PipelineModel:getTransform()
	return self.transform
end

--- @param modelDefinition RatScratch.Pipeline.Graphics3D.PipelineModelDefinition
--- @return RatScratch.Pipeline.Graphics3D.PipelineModel
function PipelineModel.fromDefinition(modelDefinition)
	local meshes = {}

	for _, meshDefinition in ipairs(modelDefinition.meshes) do
		table.insert(meshes, PipelineMesh.fromDefinition(meshDefinition))
	end

	return PipelineModel(meshes, modelDefinition.transform)
end

return PipelineModel
