local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local Skeleton = require("rat-scratch-graphics").Graphics3D.Skeleton
local Animation = require("rat-scratch-graphics").Graphics3D.Animation
local PipelineModel = require("rat-scratch-pipeline.Graphics3D.PipelineModel")

--- @class RatScratch.Pipeline.Graphics3D.PipelineScene : RatScratch.Common.BaseObject
--- @field private models RatScratch.Pipeline.Graphics3D.PipelineModel[]
--- @field private skeletons RatScratch.Graphics.Graphics3D.Skeleton[]
--- @field private animations table<RatScratch.Graphics.Graphics3D.Skeleton, RatScratch.Graphics.Graphics3D.Animation[]>
--- @overload fun(models: RatScratch.Pipeline.Graphics3D.PipelineModel[], skeletons: RatScratch.Graphics.Graphics3D.Skeleton[], animations: table<RatScratch.Graphics.Graphics3D.Skeleton, RatScratch.Graphics.Graphics3D.Animation[]>): RatScratch.Pipeline.Graphics3D.PipelineScene
local PipelineScene = Object()

--- @param models RatScratch.Pipeline.Graphics3D.PipelineModel[]
--- @param skeletons RatScratch.Graphics.Graphics3D.Skeleton[]
--- @param animations table<RatScratch.Graphics.Graphics3D.Skeleton, RatScratch.Graphics.Graphics3D.Animation[]>
function PipelineScene:new(models, skeletons, animations)
	self.models = models

	self.skeletons = Table.clone(skeletons)
	self.animations = Table.cloneHash(animations)
end

--- @param sceneDefinition RatScratch.Pipeline.Graphics3D.PipelineSceneDefinition
--- @return RatScratch.Pipeline.Graphics3D.PipelineScene
function PipelineScene.fromDefinition(sceneDefinition)
	local skeletons = {}
	local definitionToSkeleton = {}
	for _, skeletonDefinition in ipairs(sceneDefinition.skeletons) do
		local skeleton = Skeleton.fromDefinition(skeletonDefinition)
		table.insert(skeletons, skeleton)
		definitionToSkeleton[skeletonDefinition] = skeleton
	end

	local animations = {}
	for _, animationDefinitions in pairs(sceneDefinition.animations) do
		local skeleton = definitionToSkeleton[animationDefinitions.skeleton]
		if skeleton then
			animations[skeleton] = {}

			for _, animationDefinition in
				ipairs(animationDefinitions.animations)
			do
				table.insert(
					animations[skeleton],
					Animation.fromDefinition(animationDefinition, skeleton)
				)
			end
		end
	end

	local models = {}
	for _, modelDefinition in ipairs(sceneDefinition.models) do
		local model = PipelineModel.fromDefinition(
			modelDefinition,
			definitionToSkeleton[modelDefinition.skeleton]
		)
		table.insert(models, model)
	end

	return PipelineScene(models, skeletons, animations)
end

return PipelineScene
