local GLTF = require("rat-scratch-gltf")
local Scene = require("rat-scratch-graphics").Graphics3D.Scene
local Animator = require("rat-scratch-graphics").Graphics3D.Animator
local SkinnedModel = require("rat-scratch-graphics").Graphics3D.SkinnedModel
local ModelProcessor = require("rat-scratch-graphics").Graphics3D.ModelProcessor
local Transform = require("rat-scratch-math").Transform
local Vector3 = require("rat-scratch-math").Vector3
local Common = require("rat-scratch-math").Common
local Quaternion = require("rat-scratch-math").Quaternion
local Object = require("rat-scratch-common").Object
local Table  = require("rat-scratch-common").Table

local list = require("samples.common.list")
local demo = {}

function demo.load()
	demo.gltfs = {}

	list.recurse("samples/assets/gltf", function(path)
		if path:match(".*%.glb$") or path:match(".*%.gltf") then
			table.insert(demo.gltfs, path)
		end
	end)
end

function demo.mousepressed(x, y, button)
	if button == 1 then
		if not demo.gltf then
			local index = list.click(demo.gltfs, x, y)

			local parser = GLTF.loadFromFilesystem(demo.gltfs[index])
			local sceneDefinition = parser:loadScene(1)
			local scene = Scene.fromDefinition(sceneDefinition, false)
			local model = scene:getModel(1)

			demo.gltf = { scene = scene, model = model }
			if Object.isDerived(SkinnedModel, model:getType()) then 
				--- @cast model RatScratch.Graphics.Graphics3D.SkinnedModel
				demo.gltf.animator = Animator(model)
				demo.gltf.processor = ModelProcessor(model)

				demo.gltf.animations = {}
				for i = 1, model:getAnimationCount() do
					local animation = model:getAnimation(i)
					table.insert(demo.gltf.animations, animation:getName() ~= "" and animation:getName() or i)
				end
			end
		elseif demo.gltf.animations then
			local index = list.click(demo.gltf.animations, x, y)

			local animation = demo.gltf.animations[index]
			if animation then
				if demo.gltf.animationPlayback then
					demo.gltf.animator:stop(demo.gltf.animationPlayback)
				end

				demo.gltf.animationPlayback =
					demo.gltf.animator:play(animation, "main", { looping = true })
			end
		end
	end
end

function demo.update(deltaTime)
	if demo.gltf and demo.gltf.animator and demo.gltf.processor then
		demo.gltf.animator:update(deltaTime)
		demo.gltf.processor:skin(demo.gltf.animator)
	end
end

function demo.drawGLTF()
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
			scale = Common.lerp(0.25, 400, delta ^ 2)
		end

		local projection = Transform.makePerspectiveTransform(
				math.rad(45),
				love.graphics.getWidth() / love.graphics.getHeight(),
				0.1,
				1000
			)

		camera = Transform.makeTranslationTransform(Vector3(0, 0, -scale)) * camera

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

		love.graphics.draw(loveMesh)

		love.graphics.pop()
	end
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
