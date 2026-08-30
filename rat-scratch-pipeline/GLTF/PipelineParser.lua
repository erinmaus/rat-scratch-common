local PATH = ...
local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Search = require("rat-scratch-common").Search
local RatScratchModule = require("lib.rat-scratch-module")
local Vector3 = require("rat-scratch-math").Vector3
local Quaternion = require("rat-scratch-math").Quaternion
local Transform = require("rat-scratch-math").Transform
local PipelineConfig = require("rat-scratch-pipeline.PipelineConfig")

--- @class RatScratch.Pipeline.GLTF.GLTFPipelineParser : RatScratch.Common.BaseObject
--- @field private parser RatScratch.GLTF.GLTFParser
--- @field private pipelineConfig RatScratch.Pipeline.PipelineConfig
--- @overload fun(pipelineConfig?: RatScratch.Pipeline.PipelineConfig, parser: RatScratch.GLTF.GLTFParser): RatScratch.Pipeline.GLTF.GLTFPipelineParser
local PipelineParser = Object()

--- @param pipelineConfig? RatScratch.Pipeline.PipelineConfig
--- @param parser RatScratch.GLTF.GLTFParser
function PipelineParser:new(pipelineConfig, parser)
	local extras = parser:getJSON().extras

	--- @type RatScratch.Pipeline.GLTF.RAT_pipeline_extra?
	local pipeline = extras and extras.RAT_pipeline_extra or nil

	assert(pipeline, "GLTF does not have RAT_pipeline_extra")
	assert(
		RatScratchModule.isCompatible(PATH, pipeline.pipeline.version),
		"pipeline config (version %s) is incompatible with rat-scratch-pipeline version %s",
		pipeline.pipeline.version,
		RatScratchModule.getSelfVersion(PATH)
	)

	local otherPipelineConfig = PipelineConfig(pipeline.pipeline)
	assert(
		not pipelineConfig or pipelineConfig:isMatch(otherPipelineConfig),
		"pipeline config mismatch"
	)

	self.pipelineConfig = pipelineConfig or otherPipelineConfig
	self.parser = parser
end

--- @private
--- @param mesh integer
--- @param node integer
--- @return RatScratch.GLTF.Node?
function PipelineParser:_findNodeOrChildNode(mesh, node)
	local node = self.parser:getNode(node)
	if node.mesh == mesh then
		return node
	end

	if node.children then
		for _, child in ipairs(node.children) do
			local result = self:_findNodeOrChildNode(mesh, child)
			if result then
				return result
			end
		end
	end

	return nil
end

--- @private
--- @param scene integer
--- @param mesh integer
--- @return RatScratch.GLTF.Node?
function PipelineParser:_findNode(scene, mesh)
	local scene = self.parser:getScene(scene)
	if scene.nodes then
		for _, node in ipairs(scene.nodes) do
			local result = self:_findNodeOrChildNode(mesh, node)
			if result then
				return result
			end
		end
	end

	return nil
end

local function _lessInteger(a, b)
	return a - b
end

--- @private
--- @param index integer
--- @param result integer[]
--- @return RatScratch.Pipeline.GLTF.GLTFPipelineParser
function PipelineParser:_collectModelNodes(index, result)
	local node = self.parser:getNode(index)
	if node.mesh then
		table.insert(
			result,
			Search.lessThanEqual(result + 1, index, _lessInteger),
			index
		)
	end

	for _, child in ipairs(node.children) do
		self:_collectModelNodes(child, result)
	end
end

--- @param index? integer
--- @return RatScratch.Pipeline.Graphics3D.PipelineSceneDefinition
function PipelineParser:loadSceneDefinition(index)
	local scene = self.parser:getScene(index or self.parser:getDefaultScene())

	local modelNodes = {}
	for _, nodeIndex in ipairs(scene.nodes) do
		self:_collectModelNodes(nodeIndex, modelNodes)
	end

	--- @type RatScratch.Pipeline.Graphics3D.PipelineSceneDefinition
	local sceneDefinition = {
		models = #modelNodes > 0 and {} or nil,
	}

	local skeletonsByID = {}
	for _, nodeIndex in ipairs(modelNodes) do
		local node = self.parser:getNode(nodeIndex)
		local model = self:loadModelDefinition(node.mesh)
		if node.skin then
			local skeletonDefinition = skeletonsByID[node.skin]
			if not skeletonDefinition then
				skeletonDefinition = self.parser:loadSkin(node.skin)

				skeletonsByID[node.skin] = skeletonDefinition

				local animationDefinitions =
					self.parser:loadAnimations(skeletonDefinition)
				table.insert(sceneDefinition.skeletons, skeletonDefinition)

				if not sceneDefinition.skeletons then
					sceneDefinition.skeletons = {}
				end

				if
					not sceneDefinition.animations
					and #animationDefinitions > 0
				then
					sceneDefinition.animations = {}
				end

				if #animationDefinitions > 0 then
					table.insert(sceneDefinition.animations, {
						skeleton = skeletonDefinition,
						animations = animationDefinitions,
					})
				end
			end

			model.skeleton = skeletonsByID[node.skin]
		end
	end

	return sceneDefinition
