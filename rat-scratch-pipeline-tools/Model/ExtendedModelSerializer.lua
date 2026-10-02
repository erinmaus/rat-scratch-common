local PATH = ...
local ffi = require("ffi")
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local SkinnedModel = require("rat-scratch-graphics").Graphics3D.SkinnedModel
local Scene = require("rat-scratch-graphics").Graphics3D.Scene
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local PipelineLOD = require("rat-scratch-pipeline").Graphics3D.PipelineLOD
local RatScratchModule = require("lib.rat-scratch-module")

--- @class RatScratch.Pipeline.ExtendedModelSerializer : RatScratch.Common.BaseObject
--- @overload fun(modelDefinition: RatScratch.Graphics.Graphics3D.ModelDefinition, extendedModel: RatScratch.Pipeline.ExtendedModel): RatScratch.Pipeline.ExtendedModelSerializer
--- @field private modelDefinition RatScratch.Graphics.Graphics3D.ModelDefinition
--- @field private extendedModel RatScratch.Pipeline.ExtendedModel
--- @field private model? RatScratch.Graphics.Graphics3D.SkinnedModel
--- @field private animationDefinitionToID table<RatScratch.Graphics.Graphics3D.AnimationDefinition, integer>
--- @field private skeletonDefinitionToID table<RatScratch.Graphics.Graphics3D.SkeletonDefinition, integer>
--- @field private boneIDToNodeID table<integer, integer>
local ExtendedModelSerializer = Object()

--- @param modelDefinition RatScratch.Graphics.Graphics3D.ModelDefinition
--- @param extendedModel RatScratch.Pipeline.ExtendedModel
function ExtendedModelSerializer:new(modelDefinition, extendedModel)
	self.extendedModel = extendedModel

	local animationDefinitions = modelDefinition.animations and {}
	local skeletonDefinition = modelDefinition.skeleton
		and {
			id = modelDefinition.skeleton.id,
			parentID = modelDefinition.skeleton.parentID,
			name = modelDefinition.skeleton.name,
			bones = {},
			extras = {
				RAT_extras_serialize = {
					userdata = self,
					serialize = ExtendedModelSerializer._serializeSkeleton,
				},
			},
		}

	if animationDefinitions and skeletonDefinition then
		--- @type RatScratch.Graphics.Graphics3D.SceneDefinition
		local sceneDefinition = {
			models = {
				{
					meshes = {},
					animations = modelDefinition.animations,
					skeleton = modelDefinition.skeleton,
				},
			},
		}

		local scene = Scene.fromDefinition(sceneDefinition)
		local model = scene:getModel(1)

		--- @cast model RatScratch.Graphics.Graphics3D.SkinnedModel
		self.model = model

		for _, animationDefinition in ipairs(modelDefinition.animations) do
			table.insert(animationDefinitions, {
				id = animationDefinition.id,
				name = animationDefinition.name,
				parentID = animationDefinition.parentID,
				channels = animationDefinition.channels,
				extras = {
					RAT_extras_serialize = {
						userdata = self,
						serialize = ExtendedModelSerializer._serializeAnimation,
					},
				},
			})
		end

		for _, boneDefinition in ipairs(modelDefinition.skeleton.bones) do
			local result = Table.deepClone(boneDefinition)

			local extras = result.extras
			if not extras then
				extras = {}
				result.extras = extras
			end

			result.extras.RAT_extras_serialize = {
				userdata = self,
				serialize = ExtendedModelSerializer._serializeBone,
			}

			table.insert(skeletonDefinition.bones, result)
		end
	end

	self.modelDefinition = {
		id = modelDefinition.id,
		parentID = modelDefinition.parentID,
		name = modelDefinition.name,
		skeleton = skeletonDefinition,
		animations = animationDefinitions,
		meshes = modelDefinition.meshes,
		transform = modelDefinition.transform,
		extras = {
			RAT_extras_serialize = {
				userdata = self,
				serialize = ExtendedModelSerializer._serializeModel,
			},
		},
	}

	self.extendedModel = extendedModel

	self.animationDefinitionToID = {}
	self.skeletonDefinitionToID = {}
	self.boneIDToNodeID = {}
end

function ExtendedModelSerializer:getModelDefinition()
	return self.modelDefinition
end

--- @private
--- @param builder RatScratch.GLTF.GLTFBuilder
--- @param animation RatScratch.GLTF.Animation
--- @param index integer
--- @param animationDefinition RatScratch.Graphics.Graphics3D.AnimationDefinition
function ExtendedModelSerializer:_serializeAnimation(
	builder,
	animation,
	index,
	animationDefinition
)
	self.animationDefinitionToID[animationDefinition] = index
