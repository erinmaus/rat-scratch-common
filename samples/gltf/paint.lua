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
local ShaderPreprocessor = require("rat-scratch-graphics").ShaderPreprocessor
local Point = require("rat-scratch-math").Geometry2D.Point
local Mesh = require("rat-scratch-graphics").Graphics3D.Mesh
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat

local list = require("samples.common.list")
local demo = {}

demo.zoom = 10
demo.isPainting = false
demo.isDragging = false
demo.verticalRotation = 0
demo.horizontalRotation = 0
demo.textureOverrides = {}

function demo.load()
	demo.gltfs = {}

	list.recurse("samples/assets/gltf", function(path)
		if path:match(".*%.glb$") or path:match(".*%.gltf") then
			table.insert(demo.gltfs, path)
		end
	end)

	demo.paintShader = ShaderPreprocessor.newComputeShader(
		"samples/assets/shaders/Paint/Paint.compute.glsl",
		{
			rootPath = "/rat-scratch-graphics/Shaders",
		}
	)

	demo.simpleShader = ShaderPreprocessor.newShader(
		"samples/assets/shaders/SimpleModel/SimpleModel.frag.glsl",
		"samples/assets/shaders/SimpleModel/SimpleModel.vert.glsl",
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
				demo.gltf.animator = Animator(model)
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
		demo.isPainting = true
	elseif button == 3 then
		demo.isDragging = true
	end
end

function demo.mousereleased(x, y, button)
	if button == 2 then
		demo.isPainting = false
	elseif button == 3 then
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

function demo.getRays(x, y, radius)
	local view = demo.getView()
	local projection = demo.getProjection()
	local projectionView = projection * view
	local inverseProjectionView = projectionView:inverse()
	local viewportWidth, viewportHeight = love.graphics.getDimensions()

	local result = {}
	local halfRadius = -(radius / 2)
	for i = 1, radius do
		for j = 1, radius do
			local rx = x + halfRadius + (i - 1)
			local ry = y + halfRadius + (j - 1)

			local distance = Point.distance(rx, ry, x, y)
			if distance <= radius then
				local v1 = Transform.unproject(
					inverseProjectionView,
					Vector3(rx, ry, 0),
					0,
					0,
					viewportWidth,
					viewportHeight
				)
				local v2 = Transform.unproject(
					inverseProjectionView,
					Vector3(rx, ry, 0.05),
					0,
					0,
					viewportWidth,
					viewportHeight
				)
				local origin = v1
				local direction = v1:direction(v2)

				table.insert(result, {
					origin.x,
					origin.y,
					origin.z,
					direction.x,
					direction.y,
					direction.z,
				})
			end
		end
	end

	return result
end

local RAY_FORMAT = {
	{ location = 0, name = "origin", format = "floatvec3" },
	{ location = 1, name = "direction", format = "floatvec3" },
}

local RAY_INFO_FORMAT = {
	{ location = 0, name = "count", format = "uint32" },
}

local RAY_HITS_FORMAT = {
	{ location = 0, name = "hit", format = "uint32" },
	{ location = 1, name = "ray", format = "uint32" },
	{ location = 2, name = "worldCoordinate", format = "floatvec3" },
	{ location = 3, name = "textureCoordinate", format = "floatvec2" },
	{ location = 4, name = "textureCoordinateA", format = "floatvec2" },
	{ location = 5, name = "textureCoordinateB", format = "floatvec2" },
	{ location = 6, name = "textureCoordinateC", format = "floatvec2" },
	{ location = 7, name = "worldCoordinateA", format = "floatvec3" },
	{ location = 8, name = "worldCoordinateB", format = "floatvec3" },
	{ location = 9, name = "worldCoordinateC", format = "floatvec3" },
}

demo.pendingPaints = {}

--- @param mesh RatScratch.Graphics.Graphics3D.Mesh
--- @param x number
--- @param y number
function demo.beginPaint(transform, mesh, x, y)
	local rays = demo.getRays(x, y, 1)

	local raysBuffer =
		love.graphics.newBuffer(RAY_FORMAT, #rays, { shaderstorage = true })
	raysBuffer:setArrayData(rays)

	local hits = love.graphics.newBuffer(
		RAY_HITS_FORMAT,
		#rays * 8,
		{ shaderstorage = true }
	)
	local infoBuffer =
		love.graphics.newBuffer(RAY_INFO_FORMAT, 1, { shaderstorage = true })

	local skinnedVertexBuffer = mesh:getBufferByRole("compute_output")
	local staticVertexBuffer = mesh:getBufferByRole("static")
	local indexBuffer = mesh:getIndexBuffer()

	local triangleCount = indexBuffer:getElementCount() / 3
	local rayCount = #rays
	local rayHitCount = hits:getElementCount()

	demo.paintShader:send("rat_SkinnedVerticesBuffer", skinnedVertexBuffer)
	demo.paintShader:send("rat_StaticVerticesBuffer", staticVertexBuffer)
	demo.paintShader:send("rat_IndicesBuffer", indexBuffer)
	demo.paintShader:send("rat_TriangleCount", triangleCount)
	demo.paintShader:send("rat_RayBuffer", raysBuffer)
	demo.paintShader:send("rat_RayCount", rayCount)
	demo.paintShader:send("rat_RayHitInfoBuffer", infoBuffer)
	demo.paintShader:send("rat_RayHitsBuffer", hits)
	demo.paintShader:send("rat_RayHitCount", rayHitCount)
	demo.paintShader:send("rat_WorldMatrix", transform)

	local x, y = demo.paintShader:getLocalThreadgroupSize()

	love.graphics.dispatchThreadgroups(
		demo.paintShader,
		math.max(math.ceil(triangleCount / x), 1),
		math.max(math.ceil(rayCount / y), 1)
	)

	table.insert(demo.pendingPaints, 1, {
		mesh = mesh,
		info = love.graphics.readbackBufferAsync(infoBuffer),
		hits = love.graphics.readbackBufferAsync(hits),
	})
end

function demo.getCanvas(texture)
	local canvas = demo.textureOverrides[texture]
	if canvas then
		return canvas
	end

	canvas = love.graphics.newCanvas(texture:getWidth(), texture:getHeight())
	demo.textureOverrides[texture] = canvas

	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	love.graphics.draw(texture)
	love.graphics.pop()

	return canvas
end

function demo.endPaint(mesh, info, hits)
	--- @cast mesh RatScratch.Graphics.Graphics3D.Mesh
	local canvas = demo.getCanvas(mesh:getMaterial():getTexture())

	local stride = BufferFormat.getFormatStride(RAY_HITS_FORMAT)
	local textureCoordinateOffset =
		BufferFormat.getFormatByteOffset(RAY_HITS_FORMAT, "textureCoordinate")
	local textureCoordinatTriangleOffset =
		BufferFormat.getFormatByteOffset(RAY_HITS_FORMAT, "textureCoordinateA")
	local w, h = canvas:getWidth(), canvas:getHeight()

	love.graphics.push("all")
	love.graphics.setColor(0, 0, 0, 0.25)
	love.graphics.setCanvas({ canvas, stencil = true })
	local count = info:getBufferData():getUInt32(0)
	for i = 1, count do
		local offset = stride * (i - 1)
		local s, t = hits:getBufferData()
			:getFloat(offset + textureCoordinateOffset, 2)
		local s1, t1, s2, t2, s3, t3 =
			hits:getBufferData()
				:getFloat(offset + textureCoordinatTriangleOffset, 6)

		local x1, y1 = s1 * w, t1 * h
		local x2, y2 = s2 * w, t2 * h
		local x3, y3 = s3 * w, t3 * h

		love.graphics.setStencilMode("draw", 1)
		love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3)

		love.graphics.setStencilMode("test", 1)
		love.graphics.circle("fill", s * w, t * h, 8)

		love.graphics.setStencilMode("off")
	end
	love.graphics.pop()
end

function demo.mousemoved(x, y, dx, dy)
	if demo.isDragging then
		local width, height = love.graphics.getDimensions()

		dx = dx / width * math.pi
		dy = dy / height * math.pi

		demo.verticalRotation = demo.verticalRotation + dx
		demo.horizontalRotation = demo.horizontalRotation - dy
	elseif demo.isPainting then
		if demo.gltf then
			local mesh = demo.gltf.model:getMesh(1)
			demo.beginPaint(demo.gltf.model:getTransform(), mesh, x, y)
		end
	end
end

function demo.update(deltaTime)
	if demo.gltf and demo.gltf.animator and demo.gltf.processor then
		demo.gltf.animator:update(deltaTime)
		demo.gltf.processor:skin(demo.gltf.animator)
	end

	for i = #demo.pendingPaints, 1, -1 do
		local mesh = demo.pendingPaints[i].mesh
		local info = demo.pendingPaints[i].info
		local hits = demo.pendingPaints[i].hits

		if
			(info:hasError() or info:isComplete())
			and (hits:hasError() or hits:isComplete())
		then
			demo.endPaint(mesh, info, hits)
			table.remove(demo.pendingPaints, i)
		end
	end
end

function demo.drawGLTF()
	local model = demo.gltf.scene:getModel(1)
	for i = 1, model:getMeshCount() do
		local mesh = model:getMesh(i)
		local material = mesh:getMaterial()

		love.graphics.push("all")

		local projection = demo.getProjection()
		local camera = demo.getView()

		love.graphics.setDepthMode("lequal", true)
		love.graphics.setProjection(projection)
		love.graphics.applyTransform(camera)
		love.graphics.applyTransform(model:getTransform())

		local loveMesh = mesh:getMesh()
		if material and material:getTexture() then
			local texture = material:getTexture()
			local canvas = demo.textureOverrides[texture]
			loveMesh:setTexture(canvas or texture)
		end

		if material and material:getColor() then
			love.graphics.setColor(material:getColor())
		end

		love.graphics.setShader(demo.simpleShader)
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
