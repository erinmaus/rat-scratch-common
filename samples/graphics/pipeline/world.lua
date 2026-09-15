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
local GammaColor = require("rat-scratch-graphics.GammaColor")
local LinearColor = require("rat-scratch-graphics.LinearColor")
local PointLight = require("rat-scratch-pipeline.PointLight")
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
	ambientLight:setAmbience(0.3)

	local directionalLight = scene:newLight(DirectionalLight)
	directionalLight:setDirection(Vector3(1, -4, 1))
	directionalLight:setColor(GammaColor(0.4, 0.4, 0.4))

	local pointLight = scene:newLight(PointLight)
	pointLight:setColor(LinearColor(1, 1, 1))
	pointLight:setAttenuation(10)

	local camera = ArcballCamera()
	camera:setDistance(1.25)
	camera:setSize(love.graphics.getDimensions())
	camera:setFOV(math.pi / 2)

	scene:setCamera(camera)
	scene:getPipeline(LightPipeline):loadDefaultShaders()

	demo.renderer = renderer
	demo.scene = scene
	demo.camera = camera
	demo.pointLight = pointLight
	demo.directionalLight = directionalLight
end

function demo.update()
	local mx, my = love.mouse.getPosition()
	local w, h = love.graphics.getDimensions()
	local hw, hh = w / 2, h / 2
	local x, y = (mx - hw) / hw, (my - hh) / hh

	demo.camera:setRotation(
		Quaternion.fromAxisAngle(Vector3.UNIT_Y, x * math.pi)
			:product(Quaternion.fromAxisAngle(Vector3.UNIT_X, y * math.pi))
	)

	demo.directionalLight:setDirection(
		demo.camera:getRotation():transformVector(Vector3(0, 0, -1))
	)

	demo.pointLight:setPosition(
		Vector3(
			math.cos(love.timer.getTime() * (math.pi / 3) / 3)
				* math.cos(love.timer.getTime() * (math.pi / 5) / 4)
				* 0.5,
			-0.25,
			math.cos(love.timer.getTime() * (math.pi / 2.5) / 3)
				* math.cos(love.timer.getTime() * (math.pi / 2.75) / 4)
				* 0.5
		)
	)

	ResourceLoader.update()
	demo.renderer:update()
	demo.scene:flush()
end

local _position = Vector3()
function demo.draw()
	love.graphics.push("all")
	love.graphics.setDepthMode("lequal", true)
	demo.renderer:draw(demo.scene)
	love.graphics.pop()

	local position =
		demo.camera:project(demo.pointLight:getPosition(), _position)
	if
		position.x >= 0
		and position.x < love.graphics.getWidth()
		and position.y >= 0
		and position.y < love.graphics.getHeight()
		and position.z >= 0
		and position.z <= 1
	then
		love.graphics.circle("fill", position.x, position.y, 8)
	end
end

return demo
