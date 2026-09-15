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
local GammaColor = require("rat-scratch-graphics").GammaColor
local PointLight = require("rat-scratch-pipeline").PointLight
local ResourceEvent = require("rat-scratch-resource").ResourceEvent
local PipelineSceneResourceType =
	require("rat-scratch-pipeline").Resources.PipelineSceneResourceType
local PipelineScenePointer =
	require("rat-scratch-pipeline").Resources.PipelineScenePointer
local AnimationPipeline = require("rat-scratch-pipeline").AnimationPipeline

local demo = {}

local function makeGLB()
	local pipelineConfig = PipelineConfig.loadDefault()

	local parser = GLTF.loadFromFilesystem(
		"samples/assets/gltf/thejunkshopsplashscreen.glb"
	)
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
	GLTF.saveGLB(
		"shoe_pipeline.glb",
		builder:build("thejunkshopsplashscreen.glb")
	)
end

function demo.load()
	if not love.filesystem.getInfo("shoe_pipeline.glb") then
		makeGLB()
	end

	ResourceLoader.toggleDebug(true)

	local pipelineRuntime = PipelineRuntime.loadDefault()

	local renderer = PipelineRenderer(pipelineRuntime)
	local world = renderer:getWorld()
	local scene = Scene(world)
	local object = world:newObject()
	object:move(scene)

	local sceneResource =
		ResourceLoader.load(PipelineSceneResourceType, "shoe_pipeline.glb")
	sceneResource:listen(ResourceEvent.MODIFY, function(event, resource)
		--- @type RatScratch.Pipeline.Graphics3D.PipelineScene
		local scene = resource:get()

		for i = 1, scene:getModelCount() do
			local modelResource =
				PipelineScenePointer.newModelPointer(sceneResource, i)
			object:attachModel(modelResource)
		end
	end)

	world:getPipeline(AnimationPipeline):loadDefaultShaders()

	local ambientLight = scene:newLight(AmbientLight)
	ambientLight:setAmbience(0.3)
	ambientLight:setColor(GammaColor(0.85098, 0.713725, 0.556863, 1))

	local directionalLight = scene:newLight(DirectionalLight)
	directionalLight:setColor(GammaColor(0.85098, 0.326, 0.556863, 1))

	local pointLights = {}
	for i = 1, 10 do
		local pointLightInfo = {
			offsets = {
				x = {},
				y = {},
				z = {},
			},
		}

		for key in pairs(pointLightInfo.offsets) do
			for i = 1, love.math.random(2, 5) do
				pointLightInfo.offsets[key][i] = love.math.random()
			end
		end

		local pointLight = scene:newLight(PointLight)
		pointLight:setAttenuation(love.math.random(1, 3))

		pointLightInfo.light = pointLight
		table.insert(pointLights, pointLightInfo)
	end

	local pointLight = scene:newLight(PointLight)
	pointLight:setAttenuation(50)
	pointLight:setPosition(Vector3(-2.3, -2.4, 2))

	local camera = ArcballCamera()
	camera:setSize(love.graphics.getDimensions())
	camera:setFOV(math.rad(65.3))

	scene:setCamera(camera)
	scene:getPipeline(LightPipeline):loadDefaultShaders()

	demo.renderer = renderer
	demo.scene = scene
	demo.camera = camera
	demo.directionalLight = directionalLight
	demo.pointLights = pointLights
end

demo.isPanning = false
demo.isRotating = false
demo.isElevating = false

function demo.mousepressed(x, y, button)
	if button == 1 then
		demo.isPanning = true
	elseif button == 2 then
		demo.isRotating = true
	elseif button == 3 then
		demo.isElevating = true
	end
end

function demo.mousemoved(_, _, dx, dy)
	if demo.isPanning then
		local position = demo.camera:getTranslation()
		local newPosition = position:add(Vector3(dx / 64, 0, dy / 64))
		demo.camera:setTranslation(newPosition)
	end

	if demo.isRotating then
		local rotation = demo.camera:getRotation()
		local xRotation =
			Quaternion.fromAxisAngle(Vector3.UNIT_X, dy / 256 * math.pi)
		local yRotation =
			Quaternion.fromAxisAngle(Vector3.UNIT_Y, -dx / 256 * math.pi)
		demo.camera:setRotation(yRotation:product(rotation):product(xRotation))
	end

	if demo.isElevating then
		local position = demo.camera:getTranslation()
		local newPosition = position:add(Vector3(0, dy / 64, 0))
		demo.camera:setTranslation(newPosition)
	end
end

function demo.mousereleased(x, y, button)
	if button == 1 then
		demo.isPanning = false
	elseif button == 2 then
		demo.isRotating = false
	elseif button == 3 then
		demo.isElevating = false
	end
end

function demo.update()
	demo.directionalLight:setDirection(
		Vector3(
			math.cos(love.timer.getTime()),
			-4,
			math.sin(love.timer.getTime())
		)
	)

	for _, pointLightInfo in ipairs(demo.pointLights) do
		local position = Vector3(1, 1, 1)

		for key, value in pairs(pointLightInfo.offsets) do
			for i = 1, #value do
				position[key] = position[key]
					* math.sin(
						love.timer.getTime() * (math.pi * value[i]) * (1 / 16)
					)
			end
		end

		pointLightInfo.light:setPosition(position:scale(10))
	end

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

	for i = 1, #demo.pointLights do
		local position = demo.camera:project(
			demo.pointLights[i].light:getPosition(),
			_position
		)
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
end

return demo
