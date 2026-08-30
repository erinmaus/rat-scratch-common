local GLTF = require("rat-scratch-gltf")
local Scene = require("rat-scratch-graphics").Graphics3D.Scene
local Animator = require("rat-scratch-graphics").Graphics3D.Animator
local SkinnedModel = require("rat-scratch-graphics").Graphics3D.SkinnedModel
local SkinnedModelAnimatorProvider =
	require("rat-scratch-graphics").Graphics3D.SkinnedModelAnimatorProvider
local ModelProcessor = require("rat-scratch-graphics").Graphics3D.ModelProcessor
local Transform = require("rat-scratch-math").Transform
local Vector3 = require("rat-scratch-math").Vector3
local Quaternion = require("rat-scratch-math").Quaternion
local Object = require("rat-scratch-common").Object
local ShaderPreprocessor = require("rat-scratch-graphics").ShaderPreprocessor

local list = require("samples.common.list")
local demo = {}

demo.zoom = 10
demo.isDragging = false
demo.verticalRotation = 0
demo.horizontalRotation = 0
demo.enableCulling = false
demo.enableOIT = true

local A_BUFFER_FRAGMENT_FORMAT = {
	{ location = 0, name = "color", format = "floatvec4" },
	{ location = 1, name = "depth", format = "float" },
	{ location = 2, name = "blendMode", format = "uint32" },
	{ location = 3, name = "next", format = "int32" },
}

local ATOMIC_COUNTER_FORMAT = {
	{ location = 0, name = "counter", format = "uint32" },
}

local A_BUFFER_FORMAT = {
	{ location = 0, name = "pixel", format = "int32" },
}

local MAX_GLOBAL_FRAGMENTS = 4

function demo.load()
	demo.gltfs = {}

	list.recurse("samples/assets/gltf", function(path)
		if path:match(".*%.glb$") or path:match(".*%.gltf") then
			table.insert(demo.gltfs, path)
		end
	end)

	local width, height = love.graphics.getDimensions()
	demo.fragmentsBuffer = love.graphics.newBuffer(
		A_BUFFER_FRAGMENT_FORMAT,
		MAX_GLOBAL_FRAGMENTS * width * height,
		{ shaderstorage = true }
	)
	demo.counterBuffer = love.graphics.newBuffer(
		ATOMIC_COUNTER_FORMAT,
		1,
		{ shaderstorage = true }
	)
	demo.aBufferImage = love.graphics.newTexture(
		love.graphics.getWidth(),
		love.graphics.getHeight(),
		{ format = "r32i", computewrite = true }
	)
	demo.canvas = love.graphics.newTexture(
		width,
		height,
		{ format = "rgba8", canvas = true }
	)

	demo.renderShader = ShaderPreprocessor.newShader(
		"samples/assets/shaders/TestOIT/RenderFragment.frag.glsl",
		nil,
		{
			rootPath = "/rat-scratch-graphics/Shaders",
		}
	)

	demo.resolveShader = ShaderPreprocessor.newShader(
		"samples/assets/shaders/TestOIT/ResolveABuffer.frag.glsl",
		nil,
		{
			rootPath = "/rat-scratch-graphics/Shaders",
		}
	)

	demo.clearShader = ShaderPreprocessor.newComputeShader(
		"samples/assets/shaders/TestOIT/PrepareABuffer.compute.glsl",
		{
			rootPath = "/rat-scratch-graphics/Shaders",
		}
	)

	demo.clearShader = ShaderPreprocessor.newComputeShader(
		"samples/assets/shaders/TestOIT/PrepareABuffer.compute.glsl",
		{
			rootPath = "/rat-scratch-graphics/Shaders",
		}
	)
end

function demo.wheelmoved(x, y)
	demo.zoom = math.max(demo.zoom + y / 2, 0.25)
end

function demo.mousepressed(x, y, button)
	if button == 1 then
		if not demo.gltf then
			local index = list.click(demo.gltfs, x, y)

			local parser = GLTF.loadFromFilesystem(demo.gltfs[index])
			local sceneDefinition =
				parser:loadScene(1, { forceSkinning = true })

			local scene = Scene.fromDefinition(sceneDefinition, false)
			local model = scene:getModel(1)

			demo.gltf = { scene = scene, model = model }
			if Object.isDerived(SkinnedModel, model:getType()) then
				--- @cast model RatScratch.Graphics.Graphics3D.SkinnedModel
				demo.gltf.animator =
					Animator(SkinnedModelAnimatorProvider(model))
				demo.gltf.processor = ModelProcessor(model)

				demo.gltf.animations = {}
				for i = 1, model:getAnimationCount() do
					local animation = model:getAnimation(i)
					table.insert(
						demo.gltf.animations,
						animation:getName() ~= "" and animation:getName() or i
					)
				end
			end
		elseif demo.gltf.animations then
			local index = list.click(demo.gltf.animations, x, y)

			local animation = demo.gltf.animations[index]
			if animation then
				if demo.gltf.animationPlayback then
					demo.gltf.animator:stop(demo.gltf.animationPlayback)
				end

				demo.gltf.animationPlayback = demo.gltf.animator:play(
					animation,
					"main",
					{ looping = true }
				)
			end
		end
	elseif button == 2 then
		demo.isDragging = true
	end
