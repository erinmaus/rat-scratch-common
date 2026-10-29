local ArcballCameraView = require("rat-scratch-pipeline").ArcballCameraView
local Camera = require("rat-scratch-pipeline").Camera
local Common = require("rat-scratch-math").Common
local CubeMap = require("rat-scratch-graphics").CubeMap
local LinearColor = require("rat-scratch-graphics").LinearColor
local PerspectiveFOVCameraProjection =
	require("rat-scratch-pipeline").PerspectiveFOVCameraProjection
local Quaternion = require("rat-scratch-math").Quaternion
local Vector3 = require("rat-scratch-math").Vector3
local demo = {}

demo.cubeMapIterations = 10
demo.cubeMapI = 3
demo.cubeMapCells = 8
demo.cubeMapSize = 256

local ITERATIONS = {
	-- top
	{
		s = {
			reverse = false,
			delta = true,
			size = false,
		},

		t = {
			reverse = false,
			delta = false,
			size = false,
		},
	},
	-- right
	{
		s = {
			reverse = false,
			delta = false,
			size = true,
		},

		t = {
			reverse = false,
			delta = true,
			size = false,
		},
	},
	-- bottom
	{
		s = {
			reverse = true,
			delta = true,
			size = false,
		},

		t = {
			reverse = false,
			delta = false,
			size = true,
		},
	},
	-- left
	{
		s = {
			reverse = false,
			delta = false,
			size = false,
		},

		t = {
			reverse = true,
			delta = true,
			size = false,
		},
	},
}

demo.isRotatingCamera = false
demo.isRotatingNormal = false
demo.rotationAxis = false

demo.normalRotationEulerAngles = Vector3()
demo.normalRotation = Quaternion()

function demo.keypressed(key, _, isRepeat)
	if isRepeat then
		return
	end

	if not (demo.isRotatingNormal or demo.isRotatingCamera) then
		if key == "x" then
			demo.isRotatingNormal = true
			demo.rotationAxis = "x"
		elseif key == "y" then
			demo.isRotatingNormal = true
			demo.rotationAxis = "y"
		elseif key == "z" then
			demo.isRotatingNormal = true
			demo.rotationAxis = "z"
		end
	end

	if not (demo.isRotatingCamera or demo.isRotatingCamera) then
		if key == "1" then
			demo.isRotatingCamera = true
		end
	end

	if key == "=" then
		demo.cubeMapI = math.min(demo.cubeMapI + 1, 8)
		demo.cubeMapCells = 2 ^ demo.cubeMapI
	elseif key == "-" then
		demo.cubeMapI = math.max(demo.cubeMapI - 1, 0)
		demo.cubeMapCells = 2 ^ demo.cubeMapI
	end

	if key == "space" then
		demo.normalRotationEulerAngles:from()
		demo.normalRotation:from()
	end
end

function demo.keyreleased(key)
	if demo.isRotatingNormal then
		if
			(key == "x" and demo.rotationAxis == "x")
			or (key == "y" and demo.rotationAxis == "y")
			or (key == "z" and demo.rotationAxis == "z")
		then
			demo.isRotatingNormal = false
			demo.rotationAxis = false
		end
	end

	if demo.isRotatingCamera then
		if key == "1" then
			demo.isRotatingCamera = false
		end
	end
end

function demo.mousemoved(_, _, dx, dy)
	if demo.isRotatingNormal then
		local delta
		if demo.rotationAxis == "x" then
			delta = dy / 256 * math.pi
		elseif demo.rotationAxis == "y" then
			delta = -dx / 256 * math.pi
		elseif demo.rotationAxis == "z" then
			delta = -dy / 256 * math.pi
		end

		if delta then
			demo.normalRotationEulerAngles[demo.rotationAxis] = demo.normalRotationEulerAngles[demo.rotationAxis]
				+ delta
			demo.normalRotation =
				Quaternion.fromEulerXYZ(demo.normalRotationEulerAngles:get())
					:normalize()
		end
	end

	if demo.isRotatingCamera then
		local rotation = demo.camera:getView():getRotation()
		local xRotation =
			Quaternion.fromAxisAngle(Vector3.UNIT_X, -dy / 256 * math.pi)
		local yRotation =
			Quaternion.fromAxisAngle(Vector3.UNIT_Y, -dx / 256 * math.pi)
		demo.camera
			:getView()
			:setRotation(yRotation:product(rotation):product(xRotation))
	end
end

