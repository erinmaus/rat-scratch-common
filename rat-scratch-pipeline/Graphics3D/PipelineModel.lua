local Object = require("rat-scratch-common").Object
local PipelineMesh = require("rat-scratch-pipeline.Graphics3D.PipelineMesh")
local Skeleton = require("rat-scratch-graphics.Graphics3D").Skeleton

--- @class RatScratch.Pipeline.Graphics3D.PipelineModel : RatScratch.Common.BaseObject
--- @field private meshes RatScratch.Pipeline.Graphics3D.PipelineMesh[]
--- @field private skeleton? RatScratch.Graphics.Graphics3D.Skeleton
--- @field private transform love.Transform
--- @overload fun(meshes: RatScratch.Pipeline.Graphics3D.PipelineMesh[], transform?: love.Transform, skeleton: RatScratch.Graphics.Graphics3D.Skeleton?): RatScratch.Pipeline.Graphics3D.PipelineModel
local PipelineModel = Object()

--- @param meshes RatScratch.Pipeline.Graphics3D.PipelineMesh[]
--- @param transform? love.Transform
function PipelineModel:new(meshes, transform, skeleton)
	self.meshes = meshes
	self.transform = transform or love.math.newTransform()
	self.skeleton = skeleton
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

function PipelineModel:getSkeleton()
	return self.skeleton
end

--- @param modelDefinition RatScratch.Pipeline.Graphics3D.PipelineModelDefinition
--- @param skeleton RatScratch.Graphics.Graphics3D.Skeleton?
--- @return RatScratch.Pipeline.Graphics3D.PipelineModel
function PipelineModel.fromDefinition(modelDefinition, skeleton)
	local meshes = {}

	for _, meshDefinition in ipairs(modelDefinition.meshes) do
		table.insert(meshes, PipelineMesh.fromDefinition(meshDefinition))
	end

	return PipelineModel(
		meshes,
		modelDefinition.transform,
		skeleton
			or (
				modelDefinition.skeleton
				and Skeleton.fromDefinition(modelDefinition.skeleton)
			)
	)
end

return PipelineModel
