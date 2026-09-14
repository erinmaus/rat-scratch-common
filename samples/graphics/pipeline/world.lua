local PipelineRuntime = require("rat-scratch-pipeline").PipelineRuntime
local ResourceLoader = require("rat-scratch-resource").ResourceLoader
local Scene = require("rat-scratch-pipeline").Scene
local PipelineRenderer = require("rat-scratch-pipeline").PipelineRenderer
local AmbientLight = require("rat-scratch-pipeline").AmbientLight
local DirectionalLight = require("rat-scratch-pipeline").DirectionalLight
local Vector3 = require("rat-scratch-math").Vector3
local Quaternion = require("rat-scratch-math").Quaternion
local ArcballCamera = require("rat-scratch-pipeline").ArcballCamera
local LightPipeline = require("rat-scratch-pipeline").LightPipeline
local PipelineSceneResourceType =
	require("rat-scratch-pipeline").Resources.PipelineSceneResourceType
local PipelineScenePointer =
	require("rat-scratch-pipeline").Resources.PipelineScenePointer
local AnimationPipeline = require("rat-scratch-pipeline").AnimationPipeline

local demo = {}

function demo.load()
	ResourceLoader.toggleDebug(true)

	local pipelineRuntime = PipelineRuntime.loadDefault()

	local renderer = PipelineRenderer(pipelineRuntime)
	local world = renderer:getWorld()
	local scene = Scene(world)
	local object = world:newObject()
	object:move(scene)

	local sceneResource = ResourceLoader.load(
		PipelineSceneResourceType,
		"samples/assets/gltf/shoe_pipeline.glb"
	)
	local modelResource = PipelineScenePointer.newModelPointer(sceneResource, 1)
	object:attachModel(modelResource)

	world:getPipeline(AnimationPipeline):loadDefaultShaders()

	local ambientLight = scene:newLight(AmbientLight)
	ambientLight:setAmbience(0.5)

	local directionalLight = scene:newLight(DirectionalLight)
	directionalLight:setDirection(Vector3(1, 4, 1))

	local camera = ArcballCamera()
	camera:setDistance(10)
	scene:setCamera(camera)
	scene:getPipeline(LightPipeline):loadDefaultShaders()

	demo.renderer = renderer
	demo.scene = scene
	demo.camera = camera
end

function demo.update()
	demo.camera:setRotation(
		Quaternion.fromAxisAngle(Vector3.UNIT_Y, love.timer.getTime() / math.pi)
	)

	ResourceLoader.update()
	demo.renderer:update()
	demo.scene:flush()
end

function demo.draw()
	demo.renderer:draw(demo.scene)
end

return demo