local function getCubeMapLine(func, face, s1, t1, s2, t2)
	local points = {}
	for i = 1, demo.cubeMapIterations do
		local delta = (i - 1) / (demo.cubeMapIterations - 1)
		local s, t = Common.lerp(s1, s2, delta), Common.lerp(t1, t2, delta)

		local position = func(face, s, t)
		local projected =
			demo.camera:project(position, demo.cubeMapSize, demo.cubeMapSize)

		table.insert(
			points,
			projected.x + (love.graphics.getWidth() - demo.cubeMapSize) / 2
		)
		table.insert(
			points,
			(demo.cubeMapSize - projected.y)
				+ (love.graphics.getHeight() - demo.cubeMapSize) / 2
		)
	end
	return points
end

local function getCubeMapSideCellPoints(func, face, s, t)
	local c = 1 / demo.cubeMapCells

	local points = {}
	for _, iteration in ipairs(ITERATIONS) do
		for k = 1, demo.cubeMapIterations do
			local delta = (k - 1) / (demo.cubeMapIterations - 1)

			local d1 = iteration.s.reverse and (1 - delta) or delta
			local d2 = iteration.t.reverse and (1 - delta) or delta

			local sd = (c * d1) * (iteration.s.delta and 1 or 0)
			local ss = c * (iteration.s.size and 1 or 0)

			local td = (c * d2) * (iteration.t.delta and 1 or 0)
			local ts = c * (iteration.t.size and 1 or 0)

			local position = func(face, s + sd + ss, t + td + ts)

			local projected = demo.camera:project(
				position,
				demo.cubeMapSize,
				demo.cubeMapSize
			)

			table.insert(
				points,
				projected.x + (love.graphics.getWidth() - demo.cubeMapSize) / 2
			)
			table.insert(
				points,
				(demo.cubeMapSize - projected.y)
					+ (love.graphics.getHeight() - demo.cubeMapSize) / 2
			)
		end
	end

	return points
end

