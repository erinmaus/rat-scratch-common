local GLTF = require("rat-scratch-gltf")
local Scene = require("rat-scratch-graphics").Graphics3D.Scene
local Mesh = require("rat-scratch-graphics").Graphics3D.Mesh
local Transform = require("rat-scratch-math").Transform
local Vector3 = require("rat-scratch-math").Vector3
local Common = require("rat-scratch-math").Common
local Quaternion = require("rat-scratch-math").Quaternion
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local ExtendedModel = require("rat-scratch-pipeline-tools").Model.ExtendedModel
local PipelineConfig = require("rat-scratch-pipeline").PipelineConfig
local ShaderPreprocessor = require("rat-scratch-graphics.ShaderPreprocessor")
local ffi = require("ffi")

local demo = {}

local COLORS = {
	{ 1, 0, 0, 1 },
	{ 0, 1, 0, 1 },
	{ 0, 0, 1, 1 },
	{ 0, 1, 1, 1 },
	{ 1, 0, 1, 1 },
	{ 1, 1, 0, 1 },
	{ 1, 0, 0.5, 1 },
	{ 0.5, 0, 1, 1 },
	{ 1, 0.5, 0, 1 },
	{ 0.5, 1, 0, 1 },
	--{ 0, 1, 0.5, 1 },
	{ 0, 0.5, 1, 1 },
	{ 1, 1, 1, 1 },
}

function demo.load()
	local parser = GLTF.loadFromFilesystem("samples/assets/gltf/shoe.glb")

	local pipelineConfig = PipelineConfig.loadDefault()
	local extendedModel = ExtendedModel(parser, 0)
	extendedModel:build(pipelineConfig)

	local meshDefinitions = parser:loadMesh(0, {
		attributes = {
			static = {
				output = parser:getAttributes(),
				static = parser:getAttributes(),
			},
		},
	})
	local scene =
		Scene.fromDefinition({ models = { { meshes = meshDefinitions } } })
	demo.gltf = { scene = scene }

	local indexBuffers = {}
	local extendedMesh = extendedModel:getMesh(1)
	for i = 1, extendedMesh:getMeshletCount() do
		local meshlet = extendedMesh:getMeshlet(i)
		local indexData = meshlet:getIndexData()

		local indexBuffer = love.graphics.newBuffer(
			Mesh.INDEX_FORMAT,
			indexData:getSize() / ffi.sizeof("uint32_t"),
			{ index = true }
		)
		indexBuffer:setArrayData(indexData)

		table.insert(indexBuffers, indexBuffer)
	end

	demo.indices = indexBuffers
	demo.currentIndexBuffer = 1
	demo.useDefaultIndexBuffer = true
	demo.showTexture = true

	demo.simpleShader = ShaderPreprocessor.newShader(
		"samples/assets/shaders/Bump/Bump.frag.glsl",
		"samples/assets/shaders/Bump/Bump.vert.glsl",
		{
			rootPath = "/rat-scratch-graphics/Shaders",
		}
	)

	demo.lightDirection = Vector3()
end

function demo.keypressed(key, _, isRepeat)
	if isRepeat then
		return
	end

	if key == "n" then
		demo.currentIndexBuffer =
			Table.wrapIndex(demo.currentIndexBuffer + 1, #demo.indices)
		demo.useDefaultIndexBuffer = false
	elseif key == "a" then
		demo.useDefaultIndexBuffer = not demo.useDefaultIndexBuffer
	elseif key == "t" then
		demo.showTexture = not demo.showTexture
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
			scale = Common.lerp(0.5, 3, delta ^ 2)
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
		if material and material:getTexture() and demo.showTexture then
			loveMesh:setTexture(material:getTexture())
			love.graphics.setShader(demo.simpleShader)

			if material:getNormalTexture() then
				demo.simpleShader:send(
					"rat_NormalImage",
					material:getNormalTexture()
				)
			end

			demo.lightDirection
				:from(
					math.cos(love.timer.getTime()),
					0.25,
					math.sin(love.timer.getTime())
				)
				:normalize(demo.lightDirection)
			demo.simpleShader:send(
				"rat_LightDirection",
				{ demo.lightDirection:get() }
			)
		else
			loveMesh:setTexture()
		end

		if material and material:getColor() then
			love.graphics.setColor(material:getColor())
		end

		if demo.useDefaultIndexBuffer then
			for i = 1, #demo.indices do
				if not demo.showTexture then
					love.graphics.setColor(COLORS[Table.wrapIndex(i, #COLORS)])
				end

				loveMesh:setIndexBuffer(demo.indices[i])
				love.graphics.draw(loveMesh)
			end
		else
			if not demo.showTexture then
				love.graphics.setColor(
					COLORS[Table.wrapIndex(demo.currentIndexBuffer, #COLORS)]
				)
			end

			loveMesh:setIndexBuffer(demo.indices[demo.currentIndexBuffer])
			love.graphics.draw(loveMesh)
		end

		love.graphics.pop()
	end

	local width, height = love.graphics.getDimensions()
	love.graphics.printf(
		("frame: %.2f ms, index %d/%d"):format(
			love.timer.getAverageDelta() * 1000,
			demo.currentIndexBuffer,
			#demo.indices
		),
		0,
		height - 16,
		width - 16,
		"right"
	)
end

return demo
