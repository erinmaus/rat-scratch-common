local Scene = require("rat-scratch-graphics").Graphics3D.Scene
local ExtendedMeshMeshlet =
	require("rat-scratch-pipeline-tools").Model.ExtendedMeshMeshlet

--- @type RatScratch.Pipeline.SerializedExtendedMeshMeshlet, RatScratch.Graphics.Graphics3D.SceneDefinition, integer, love.Channel
local serializedExtendedMeshMeshlet, scene, id, outputChannel = ...

local scene = Scene.fromDefinition(scene)

local model = scene:getModel(1)
--- @cast model RatScratch.Graphics.Graphics3D.SkinnedModel

local skeleton = model:getSkeleton()
local animation = model:getAnimation(1)

local extendedMeshMeshlet =
	ExtendedMeshMeshlet.fromSerialized(serializedExtendedMeshMeshlet)
local center, radius =
	extendedMeshMeshlet:computeSkinnedBounds(skeleton, animation)

outputChannel:push({
	id = id,
	center = { center:get() },
	radius = radius,
})