end

--- @private
--- @param node? RatScratch.GLTF.Node
--- @param transform love.Transform
function PipelineParser:_getNodeTransform(node, transform)
	if not node then
		return
	end

	if node.matrix then
		transform:setMatrix("column", unpack(node.matrix))
	elseif node.translation or node.scale or node.rotation then
		local translation = node.translation and { unpack(node.translation) }
			or { Vector3.ZERO:get() }
		local scale = node.scale and { unpack(node.scale) }
			or { Vector3.ONE:get() }
		local rotation = node.rotation and { unpack(node.rotation) }
			or { Quaternion.IDENTITY:get() }

		Transform.compose(
			Vector3(unpack(translation)),
			Quaternion(unpack(rotation)),
			Vector3(unpack(scale)),
			transform
		)
	end
end

--- @param index integer
--- @return RatScratch.Pipeline.Graphics3D.PipelineModelDefinition
function PipelineParser:loadModelDefinition(index)
	local indexSize = self.pipelineConfig:getIndexFormat():getStride()
	local meshletIndexSize = self.pipelineConfig
		:getMeshletFormat()
		:getTriangleCount() * 3 * indexSize

	local transform = love.math.newTransform()
	do
		local scene = self.parser:getDefaultScene()
		local node = self:_findNode(scene, index)
		self:_getNodeTransform(node, transform)
	end

	local mesh = self.parser:getMesh(index)

	--- @type RatScratch.Pipeline.Graphics3D.PipelineModelDefinition
	local modelDefinition = {
		meshes = {},
		transform = transform,
	}

	for i, primitive in ipairs(mesh.primitives) do
		local primitiveExtras = primitive.extras

		--- @type RatScratch.Pipeline.GLTF.RAT_mesh_primitive_meshlets?
		local primitiveMeshlets = primitiveExtras
				and primitiveExtras.RAT_mesh_primitive_meshlets
			or nil
		assert(
			primitiveMeshlets,
			"GLTF mesh '%s' primitive '%s' does not have meshlets",
			mesh.name or index,
			primitive.name or i
		)

		--- @type table<string, love.Data>
		local vertices = {}
		for bufferName, bufferView in pairs(primitiveMeshlets.attributes) do
			local data = self.parser:getBufferViewData(bufferView)
			vertices[bufferName] = data
		end

		local indices = self.parser:getBufferViewData(primitiveMeshlets.indices)

		--- @type RatScratch.Pipeline.Graphics3D.PipelineMeshletDefinition[]
		local meshletDefinitions = {}

		local meshletIndexOffset = 0
		for _, meshlet in ipairs(primitiveMeshlets.meshlets) do
			--- @type RatScratch.Pipeline.Graphics3D.PipelineMeshletDefinition
			local meshletDefinition = {
				indices = love.data.newDataView(
					indices,
					meshletIndexOffset,
					meshletIndexSize
				),
				staticBounds = {
					center = Vector3(unpack(meshlet.staticBounds.center)),
					radius = meshlet.staticBounds.radius,
				},
			}

			if meshlet.skinnedBounds then
				meshletDefinition.skinnedBounds = {}

				for _, bounds in ipairs(meshlet.skinnedBounds) do
					table.insert(meshletDefinition.skinnedBounds, {
						center = Vector3(unpack(bounds.center)),
						radius = bounds.radius,
						bone = bounds.bone,
						animation = bounds.animation,
					})
				end
			end

			table.insert(meshletDefinitions, meshletDefinition)
			meshletIndexOffset = meshletIndexOffset + meshletIndexSize
		end

		table.insert(modelDefinition.meshes, {
			vertices = vertices,
			indices = indices,
			meshlets = meshletDefinitions,
			material = primitive.material
				and self.parser:loadMaterial(primitive.material),
		})
	end

	return modelDefinition
end

return PipelineParser
