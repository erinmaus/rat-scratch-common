local GLTF = require("rat-scratch-gltf")
local Scene = require("rat-scratch-graphics").Graphics3D.Scene
local Animator = require("rat-scratch-graphics").Graphics3D.Animator
local Transform = require("rat-scratch-math").Transform
local Vector3 = require("rat-scratch-math").Vector3
local Common = require("rat-scratch-math").Common
local Quaternion = require("rat-scratch-math").Quaternion
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local AnimationPipeline =
	require("rat-scratch-graphics.Pipeline3D.AnimationPipeline")
local ShaderPreprocessor = require("rat-scratch-graphics").ShaderPreprocessor

local demo = {}
demo.isPaused = false

local GRID_SIZE_X = 8
local GRID_SIZE_Y = 8
local GRID_SIZE_Z = 8
local SIZE = Vector3(512, 512, 512)
local INSTANCE_COUNT = (GRID_SIZE_X * 2 + 1)
	* (GRID_SIZE_Y * 2 + 1)
	* (GRID_SIZE_Z * 2 + 1)

local INSTANCE_FORMAT = {
	{ location = 0, name = "worldMatrix", format = "floatmat4x4" },
	{ location = 1, name = "boneIndexCount", format = "uint32vec2" },
}

function demo.load()
	local parser = GLTF.loadFromFilesystem("samples/assets/gltf/fox.glb")
	local sceneDefinition = parser:loadScene(1)
	local scene = Scene.fromDefinition(sceneDefinition, false)

	--- @type RatScratch.Graphics.Graphics3D.SkinnedModel
	--- @diagnostic disable-next-line: assign-type-mismatch
	local model = scene:getModel(1)

	demo.gltf = { scene = scene, model = model }

	demo.pipeline = AnimationPipeline()
	demo.pipeline:loadDefaultShaders()

	demo.pipeline:addSkeleton(model:getSkeleton())
	demo.pipeline:addAnimation(model:getAnimation(1), model:getSkeleton())
	demo.pipeline:addAnimation(model:getAnimation(2), model:getSkeleton())
	demo.pipeline:addAnimation(model:getAnimation(3), model:getSkeleton())

	demo.shader = ShaderPreprocessor.newShader(
		"samples/assets/shaders/InstancedSkinnedModel/InstancedSkinnedModel.frag.glsl",
		"samples/assets/shaders/InstancedSkinnedModel/InstancedSkinnedModel.vert.glsl",
		{
			rootPath = "/rat-scratch-graphics/Shaders",
		}
	)

	demo.animators = {}
	for i = -GRID_SIZE_X, GRID_SIZE_X do
		for j = -GRID_SIZE_Y, GRID_SIZE_Y do
			for k = -GRID_SIZE_Z, GRID_SIZE_Z do
				local animator = Animator(model)
				demo.pipeline:addAnimator(animator)

				animator:play(
					love.math.random(model:getAnimationCount()),
					"main",
					{ looping = true, time = love.math.random() }
				)

				table.insert(demo.animators, animator)
			end
		end
	end

	local instanceData = {}
	local index = 1
	for i = -GRID_SIZE_X, GRID_SIZE_X do
		for j = -GRID_SIZE_Y, GRID_SIZE_Y do
			for k = -GRID_SIZE_Z, GRID_SIZE_Z do
				local cellIndex = Vector3(i / 2, j / 2, k / 2)
				local scale = Vector3.ONE:divide(SIZE)
				local transform = model:getTransform()
					* Transform.compose(cellIndex, Quaternion.IDENTITY, scale)
				local transposedTransform =
					Transform.transposeTransform(transform)

				Table.append(instanceData, transposedTransform:getMatrix())

				local animatorIndex, animatorCount =
					demo.pipeline:getAnimatorBoneIndexCount(
						demo.animators[index]
					)
				Table.append(instanceData, animatorIndex - 1, animatorCount)

				index = index + 1
			end
		end
	end

	demo.instanceBuffer = love.graphics.newBuffer(
		INSTANCE_FORMAT,
		INSTANCE_COUNT,
		{ shaderstorage = true }
	)
	demo.instanceBuffer:setArrayData(instanceData)
end

function demo.keypressed(key, _, isRepeat)
	if isRepeat then
		return
	end

	if key == "p" then
		demo.isPaused = not demo.isPaused
	end
end

function demo.update(deltaTime)
	if not demo.isPaused then
		local before = love.timer.getTime()
		for _, animator in ipairs(demo.animators) do
			animator:updateTime(deltaTime)
		end
		local after = love.timer.getTime()
		demo.animationUpdateDelta = (after - before) * 1000
	else
		demo.animationUpdateDelta = 0
	end

	do
		local before = love.timer.getTime()
		demo.pipeline:update()
		local after = love.timer.getTime()
		demo.pipelineUpdateDelta = (after - before) * 1000
	end
end

function demo.draw()
	local model = demo.gltf.scene:getModel(1)
	for i = 1, model:getMeshCount() do
		local mesh = model:getMesh(i)
		local material = mesh:getMaterial()

		love.graphics.push("all")

		local camera
		do
			local mx = love.mouse.getPosition()
			local delta = mx / love.graphics.getWidth()
			local angle = Common.lerp(-math.pi, math.pi, delta)

			camera = Transform.makeRotationTransform(
				Quaternion.fromAxisAngle(Vector3.UNIT_Y, angle)
			)
		end

		local scale
		do
			local _, my = love.mouse.getPosition()
			local delta = Common.saturate((my - 32) / love.graphics.getHeight())
			scale = Common.lerp(
				0.25,
				math.max(GRID_SIZE_X, GRID_SIZE_Y, GRID_SIZE_Z) * 2,
				delta ^ 2
			)
		end

		local projection = Transform.makePerspectiveTransform(
			math.rad(45),
			love.graphics.getWidth() / love.graphics.getHeight(),
			0.1,
			1000
		)

		camera = Transform.makeTranslationTransform(Vector3(0, 0, -scale))
			* camera

		love.graphics.setDepthMode("lequal", true)
		love.graphics.setProjection(projection)
		love.graphics.applyTransform(camera)

		local loveMesh = mesh:getMesh()
		if material and material:getTexture() then
			loveMesh:setTexture(material:getTexture())
		end

		if material and material:getColor() then
			love.graphics.setColor(material:getColor())
		end

		love.graphics.setShader(demo.shader)
		demo.shader:send("rat_MeshInstancesBuffer", demo.instanceBuffer)
		demo.shader:send(
			"rat_MeshInstanceBoneTransformsBuffer",
			demo.pipeline:getBoneTransforms()
		)

		love.graphics.drawInstanced(loveMesh, INSTANCE_COUNT)

		love.graphics.pop()
	end

	local width, height = love.graphics.getDimensions()
	love.graphics.printf(
		("frame: %.2f ms, animation: %.2f ms, pipeline: %.2f ms (%d entities)"):format(
			love.timer.getAverageDelta() * 1000,
			demo.animationUpdateDelta or 0,
			demo.pipelineUpdateDelta or 0,
			#demo.animators
		),
		0,
		height - 16,
		width - 16,
		"right"
	)
end

return demo
