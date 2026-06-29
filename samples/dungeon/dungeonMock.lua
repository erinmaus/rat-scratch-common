local GLTF = require("rat-scratch-gltf")
local Table = require("rat-scratch-common").Table
local FlatTable = require("rat-scratch-common").FlatTable
local SDF = require("rat-scratch-math").Geometry2D.SDF
local Polygon = require("rat-scratch-math").Geometry2D.Polygon
local Point = require("rat-scratch-math").Geometry2D.Point
local MarchingSquares = require("rat-scratch-math").MarchingSquares
local DualContour = require("rat-scratch-math").DualContour
local Contour = require("rat-scratch-math").Geometry2D.Contour
local Scene = require("rat-scratch-graphics").Graphics3D.Scene
local Animator = require("rat-scratch-graphics").Graphics3D.Animator
local SkinnedModel = require("rat-scratch-graphics").Graphics3D.SkinnedModel
local ModelProcessor = require("rat-scratch-graphics").Graphics3D.ModelProcessor
local Transform = require("rat-scratch-math").Transform
local Vector3 = require("rat-scratch-math").Vector3
local Common = require("rat-scratch-math").Common
local Quaternion = require("rat-scratch-math").Quaternion
local ShaderPreprocessor = require("rat-scratch-graphics").ShaderPreprocessor

local function sampleSDF(rectangle, x, y)
	local sample = SDF.distanceFromRectangle(x, y, unpack(rectangle))
	return sample, sample <= 0
end

local demo = {}

function demo.load()
	local contour = DualContour.generate(
		-10,
		-10,
		10,
		10,
		0.5,
		{ -4, -4, 4, 4 },
		sampleSDF
	)[1]

	contour = Contour.simplify(contour)

	local parser = GLTF.loadFromFilesystem("samples/assets/gltf/simpleWall.glb")
	local sceneDefinition = parser:loadScene(1)
	local scene = Scene.fromDefinition(sceneDefinition, false)
	local model = scene:getModel(1)
	local mesh = model:getMesh(1)

	local shader = ShaderPreprocessor.newComputeShader(
		"rat-scratch-dungeon/Shaders/WarpMesh/WarpMesh.compute.glsl",
		{
			rootPath = "/rat-scratch-graphics/Shaders",
		}
	)

	local meshCount = 0

	-- local polygon = FlatTable.wrap(contour, 2)
	-- for i = 1, polygon:getLength() do
	-- 	local x1, y1 = polygon:get(i)
	-- 	local x2, y2 = polygon:get(i + 1)

	-- 	local dx, dy = Point.direction(x1, y1, x2, y2)
	-- 	local length = Point.length(dx, dy)
	-- 	dx, dy = dx / length, dy / length

	-- end
end

return demo
