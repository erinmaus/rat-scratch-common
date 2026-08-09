local GLTF = require("rat-scratch-gltf")
local Scene = require("rat-scratch-graphics").Graphics3D.Scene
local Mesh = require("rat-scratch-graphics").Graphics3D.Mesh
local Transform = require("rat-scratch-math").Transform
local Vector3 = require("rat-scratch-math").Vector3
local Common = require("rat-scratch-math").Common
local Quaternion = require("rat-scratch-math").Quaternion
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local ClusteredMesh = require("rat-scratch-graphics.Pipeline3D.ClusteredMesh")

local demo = {}

function demo.load()
	local parser = GLTF.loadFromFilesystem("samples/assets/gltf/avocado.glb")
	local sceneDefinition = parser:loadScene(1)
	local scene = Scene.fromDefinition(sceneDefinition, false)

	--- @diagnostic disable-next-line: assign-type-mismatch
	local model = scene:getModel(1)
	demo.gltf = { scene = scene, model = model }

	local clusteredMesh = ClusteredMesh(
		sceneDefinition.models[1].meshes[1],
		{ maxTriangles = 32 }
	)
	local clusteredMeshDefinition = clusteredMesh:getDefinition()

	local indexBuffers = {}
	for _, cluster in ipairs(clusteredMeshDefinition.clusters) do
		local indexBuffer = love.graphics.newBuffer(
			Mesh.INDEX_FORMAT,
			#cluster,
			{ index = true }
		)
		indexBuffer:setArrayData(cluster)

		table.insert(indexBuffers, indexBuffer)
	end

	demo.indices = indexBuffers
	demo.currentIndexBuffer = 1
	demo.useDefaultIndexBuffer = false
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
			scale = Common.lerp(0.15, 0.25, delta ^ 2)
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

		if demo.useDefaultIndexBuffer then
			for i = 1, #demo.indices do
				loveMesh:setIndexBuffer(demo.indices[i])
				love.graphics.draw(loveMesh)
			end
		else
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