end

--- @private
--- @param builder RatScratch.GLTF.GLTFBuilder
--- @param skin RatScratch.GLTF.Skin
--- @param index integer
--- @param skeletonDefinition RatScratch.Graphics.Graphics3D.SkeletonDefinition
function ExtendedModelSerializer:_serializeSkeleton(
	builder,
	skin,
	index,
	skeletonDefinition
)
	self.skeletonDefinitionToID[skeletonDefinition] = index
end

--- @private
--- @param builder RatScratch.GLTF.GLTFBuilder
--- @param node RatScratch.GLTF.Node
--- @param index integer
--- @param boneDefinition RatScratch.Graphics.Graphics3D.BoneDefinition
function ExtendedModelSerializer:_serializeBone(
	builder,
	node,
	index,
	boneDefinition
)
	self.boneIDToNodeID[boneDefinition.id] = index
end

--- @private
--- @param extendedMesh RatScratch.Pipeline.ExtendedMesh
--- @param primitive RatScratch.Pipeline.GLTF.RAT_mesh_primitive_meshlets
function ExtendedModelSerializer:_getDynamicMeshletBounds(
	extendedMesh,
	primitive
)
	local threads = {}
	local outputChannel = love.thread.newChannel()

	for i = 1, extendedMesh:getMeshletCount() do
		local serializedExtendedMeshMeshlet =
			extendedMesh:getMeshlet(i):serialize()
		for j = 1, self.model:getAnimationCount() do
			local scene = {
				models = {
					{
						meshes = {},
						skeleton = self.extendedModel:getModelDefinition().skeleton,
						animations = {
							self.extendedModel:getModelDefinition().animations[j],
						},
					},
				},
			}

			local thread = RatScratchModule.newThread(
				PATH,
				("%s/Model/Threads/ExtendedMeshMeshletComputeSkinnedBounds.lua"):format(
					RatScratchModule.getSelfPath(PATH)
				),
				serializedExtendedMeshMeshlet,
				scene,
				#threads + 1,
				outputChannel
			)

			table.insert(threads, {
				meshletIndex = i,
				animationIndex = j,
				thread = thread,
			})
		end
	end

	local dynamicMeshletBounds = {}
	for _ = 1, #threads do
		local result = outputChannel:demand()
		local threadInfo = threads[result.id]

		local bounds = dynamicMeshletBounds[threadInfo.meshletIndex]
		if not bounds then
			bounds = {}
			dynamicMeshletBounds[threadInfo.meshletIndex] = bounds
		end

		local animationDefinition =
			self.modelDefinition.animations[threadInfo.animationIndex]
		local animationID = self.animationDefinitionToID[animationDefinition]

		bounds[animationID] = {
			center = { unpack(result.center) },
			radius = result.radius,
			animation = animationID,
		}

		threadInfo.thread:wait()
	end

	for i = 1, extendedMesh:getMeshletCount() do
		local extendedMeshMeshlet = extendedMesh:getMeshlet(i)

		local meshlet = primitive.meshlets[i]
		local skinnedBounds = meshlet.skinnedBounds
		if not skinnedBounds then
			skinnedBounds = {}
			meshlet.skinnedBounds = skinnedBounds
		end

		for j = 1, self.model:getAnimationCount() do
			local animationDefinition = self.modelDefinition.animations[j]
			local animationID =
				self.animationDefinitionToID[animationDefinition]
			local bone = self.model
				:getSkeleton()
				:getBone(extendedMeshMeshlet:getPrimaryBone())

			local animationBounds = dynamicMeshletBounds[i]
				and dynamicMeshletBounds[i][animationID]
			if animationBounds then
				table.insert(skinnedBounds, {
					center = { unpack(animationBounds.center) },
					radius = animationBounds.radius,
					animation = animationID,
					bone = self.boneIDToNodeID[bone:getID()],
				})
			end
		end
	end
end

