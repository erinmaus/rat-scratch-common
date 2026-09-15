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
local GLTF = require("rat-scratch-gltf")
local ExtendedScene = require("rat-scratch-pipeline-tools").Model.ExtendedScene
local PipelineConfig = require("rat-scratch-pipeline").PipelineConfig
local PipelineSceneResourceType =
	require("rat-scratch-pipeline").Resources.PipelineSceneResourceType
local PipelineScenePointer =
	require("rat-scratch-pipeline").Resources.PipelineScenePointer
local AnimationPipeline = require("rat-scratch-pipeline").AnimationPipeline

local demo = {}

local function makeGLB()
	local pipelineConfig = PipelineConfig.loadDefault()

	local parser = GLTF.loadFromFilesystem("samples/assets/gltf/shoe.glb")
	local scene = parser:loadScene(1, {
		attributes = {
			static = {
				output = GLTF.Attributes.makeStaticStandard(),
			},
		},
	})

	local extendedScene = ExtendedScene(scene, pipelineConfig)

	local builder = GLTF.Builder()
	extendedScene:serialize(builder)
	GLTF.saveGLB("shoe_pipeline.glb", builder:build("shoe_pipeline.glb"))
end

function demo.load()
	makeGLB()

	ResourceLoader.toggleDebug(true)

	local pipelineRuntime = PipelineRuntime.loadDefault()

	local renderer = PipelineRenderer(pipelineRuntime)
	local world = renderer:getWorld()
	local scene = Scene(world)
	local object = world:newObject()
	object:move(scene)

	local sceneResource =
		ResourceLoader.load(PipelineSceneResourceType, "shoe_pipeline.glb")
	local modelResource = PipelineScenePointer.newModelPointer(sceneResource, 1)
	object:attachModel(modelResource)

	world:getPipeline(AnimationPipeline):loadDefaultShaders()

	local ambientLight = scene:newLight(AmbientLight)
	ambientLight:setAmbience(0.5)

	local directionalLight = scene:newLight(DirectionalLight)
	directionalLight:setDirection(Vector3(1, -4, 1))

	local camera = ArcballCamera()
	camera:setDistance(2.5)
	camera:setSize(love.graphics.getDimensions())

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
	love.graphics.push("all")
	love.graphics.setDepthMode("lequal", true)
	demo.renderer:draw(demo.scene)
	love.graphics.pop()
end

return demo
