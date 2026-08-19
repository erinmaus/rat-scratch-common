local Object = require("rat-scratch-common").Object
local ExtendedModel = require("rat-scratch-pipeline-tools.Model.ExtendedModel")
local ExtendedModelSerializer =
	require("rat-scratch-pipeline-tools.Model.ExtendedModelSerializer")

--- @class RatScratch.Pipeline.ExtendedScene : RatScratch.Common.BaseObject
--- @overload fun(sceneDefinition: RatScratch.Graphics.Graphics3D.SceneDefinition, pipelineConfig: RatScratch.Pipeline.PipelineConfig): RatScratch.Pipeline.ExtendedScene
--- @field private sceneDefinition RatScratch.Graphics.Graphics3D.SceneDefinition
--- @field private models RatScratch.Pipeline.ExtendedModel[]
--- @field private pipelineConfig RatScratch.Pipeline.PipelineConfig
local ExtendedScene = Object()

--- @param sceneDefinition RatScratch.Graphics.Graphics3D.SceneDefinition
--- @param pipelineConfig RatScratch.Pipeline.PipelineConfig
function ExtendedScene:new(sceneDefinition, pipelineConfig)
	self.sceneDefinition = {
		id = sceneDefinition.id,
		name = sceneDefinition.name,
		models = sceneDefinition.models,
		extras = {
			RAT_extras_serialize = {
				userdata = self,
				serialize = ExtendedScene._serializeScene,
			},
		},
	}

	self.pipelineConfig = pipelineConfig

	self.models = {}
	for _, modelDefinition in ipairs(self.sceneDefinition.models) do
		local extendedModel = ExtendedModel(modelDefinition)
		extendedModel:build(pipelineConfig)

		table.insert(self.models, extendedModel)
	end
end

--- @return integer
function ExtendedScene:getModelCount()
	return #self.models
end

--- @param index integer
--- @return RatScratch.Pipeline.ExtendedModel
function ExtendedScene:getModel(index)
	return self.models[index]
end

--- @param builder RatScratch.GLTF.GLTFBuilder
function ExtendedScene:serialize(builder)
	--- @type RatScratch.Graphics.Graphics3D.SceneDefinition
	local result = {
		id = self.sceneDefinition.id,
		name = self.sceneDefinition.name,
		models = {},
		extras = self.sceneDefinition.extras,
	}

	for i, extendedModel in ipairs(self.models) do
		local serializer = ExtendedModelSerializer(
			self.sceneDefinition.models[i],
			extendedModel
		)
		table.insert(result.models, serializer:getModelDefinition())
	end

	builder:fromSceneDefinition(result)
end

--- @private
--- @param builder RatScratch.GLTF.GLTFBuilder
function ExtendedScene:_serializeScene(builder)
	local root = builder:getRoot()

	local extras = root.extras
	if not extras then
		extras = {}
		root.extras = extras
	end

	extras.RAT_pipeline_extra = self.pipelineConfig:serialize()
end

return ExtendedScene