--- @param func fun(side: integer, s: number, t: number)
--- @param face integer
local function drawCubemapSide(func, face)
	for i = 1, demo.cubeMapCells do
		for j = 1, demo.cubeMapCells do
			local s = (i - 1) / demo.cubeMapCells
			local t = (j - 1) / demo.cubeMapCells

			local points = getCubeMapSideCellPoints(func, face, s, t)
			love.graphics.line(points)
		end
	end

	local normal =
		demo.normalRotation:transformVector(Vector3.POSITIVE_Z):normalize()
	local normalFace, s, t = CubeMap.getFaceTextureCoordinate(normal)
	if normalFace == face then
		local ms = s * demo.cubeMapCells
		local mt = t * demo.cubeMapCells
		local fs = math.floor(ms) / demo.cubeMapCells
		local ft = math.floor(mt) / demo.cubeMapCells

		love.graphics.polygon(
			"fill",
			getCubeMapSideCellPoints(func, face, fs, ft)
		)

		local p = func(face, s, t)
		p = demo.camera:project(p, demo.cubeMapSize, demo.cubeMapSize)
		p.x = p.x + (love.graphics.getWidth() - demo.cubeMapSize) / 2
		p.y = (demo.cubeMapSize - p.y)
			+ (love.graphics.getHeight() - demo.cubeMapSize) / 2

		love.graphics.push("all")

		love.graphics.rectangle("fill", p.x - 8, p.y - 8, 16, 16)

		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.rectangle("line", p.x - 8, p.y - 8, 16, 16)

		local ds = normal:dot(CubeMap.TANGENTS[face])
		local dt = normal:dot(CubeMap.BITANGENTS[face])

		local l = math.sqrt(ds ^ 2 + dt ^ 2)
		if l > 0 then
			ds, dt = ds / l, dt / l
		end

		local bs = (ds > 0 and math.ceil(ms) or math.floor(ms))
			/ demo.cubeMapCells
		local bt = (dt > 0 and math.ceil(mt) or math.floor(mt))
			/ demo.cubeMapCells

		local t1 = math.abs(ds) > 0 and ((bs - s) / ds) or math.huge
		local t2 = math.abs(dt) > 0 and ((bt - t) / dt) or math.huge

		local ps, pt
		if math.min(math.abs(t1), math.abs(t2)) < math.huge then
			if math.abs(t1) < math.abs(t2) then
				ps = s + ds * (t1 + 0.001)
				pt = t + dt * (t1 + 0.001)
			else
				ps = s + ds * (t2 + 0.001)
				pt = t + dt * (t2 + 0.001)
			end
		else
			ps = bs
			pt = bt
		end

		love.graphics.setColor(0, 1, 0, 1)
		love.graphics.polygon(
			"fill",
			getCubeMapSideCellPoints(
				func,
				face,
				Common.clamp(
					math.floor(ps * demo.cubeMapCells),
					0,
					demo.cubeMapCells - 1
				) / demo.cubeMapCells,
				Common.clamp(
					math.floor(pt * demo.cubeMapCells),
					0,
					demo.cubeMapCells - 1
				) / demo.cubeMapCells
			)
		)

		love.graphics.setColor(1, 0, 0, 1)
		local line1 = getCubeMapLine(func, face, s, t, ps, pt)
		love.graphics.line(line1)
		love.graphics.circle("fill", line1[#line1 - 1], line1[#line1], 4)

		love.graphics.setColor(1, 1, 1, 0.5)
		love.graphics.polygon(
			"fill",
			getCubeMapSideCellPoints(
				func,
				face,
				Common.clamp(
					math.floor(bs * demo.cubeMapCells),
					0,
					demo.cubeMapCells - 1
				) / demo.cubeMapCells,
				Common.clamp(
					math.floor(bt * demo.cubeMapCells),
					0,
					demo.cubeMapCells - 1
				) / demo.cubeMapCells
			)
		)

		love.graphics.pop()
	end
end

function demo.load()
	demo.projection = PerspectiveFOVCameraProjection()
	demo.projection:setFOV(math.pi / 4)
	demo.projection:setSize(demo.cubeMapSize, demo.cubeMapSize)

	demo.view = ArcballCameraView()
	demo.view:setDistance(2)

	demo.camera = Camera(demo.projection, demo.view)
end

local function _lessFace(a, b)
	local da = demo.view
		:getRotation()
		:transformVector(Vector3.NEGATIVE_Z)
		:dot(CubeMap.NORMALS[a] or Vector3.ZERO)
	local db = demo.view
		:getRotation()
		:transformVector(Vector3.NEGATIVE_Z)
		:dot(CubeMap.NORMALS[b] or Vector3.ZERO)

	return da < db
end

local NORMAL_FACE = -1
local NORMALS = {
	Vector3.UNIT_X,
	Vector3.UNIT_Y,
	Vector3.UNIT_Z,
}

function demo.draw()
	local faces = {
		CubeMap.FACE_POSITIVE_X,
		CubeMap.FACE_NEGATIVE_X,
		CubeMap.FACE_POSITIVE_Y,
		CubeMap.FACE_NEGATIVE_Y,
		CubeMap.FACE_POSITIVE_Z,
		CubeMap.FACE_NEGATIVE_Z,
		NORMAL_FACE,
	}

	local colors = {
		LinearColor(1, 0.5, 0.5),
		LinearColor(0, 0.5, 0.5),
		LinearColor(0.5, 1, 0.5),
		LinearColor(0.5, 0, 0.5),
		LinearColor(0.5, 0.5, 1),
		LinearColor(0.5, 0.5, 0),
	}

	table.sort(faces, _lessFace)

	love.graphics.push("all")
	for i = #faces, 1, -1 do
		local face = faces[i]
		if face == NORMAL_FACE then
			love.graphics.setLineWidth(2)

			love.graphics.setColor(1, 0, 0, 1)

			local x1, y1 = demo.camera
				:project(Vector3.ZERO, demo.cubeMapSize, demo.cubeMapSize)
				:get()
			y1 = demo.cubeMapSize - y1

			love.graphics.push()
			love.graphics.translate(
				(love.graphics.getWidth() - demo.cubeMapSize) / 2,
				(love.graphics.getHeight() - demo.cubeMapSize) / 2
			)

			for _, normal in ipairs(NORMALS) do
				local transformedNormal =
					demo.normalRotation:transformVector(normal):normalize()

				love.graphics.setColor(normal.x, normal.y, normal.z, 1)
				local x2, y2 = demo.camera
					:project(
						transformedNormal:scale(0.5),
						demo.cubeMapSize,
						demo.cubeMapSize
					)
					:get()
				y2 = demo.cubeMapSize - y2

				love.graphics.line(x1, y1, x2, y2)
				love.graphics.circle("fill", x2, y2, 4)
			end

			love.graphics.pop()
		else
			love.graphics.setLineWidth(1)
			local color = colors[face]
			local r, g, b = color:get()
			local a = i == 1 and 1 or 0.1

			love.graphics.setColor(r, g, b, a)
			drawCubemapSide(CubeMap.getNormalFromFaceTextureCoordinate, face)

			a = a * 0.5
			love.graphics.setColor(r, g, b, a)
			drawCubemapSide(
				CubeMap.getCoordinateFromFaceTextureCoordinate,
				face
			)
		end
	end
	love.graphics.pop()
end

return demo