end

function demo.mousereleased(x, y, button)
	if button == 2 then
		demo.isDragging = false
	end
end

function demo.getView()
	local yRotation =
		Quaternion.fromAxisAngle(Vector3.UNIT_Y, demo.verticalRotation)
	local xRotation =
		Quaternion.fromAxisAngle(Vector3.UNIT_X, demo.horizontalRotation)

	local rotation = yRotation:product(xRotation)

	local rotation = Transform.makeRotationTransform(rotation)
	local translation =
		Transform.makeTranslationTransform(Vector3(0, 0, demo.zoom))

	--- @type love.Transform
	local view = rotation * translation
	return view:inverse()
end

function demo.getProjection()
	return Transform.makePerspectiveTransform(
		math.rad(45),
		love.graphics.getWidth() / love.graphics.getHeight(),
		0.1,
		1000
	)
end

function demo.mousemoved(x, y, dx, dy)
	if demo.isDragging then
		local width, height = love.graphics.getDimensions()

		dx = dx / width * math.pi
		dy = dy / height * math.pi

		demo.verticalRotation = demo.verticalRotation + dx
		demo.horizontalRotation = demo.horizontalRotation - dy
	end
end

function demo.update(deltaTime)
	if demo.gltf and demo.gltf.animator and demo.gltf.processor then
		demo.gltf.animator:update(deltaTime)
		demo.gltf.processor:skin(demo.gltf.animator)
	end
end

function demo.keypressed(key, _, isRepeat)
	if isRepeat then
		return
	end

	if key == "a" then
		demo.enableOIT = not demo.enableOIT
	elseif key == "c" then
		demo.enableCulling = not demo.enableCulling
	end
end

function demo.dispatch(shader, x, y, z)
	x = x or 1
	y = y or 1
	z = z or 1

	local localX, localY, localZ = shader:getLocalThreadgroupSize()

	love.graphics.dispatchThreadgroups(
		shader,
		math.max(math.ceil(x / localX), 1),
		math.max(math.ceil(y / localY), 1),
		math.max(math.ceil(z / localZ), 1)
	)
end

function demo.drawGLTF()
	demo.counterBuffer:clear()

	local width, height = love.graphics.getDimensions()
	local bufferCount = width * height
	demo.clearShader:send("rat_ABufferImage", demo.aBufferImage)

	demo.dispatch(
		demo.clearShader,
		love.graphics.getWidth(),
		love.graphics.getHeight()
	)

	love.graphics.push("all")
	love.graphics.setFrontFaceWinding("cw")
	love.graphics.setCanvas({ demo.canvas, depthstencil = true })
	love.graphics.clear(0, 0, 0, 0)

	local model = demo.gltf.scene:getModel(1)
	for i = 1, model:getMeshCount() do
		local mesh = model:getMesh(i)
		local material = mesh:getMaterial()

		local projection = demo.getProjection()
		local camera = demo.getView()

		love.graphics.setDepthMode("lequal", true)
		love.graphics.setProjection(projection)
		love.graphics.origin()
		love.graphics.applyTransform(camera)
		love.graphics.applyTransform(model:getTransform())

		local loveMesh = mesh:getMesh()
		if material and material:getTexture() then
			local texture = material:getTexture()
			loveMesh:setTexture(texture)
		end

		local r, g, b, a = 1, 1, 1, 1
		if material and material:getColor() then
			r, g, b, a = material:getColor()
		end

		love.graphics.setColor(r, g, b, a * 0.5)

		if demo.enableOIT then
			love.graphics.setShader(demo.renderShader)
			demo.renderShader:send("rat_ABufferImage", demo.aBufferImage)
			demo.renderShader:send(
				"rat_ABufferFragmentsBuffer",
				demo.fragmentsBuffer
			)
			demo.renderShader:send(
				"rat_TransparentPixelCounterBuffer",
				demo.counterBuffer
			)
			demo.renderShader:send(
				"rat_ABufferFragmentsCount",
				demo.fragmentsBuffer:getElementCount()
			)
			demo.renderShader:send("rat_BlendMode", 0)
		end

		if demo.enableCulling then
			love.graphics.setMeshCullMode("back")
		else
			love.graphics.setMeshCullMode("none")
		end

		love.graphics.draw(loveMesh)
	end

	if demo.enableOIT then
		love.graphics.setShader(demo.resolveShader)
		demo.resolveShader:send("rat_ABufferImage", demo.aBufferImage)
		demo.resolveShader:send(
			"rat_ABufferFragmentsBuffer",
			demo.fragmentsBuffer
		)
	end

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setCanvas()
	love.graphics.origin()

	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(demo.canvas)

	love.graphics.pop()

	love.graphics.printf(
		("OIT = %s, Cull Mode = %s"):format(
			demo.enableOIT and "on" or "off",
			demo.enableCulling and "back" or "none"
		),
		0,
		love.graphics.getHeight() - love.graphics.getFont():getHeight() - 8,
		love.graphics.getWidth() - 8,
		"right"
	)
end

function demo.draw()
	if demo.gltf and demo.gltf.model then
		demo.drawGLTF()

		if demo.gltf.animations then
			list.draw(demo.gltf.animations)
		end
	else
		list.draw(demo.gltfs)
	end
end

return demo
