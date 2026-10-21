local PipelineRuntime = require("rat-scratch-pipeline").PipelineRuntime
local ResourceLoader = require("rat-scratch-resource").ResourceLoader
local Scene = require("rat-scratch-pipeline").Scene
local PipelineRenderer = require("rat-scratch-pipeline").PipelineRenderer
local AmbientLight = require("rat-scratch-pipeline").AmbientLight
local DirectionalLight = require("rat-scratch-pipeline").DirectionalLight
local Vector3 = require("rat-scratch-math").Vector3
local Quaternion = require("rat-scratch-math").Quaternion
local LightPipeline = require("rat-scratch-pipeline").LightPipeline
local GLTF = require("rat-scratch-gltf")
local ExtendedScene = require("rat-scratch-pipeline-tools").Model.ExtendedScene
local PipelineConfig = require("rat-scratch-pipeline").PipelineConfig
local GammaColor = require("rat-scratch-graphics").GammaColor
local PointLight = require("rat-scratch-pipeline").PointLight
local ResourceEvent = require("rat-scratch-resource").ResourceEvent
local Camera = require("rat-scratch-pipeline").Camera
local ArcballCameraView = require("rat-scratch-pipeline").ArcballCameraView
local ShadowRenderPass = require("rat-scratch-pipeline").ShadowRenderPass
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local IndirectDraw = require("rat-scratch-pipeline").IndirectDraw
local ForwardRendererPass = require("rat-scratch-pipeline").ForwardRendererPass
local Table = require("rat-scratch-common").Table
local ReflectionRenderPass =
	require("rat-scratch-pipeline").ReflectionRenderPass
local ReflectionProbe = require("rat-scratch-pipeline").ReflectionProbe
local ReflectionProbePipeline =
	require("rat-scratch-pipeline.ReflectionProbePipeline")
local PerspectiveFOVCameraProjection =
	require("rat-scratch-pipeline").PerspectiveFOVCameraProjection
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

	--ResourceLoader.toggleDebug(true)

	local pipelineRuntime = PipelineRuntime.loadDefault()
	demo.runtime = pipelineRuntime

	local renderer = PipelineRenderer(pipelineRuntime)
	local world = renderer:getWorld()
	local scene = Scene(world)
	local object = world:newStaticObject()
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

	demo.reflectionProbes = {}
	demo.minBounds, demo.maxBounds = Vector3(), Vector3()

	world:getPipeline(AnimationPipeline):loadDefaultShaders()

	local ambientLight = scene:newLight(AmbientLight)
	ambientLight:setAmbience(0.4)
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
		pointLight:setIsShadowCaster(true)
		pointLight:setAttenuation(love.math.random(5, 10))

		pointLightInfo.light = pointLight
		table.insert(pointLights, pointLightInfo)
	end

	demo.projection = PerspectiveFOVCameraProjection()
	demo.projection:setSize(love.graphics.getDimensions())
	demo.projection:setFOV(math.rad(65.3))

	demo.view = ArcballCameraView()
	demo.view:setTranslation(Vector3(0, 4, 0))

	local camera = Camera(demo.projection, demo.view)
	demo.camera = camera

	scene:setCamera(camera)
	scene:getPipeline(LightPipeline):loadDefaultShaders()
	scene:getPipeline(ReflectionProbePipeline):loadDefaultShaders()

	demo.runtime = pipelineRuntime
	demo.renderer = renderer
	demo.world = world
	demo.scene = scene
	demo.directionalLight = directionalLight
	demo.pointLights = pointLights
	demo.cullResult = scene:newCullResult()
	demo.shadowRenderPass = ShadowRenderPass()
	demo.shadowRenderPass:attach(
		demo.runtime:getDefaultQualityPreset(),
		demo.world,
		demo.scene
	)

	demo.reflectionRenderPass = ReflectionRenderPass()
	demo.reflectionRenderPass:addDependency(demo.shadowRenderPass)
	demo.reflectionRenderPass:attach(
		demo.runtime:getDefaultQualityPreset(),
		demo.world,
		demo.scene
	)

	demo.forwardRenderPass = ForwardRendererPass()
	demo.forwardRenderPass:addDependency(demo.shadowRenderPass)
	demo.forwardRenderPass:addDependency(demo.reflectionRenderPass)
	demo.forwardRenderPass:attach(
		demo.runtime:getDefaultQualityPreset(),
		demo.world,
		demo.scene
	)

	demo.colorCanvas = love.graphics.newTexture(
		love.graphics.getWidth(),
		love.graphics.getHeight(),
		1,
		{ canvas = true, format = "srgba8" }
	)
	demo.depthCanvas = love.graphics.newTexture(
		love.graphics.getWidth(),
		love.graphics.getHeight(),
		1,
		{ readable = true, canvas = true, format = "depth32f" }
	)

	demo.instancedDraws = { 0, 0, total = 0 }

	demo.centerProbe = ReflectionProbe()
	demo.centerProbe:setFar(50)
	demo.centerProbe:setRadius(25)
	demo.centerProbe:setRadiusFalloff(30)
	demo.centerProbe:setIsRealtime(true)
	demo.centerProbe:setPosition(Vector3(0, 5, 0))
	demo.scene:getPipeline(ReflectionProbePipeline):add(demo.centerProbe)
