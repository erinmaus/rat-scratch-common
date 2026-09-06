local GLTF = require("rat-scratch-gltf")
local ExtendedScene = require("rat-scratch-pipeline-tools").Model.ExtendedScene
local PipelineConfig = require("rat-scratch-pipeline").PipelineConfig
local PipelineRuntime = require("rat-scratch-pipeline").PipelineRuntime
local World = require("rat-scratch-pipeline").World
local ResourceLoader = require("rat-scratch-resource").ResourceLoader
local PipelineSceneResourceType =
	require("rat-scratch-pipeline").Resources.PipelineSceneResourceType
local PipelineScenePointer =
	require("rat-scratch-pipeline").Resources.PipelineScenePointer
local AnimationPipeline = require("rat-scratch-pipeline").AnimationPipeline

local demo = {}

function demo.load()
	ResourceLoader.toggleDebug(true)

	local parser = GLTF.loadFromFilesystem("samples/assets/gltf/shoe.glb")
	local baseScene = parser:loadScene(1)

	local pipelineConfig = PipelineConfig.loadDefault()
	local pipelineRuntime = PipelineRuntime(pipelineConfig)

	local extendedScene = ExtendedScene(baseScene, pipelineConfig)
	local extendedModel = extendedScene:getModel(1)

	local world = World(pipelineRuntime)
	local object = world:newObject()

	local sceneResource = ResourceLoader.load(
		PipelineSceneResourceType,
		"samples/assets/gltf/shoe_pipeline.glb"
	)
	local modelResource = PipelineScenePointer.newModelPointer(sceneResource, 1)
	object:attachModel(modelResource)

	world:getPipeline(AnimationPipeline):loadDefaultShaders()

	demo.world = world
end

function demo.update()
	ResourceLoader.update()
	demo.world:flush()
end

return demo