--- @private
--- @param builder RatScratch.GLTF.GLTFBuilder
--- @param extendedMesh RatScratch.Pipeline.ExtendedMesh
--- @param clusterExtra RatScratch.Pipeline.GLTF.RAT_mesh_primitive_cluster
function ExtendedModelSerializer:_buildClusterMeshletData(
	builder,
	extendedMesh,
	clusterExtra
)
	local clusterMeshlets = {}
	local clusterMeshletsIndexOffset = 0
	local clusterMeshletFormatInstance =
		BufferFormat.get(PipelineLOD.CLUSTER_FORMAT)
	for j = 1, extendedMesh:getMeshletCount() do
		local meshlet = extendedMesh:getMeshlet(j)
		local offset = (j - 1)
			* clusterMeshletFormatInstance:getComponentCount()

		BufferFormat.resetValue(
			clusterMeshletFormatInstance,
			clusterMeshlets,
			offset
		)

		local boundsPosition, boundsRadius = meshlet:getStaticBounds()
		BufferFormat.setValue(
			clusterMeshletFormatInstance,
			clusterMeshlets,
			"boundsPositionRadius",
			offset,
			boundsPosition.x,
			boundsPosition.y,
			boundsPosition.z,
			boundsRadius
		)

		BufferFormat.setValue(
			clusterMeshletFormatInstance,
			clusterMeshlets,
			"error",
			offset,
			meshlet:getError()
		)

		BufferFormat.setValue(
			clusterMeshletFormatInstance,
			clusterMeshlets,
			"refinedIndex",
			offset,
			meshlet:getRefinedIndex()
		)

		local count = meshlet:getIndexData():getSize() / ffi.sizeof("uint32_t")
		BufferFormat.setValue(
			clusterMeshletFormatInstance,
			clusterMeshlets,
			"indexOffsetCount",
			offset,
			clusterMeshletsIndexOffset,
			count
		)

		clusterMeshletsIndexOffset = clusterMeshletsIndexOffset + count
	end

	local clusterMeshletsData = love.data.newByteData(
		extendedMesh:getMeshletCount()
			* clusterMeshletFormatInstance:getStride()
	)
	BufferFormat.copyFromFlatTableToByteData(
		clusterMeshletFormatInstance,
		1,
		0,
		extendedMesh:getMeshletCount(),
		clusterMeshlets,
		clusterMeshletsData
	)

	clusterExtra.meshlets = builder:addWorkingBufferView({
		data = clusterMeshletsData,
	})
end

--- @private
--- @param builder RatScratch.GLTF.GLTFBuilder
--- @param extendedMesh RatScratch.Pipeline.ExtendedMesh
--- @param clusterExtra RatScratch.Pipeline.GLTF.RAT_mesh_primitive_cluster
function ExtendedModelSerializer:_buildClusterGroupData(
	builder,
	extendedMesh,
	clusterExtra
)
	local clusterGroups = {}
	local clusterGroupFormatInstance =
		BufferFormat.get(PipelineLOD.GROUP_FORMAT)
	for j = 1, extendedMesh:getClusterGroupCount() do
		local group = extendedMesh:getClusterGroup(j)
		local offset = (j - 1) * clusterGroupFormatInstance:getComponentCount()

		BufferFormat.resetValue(
			clusterGroupFormatInstance,
			clusterGroups,
			offset
		)

		BufferFormat.setValue(
			clusterGroupFormatInstance,
			clusterGroups,
			"boundsPositionRadius",
			offset,
			group.bounds.position.x,
			group.bounds.position.y,
			group.bounds.position.z,
			group.bounds.radius
		)

		BufferFormat.setValue(
			clusterGroupFormatInstance,
			clusterGroups,
			"error",
			offset,
			group.error
		)

		BufferFormat.setValue(
			clusterGroupFormatInstance,
			clusterGroups,
			"clusterIndexCount",
			offset,
			group.clusterIndex,
			group.clusterCount
		)
	end
	local clusterGroupsData = love.data.newByteData(
		extendedMesh:getClusterGroupCount()
			* clusterGroupFormatInstance:getStride()
	)
	BufferFormat.copyFromFlatTableToByteData(
		clusterGroupFormatInstance,
		1,
		0,
		extendedMesh:getClusterGroupCount(),
		clusterGroups,
		clusterGroupsData
	)
	clusterExtra.groups = builder:addWorkingBufferView({
		data = clusterGroupsData,
	})
end