end

demo.isKeyboard = false
demo.isMouse = false
demo.isPanning = false
demo.isRotating = false
demo.isElevating = false

function demo.keypressed(key)
	if demo.isMouse or demo.isKeyboard then
		return
	end

	if key == "1" then
		demo.isPanning = true
		demo.isKeyboard = true
	elseif key == "2" then
		demo.isRotating = true
		demo.isKeyboard = true
	elseif key == "3" then
		demo.isElevating = true
		demo.isKeyboard = true
	end
end

function demo.keyreleased(key)
	if key == "1" and demo.isPanning then
		demo.isPanning = false
		demo.isKeyboard = false
	elseif key == "2" and demo.isRotating then
		demo.isRotating = false
		demo.isKeyboard = false
	elseif key == "3" and demo.isElevating then
		demo.isElevating = false
		demo.isKeyboard = false
	end
end

function demo.mousepressed(x, y, button)
	if demo.isMouse or demo.isKeyboard then
		return
	end

	if button == 1 and demo.isPanning then
		demo.isPanning = false
		demo.isMouse = false
	elseif button == 2 and demo.isRotating then
		demo.isRotating = false
		demo.isMouse = false
	elseif button == 3 and demo.isElevating then
		demo.isElevating = false
		demo.isMouse = false
	end
end

function demo.mousemoved(_, _, dx, dy)
	if demo.isPanning then
		local position = demo.camera:getView():getTranslation()
		local newPosition = position:add(Vector3(dx / 64, 0, dy / 64))
		demo.camera:getView():setTranslation(newPosition)
	end

	if demo.isRotating then
		local rotation = demo.camera:getView():getRotation()
		local xRotation =
			Quaternion.fromAxisAngle(Vector3.UNIT_X, dy / 256 * math.pi)
		local yRotation =
			Quaternion.fromAxisAngle(Vector3.UNIT_Y, -dx / 256 * math.pi)
		demo.camera
			:getView()
			:setRotation(yRotation:product(rotation):product(xRotation))
	end

	if demo.isElevating then
		local position = demo.camera:getView():getTranslation()
		local newPosition = position:add(Vector3(0, dy / 64, 0))
		demo.camera:getView():setTranslation(newPosition)
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

		local minY = Vector3(-math.huge, 0.5, -math.huge)
		pointLightInfo.light:setPosition(position:scale(5):max(minY))
	end

	ResourceLoader.update()
	demo.renderer:update()
	demo.scene:update()
	demo.scene:flush()

	if not demo.readbacks then
		demo.readbacks = {
			love.graphics.readbackBufferAsync(
				demo.forwardRenderPass:getCullResult():getIndirectBuffer()
			),
			love.graphics.readbackBufferAsync(
				demo.shadowRenderPass:getCullResult():getIndirectBuffer()
			),
		}
	else
		local allDone = true
		for _, readback in ipairs(demo.readbacks) do
			if not readback:isComplete() then
				allDone = false
				break
			end
		end

		if allDone then
			demo.instancedDraws = {}
			local buffer = {}

			local count = 0
			for i, readback in ipairs(demo.readbacks) do
				BufferFormat.copyFromByteDataToFlatTable(
					IndirectDraw.INDIRECT_DRAW_FORMAT,
					0,
					1,
					1,
					readback:getBufferData(),
					buffer
				)

				local c, o =
					IndirectDraw.INDIRECT_DRAW_FORMAT_INSTANCE:getCountOffset(
						"instanceCount"
					)

				local value = buffer[o]
				demo.instancedDraws[i] = value
				count = count + value
			end

			demo.readbacks = nil
			demo.instancedDraws.total = count
		end
	end

	local minBounds, maxBounds = demo.scene:getStaticBounds()
	if
		not (
			minBounds:equal(demo.minBounds) and maxBounds:equal(demo.maxBounds)
		)
	then
		for _, probe in ipairs(demo.reflectionProbes) do
			demo.scene:getPipeline(ReflectionProbePipeline):remove(probe)
		end
		Table.clear(demo.reflectionProbes)

		if false then
		local GRID_SIZE = 10
		local GRID_OVERLAP = 2
		local w = maxBounds.x - minBounds.x
		local h = maxBounds.z - minBounds.z
		local o = math.max(w / GRID_SIZE, h / GRID_SIZE)
		for x = minBounds.x + 5, maxBounds.x - 5, GRID_SIZE do
			for z = minBounds.z + 5, maxBounds.z - 5, GRID_SIZE do
				--for i = 1, GRID_SIZE do`
				--for j = 1, GRID_SIZE do
				-- local x = w * ((i - 1) / (GRID_SIZE - 1))
				-- local z = h * ((j - 1) / (GRID_SIZE - 1))

				for _, y in ipairs({ 2, 6 }) do
					local probe = ReflectionProbe()
					probe:setRadius(GRID_SIZE)
					probe:setRadiusFalloff(GRID_SIZE + GRID_OVERLAP)
					probe:setFar(50)
					probe:setPosition(Vector3(x, y, z))
					print(">>> xyz", x, y, z)
					probe:setIsRealtime(true)

					demo.scene:getPipeline(ReflectionProbePipeline):add(probe)

					table.insert(demo.reflectionProbes, probe)
				end
			end
		end

		print("???", #demo.reflectionProbes) end

		demo.minBounds:from(minBounds:get())
		demo.maxBounds:from(maxBounds:get())

		print(">>> center", maxBounds:subtract(minBounds):get())
	end

	demo.centerProbe:setPosition(maxBounds:subtract(minBounds):scale(0.5):add(minBounds))
	demo.centerProbe:setFalloffBounds(maxBounds:subtract(minBounds):scale(0.5):negate(), maxBounds:subtract(minBounds):scale(0.5))
	demo.centerProbe:setBounds(maxBounds:subtract(minBounds):scale(0.45):negate(), maxBounds:subtract(minBounds):scale(0.45))
end

local function prettyNumber(value)
	local _, _, minus, int, fraction =
		tostring(value):find("([-]?)(%d+)([.]?%d*)")
	int = int:reverse():gsub("(%d%d%d)", "%1,")

	return minus .. int:reverse():gsub("^,", "") .. fraction
end

local _position = Vector3()
function demo.draw()
	love.graphics.push("all")
	love.graphics.setDepthMode("lequal", true)

	demo.renderer:cull(
		demo.runtime:getDefaultQualityPreset(),
		demo.scene,
		demo.shadowRenderPass:getCullResult()
	)
	demo.renderer:draw(demo.shadowRenderPass)

	demo.renderer:cull(
		demo.runtime:getDefaultQualityPreset(),
		demo.scene,
		demo.reflectionRenderPass:getCullResult()
	)
	demo.renderer:draw(demo.reflectionRenderPass)

	demo.renderer:cull(
		demo.runtime:getDefaultQualityPreset(),
		demo.scene,
		demo.forwardRenderPass:getCullResult()
	)
	demo.renderer:draw(demo.forwardRenderPass)
	love.graphics.pop()

	love.graphics.drawLayer(
		demo.forwardRenderPass:getRenderBuffer():getCanvas(1),
		1
	)
	for i = 1, #demo.pointLights do
		local position = demo.camera:project(
			demo.pointLights[i].light:getPosition(),
			love.graphics.getWidth(),
			love.graphics.getHeight(),
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
			love.graphics.circle(
				"fill",
				position.x,
				love.graphics.getHeight() - position.y,
				8
			)
		end
	end

	local d = love.graphics.getStats()
	love.graphics.print(
		("draw calls = %d (%s [%s triangles] scene, %s [%s triangles] lights, %s [%s triangles] total)\ncanvas switches = %d\nframe time = %f ms (%d FPS)"):format(
			prettyNumber(d.drawcalls),
			prettyNumber(demo.instancedDraws[1]),
			prettyNumber(
				demo.instancedDraws[1]
					* demo.runtime
						:getConfig()
						:getMeshletFormat()
						:getTriangleCount()
			),
			prettyNumber(demo.instancedDraws[2]),
			prettyNumber(
				demo.instancedDraws[2]
					* demo.runtime
						:getConfig()
						:getMeshletFormat()
						:getTriangleCount()
			),
			prettyNumber(demo.instancedDraws.total),
			prettyNumber(
				demo.instancedDraws.total
					* demo.runtime
						:getConfig()
						:getMeshletFormat()
						:getTriangleCount()
			),
			d.canvasswitches,
			love.timer.getAverageDelta() * 1000,
			love.timer.getFPS()
		),
		8,
		8
	)
end

return demo