--- @private
--- @param builder RatScratch.GLTF.GLTFBuilder
--- @param extendedMesh RatScratch.Pipeline.ExtendedMesh
--- @param clusterExtra RatScratch.Pipeline.GLTF.RAT_mesh_primitive_cluster
function ExtendedModelSerializer:_buildClusterNodeData(
	builder,
	extendedMesh,
	clusterExtra
)
	local clusterNodes = {}
	local clusterNodeFormatInstance = BufferFormat.get(PipelineLOD.NODE_FORMAT)
	for j = 1, extendedMesh:getClusterNodeCount() do
		local node = extendedMesh:getClusterNode(j)
		local offset = (j - 1) * clusterNodeFormatInstance:getComponentCount()

		BufferFormat.resetValue(clusterNodeFormatInstance, clusterNodes, offset)

		BufferFormat.setValue(
			clusterNodeFormatInstance,
			clusterNodes,
			"boundsPositionRadius",
			offset,
			node.bounds.position.x,
			node.bounds.position.y,
			node.bounds.position.z,
			node.bounds.radius
		)

		BufferFormat.setValue(
			clusterNodeFormatInstance,
			clusterNodes,
			"error",
			offset,
			node.error
		)

		BufferFormat.setValue(
			clusterNodeFormatInstance,
			clusterNodes,
			"groupIndex",
			offset,
			node.groupIndex
		)

		BufferFormat.setValue(
			clusterNodeFormatInstance,
			clusterNodes,
			"childIndexCount",
			offset,
			node.childIndex,
			node.childCount
		)
	end
	local clusterNodesData = love.data.newByteData(
		extendedMesh:getClusterNodeCount()
			* clusterNodeFormatInstance:getStride()
	)
	BufferFormat.copyFromFlatTableToByteData(
		clusterNodeFormatInstance,
		1,
		0,
		extendedMesh:getClusterNodeCount(),
		clusterNodes,
		clusterNodesData
	)
	clusterExtra.nodes = builder:addWorkingBufferView({
		data = clusterNodesData,
	})
end

--- @private
--- @param builder RatScratch.GLTF.GLTFBuilder
--- @param extendedMesh RatScratch.Pipeline.ExtendedMesh
--- @param clusterExtra RatScratch.Pipeline.GLTF.RAT_mesh_primitive_cluster
function ExtendedModelSerializer:_buildClusterData(
	builder,
	extendedMesh,
	clusterExtra
)
	self:_buildClusterMeshletData(builder, extendedMesh, clusterExtra)
	self:_buildClusterGroupData(builder, extendedMesh, clusterExtra)
	self:_buildClusterNodeData(builder, extendedMesh, clusterExtra)
end

--- @private
--- @param builder RatScratch.GLTF.GLTFBuilder
--- @param node RatScratch.GLTF.Node
function ExtendedModelSerializer:_serializeModel(builder, node)
	if not node.mesh then
		return
	end

	local mesh = builder:getMesh(node.mesh)
	for i, primitive in ipairs(mesh.primitives) do
		local extendedMesh = self.extendedModel:getMesh(i)

		--- @type RatScratch.Pipeline.GLTF.RAT_mesh_primitive_meshlets
		local primitiveExtras = {
			vertexCount = extendedMesh:getVertexCount(),
			indexCount = extendedMesh:getIndexCount(),
			meshlets = {},
			attributes = {},
			indices = builder:addWorkingBufferView({
				data = extendedMesh:getIndexBufferData(),
			}),
			cluster = {
				meshlets = -1,
				meshletCount = tonumber(extendedMesh:getMeshletCount()) or 0,
				groups = -1,
				groupCount = tonumber(extendedMesh:getClusterGroupCount()) or 0,
				nodes = -1,
				nodeCount = tonumber(extendedMesh:getClusterNodeCount()) or 0,
				rootNodeCount = tonumber(
					extendedMesh:getClusterRootNodeCount()
				) or 0,
			},
		}

		for j = 1, extendedMesh:getVertexAttributeBufferCount() do
			local bufferData = extendedMesh:getVertexAttributeBufferData(j)
			local bufferInfo = extendedMesh:getVertexAttributeBufferInfo(j)

			local vertexAttributesBufferViewIndex =
				builder:addWorkingBufferView({
					data = bufferData,
				})

			primitiveExtras.attributes[bufferInfo:getBufferName()] =
				vertexAttributesBufferViewIndex
		end

		for j = 1, extendedMesh:getMeshletCount() do
			local extendedMeshMeshlet = extendedMesh:getMeshlet(j)

			local indexBufferViewIndex = builder:addWorkingBufferView({
				data = extendedMeshMeshlet:getIndexData(),
			})

			local staticCenter, staticRadius =
				extendedMeshMeshlet:getStaticBounds()
			local meshlet = {
				indices = indexBufferViewIndex,
				staticBounds = {
					center = { staticCenter:get() },
					radius = staticRadius,
				},
			}

			table.insert(primitiveExtras.meshlets, meshlet)
		end

		self:_buildClusterData(builder, extendedMesh, primitiveExtras.cluster)

		if
			self.model and Object.isDerived(self.model:getType(), SkinnedModel)
		then
			self:_getDynamicMeshletBounds(extendedMesh, primitiveExtras)
		end

		local extras = primitive.extras
		if not extras then
			extras = {}
			primitive.extras = extras
		end

		extras.RAT_mesh_primitive_meshlets = primitiveExtras
	end
end

return ExtendedModelSerializer
