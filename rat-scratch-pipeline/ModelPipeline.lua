local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local ModelInstancesHandle =
	require("rat-scratch-pipeline.ModelInstancesHandle")
local Pipeline = require("rat-scratch-pipeline.impl.Pipeline")
local PipelineLOD = require("rat-scratch-pipeline.Graphics3D.PipelineLOD")
local PipelineMultiBuffer =
	require("rat-scratch-pipeline.Buffer.PipelineMultiBuffer")
local Transform = require("rat-scratch-math").Transform

--- @class RatScratch.Pipeline.ModelPipeline : RatScratch.Pipeline.impl.Pipeline
--- @field private staticVertexBuffer RatScratch.Pipeline.Buffer.PipelineMultiBuffer<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @field private skinnedVertexBuffer RatScratch.Pipeline.Buffer.PipelineMultiBuffer<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @field private indexBuffer RatScratch.Pipeline.Buffer.PipelineMultiBuffer<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @field private modelsBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @field private meshesBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @field private meshClustersBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @field private meshClusterGroupsBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @field private meshClusterNodesBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @field private models table<RatScratch.Pipeline.Graphics3D.PipelineModel, true>
--- @field private modelsByIndex RatScratch.Pipeline.Graphics3D.PipelineModel[]
--- @field private dirtyModels table<RatScratch.Pipeline.Graphics3D.PipelineModel, true>
--- @field private dirtyModelBuffers table<RatScratch.Pipeline.Graphics3D.PipelineModel, true>
--- @field private modelInstances table<RatScratch.Pipeline.ModelPipeline.ModelInstancesHandle, true>
--- @field private dirtyModelInstances table<RatScratch.Pipeline.ModelPipeline.ModelInstancesHandle, true>
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.ModelPipeline
local ModelPipeline = Object(Pipeline)

ModelPipeline.MODEL_INSTANCE_FORMAT = {
	{ location = 0, name = "objectInstanceIndex", format = "uint32" },
	{ location = 1, name = "modelIndex", format = "uint32" },
	{ location = 3, name = "meshInstanceIndexCount", format = "uint32vec2" },
}

ModelPipeline.MESH_INSTANCE_FORMAT = {
	{ location = 0, name = "materialInstanceIndex", format = "uint32" },
}

ModelPipeline.MODEL_FORMAT = {
	{ location = 0, name = "localTransform", format = "floatmat4x4" },
	{ location = 1, name = "meshIndexCount", format = "uint32vec2" },
}

ModelPipeline.MESH_FORMAT = {
	{ location = 0, name = "clusterIndexCount", format = "uint32vec2" },
	{ location = 1, name = "clusterGroupIndexCount", format = "uint32vec2" },
	{ location = 2, name = "clusterNodeIndexCount", format = "uint32vec2" },
	{ location = 3, name = "clusterRootNodeCount", format = "uint32vec2" },
	{ location = 4, name = "indexOffset", format = "uint32" },
	{ location = 5, name = "staticBaseVertexOffset", format = "uint32" },
	{ location = 6, name = "skinnedBaseVertexOffset", format = "uint32" },
}

ModelPipeline.CLUSTER_FORMAT = {
	{ location = 0, name = "staticCenterRadius", format = "floatvec4" },
	{ location = 1, name = "error", format = "float" },
	{ location = 2, name = "refinedIndex", format = "int32" },
	{ location = 3, name = "indexOffsetCount", format = "uint32vec2" },
}

ModelPipeline.SKINNED_CLUSTER_BOUNDS_FORMAT = {
	{ location = 0, name = "centerRadius", format = "floatvec4" },
	{ location = 1, name = "animationIndex", format = "uint32" },
	{ location = 2, name = "bone", format = "uint32" },
}

ModelPipeline.INDEX_FORMAT = {
	{ location = 0, name = "index", format = "uint32" },
}

ModelPipeline.CLUSTER_TO_MESH_FORMAT = {
	{ location = 0, name = "clusterToMesh", format = "uint32" },
}

ModelPipeline.DEFAULT_VERTEX_COUNT = 2 ^ 20
ModelPipeline.DEFAULT_MODEL_COUNT = 1024
ModelPipeline.DEFAULT_MESH_COUNT = ModelPipeline.DEFAULT_MODEL_COUNT * 64
ModelPipeline.DEFAULT_CLUSTER_COUNT = ModelPipeline.DEFAULT_MESH_COUNT * 64
ModelPipeline.DEFAULT_CLUSTER_SKINNED_BOUNDS_COUNT = ModelPipeline.DEFAULT_CLUSTER_COUNT
	* 4
ModelPipeline.DEFAULT_MODEL_INSTANCE_COUNT = 2048
ModelPipeline.DEFAULT_MESH_INSTANCE_COUNT = ModelPipeline.DEFAULT_MODEL_INSTANCE_COUNT
	* 16

--- @param pipelineRuntime RatScratch.Pipeline.PipelineRuntime
function ModelPipeline:new(pipelineRuntime)
	Pipeline.new(self, pipelineRuntime)

	local staticFormats = {}
	for i = 1, self:getPipelineConfig():getVertexFormatCountByRole("static") do
		table.insert(
			staticFormats,
			self:getPipelineConfig()
				:getVertexFormatByRole("static", i)
				:getInputFormat()
		)
	end

	self.staticVertexBuffer = PipelineMultiBuffer(
		staticFormats,
		{ shaderstorage = true },
		ModelPipeline.DEFAULT_VERTEX_COUNT
	)

	self.indexBuffer = PipelineMultiBuffer(
		{ BufferFormat.get(ModelPipeline.INDEX_FORMAT) },
		{ shaderstorage = true },
		ModelPipeline.DEFAULT_VERTEX_COUNT
	)

	local skinnedFormats = {}
	for i = 1, self:getPipelineConfig():getVertexFormatCountByRole("skinned") do
		table.insert(
			skinnedFormats,
			self:getPipelineConfig()
				:getVertexFormatByRole("skinned", i)
				:getInputFormat()
		)
	end

	self.skinnedVertexBuffer = PipelineMultiBuffer(
		skinnedFormats,
		{ shaderstorage = true },
		ModelPipeline.DEFAULT_VERTEX_COUNT
	)

	self.modelsBuffer = PipelineBuffer(
		ModelPipeline.MODEL_FORMAT,
		{ shaderstorage = true },
		ModelPipeline.DEFAULT_MODEL_COUNT
	)

	self.meshesBuffer = PipelineBuffer(
		ModelPipeline.MESH_FORMAT,
		{ shaderstorage = true },
		ModelPipeline.DEFAULT_MESH_COUNT
	)

	self.meshClustersBuffer = PipelineBuffer(
		PipelineLOD.CLUSTER_FORMAT,
		{ shaderstorage = true },
		ModelPipeline.DEFAULT_CLUSTER_COUNT
	)

	self.meshClusterGroupsBuffer = PipelineBuffer(
		PipelineLOD.GROUP_FORMAT,
		{ shaderstorage = true },
		ModelPipeline.DEFAULT_CLUSTER_COUNT
	)

	self.meshClusterNodesBuffer = PipelineBuffer(
		PipelineLOD.NODE_FORMAT,
		{ shaderstorage = true },
		ModelPipeline.DEFAULT_CLUSTER_COUNT
	)

	self.clustersSkinnedBoundsBuffer = PipelineBuffer(
		ModelPipeline.SKINNED_CLUSTER_BOUNDS_FORMAT,
		{ shaderstorage = true },
		ModelPipeline.DEFAULT_CLUSTER_SKINNED_BOUNDS_COUNT
	)

	self.modelInstancesBuffer = PipelineBuffer(
		ModelPipeline.MODEL_INSTANCE_FORMAT,
		{ shaderstorage = true },
		ModelPipeline.DEFAULT_MODEL_INSTANCE_COUNT
	)

	self.meshInstancesBuffer = PipelineBuffer(
		ModelPipeline.MESH_INSTANCE_FORMAT,
		{ shaderstorage = true },
		ModelPipeline.DEFAULT_MESH_INSTANCE_COUNT
	)

	self.models = {}
	self.modelsByIndex = {}

	self.dirtyModels = {}
	self.dirtyModelBuffers = {}

	self.modelInstances = {}
	self.dirtyModelInstances = {}
end

function ModelPipeline:bind(shader, qualityPreset)
	for i = 1, self:getPipelineConfig():getVertexFormatCountByRole("static") do
		local vertexBuffer = self:getPipelineConfig()
			:getVertexFormatByRole("static", i)

		if shader:hasUniform(vertexBuffer:getBufferShaderName()) then
			shader:send(
				vertexBuffer:getBufferShaderName(),
				self.staticVertexBuffer:getBuffer(i)
			)
		end
	end

	for i = 1, self:getPipelineConfig():getVertexFormatCountByRole("skinned") do
		local vertexBuffer = self:getPipelineConfig()
			:getVertexFormatByRole("skinned", i)

		if shader:hasUniform(vertexBuffer:getBufferShaderName()) then
			shader:send(
				vertexBuffer:getBufferShaderName(),
				self.skinnedVertexBuffer:getBuffer(i)
			)
		end
	end

	if shader:hasUniform("rat_IndicesBuffer") then
		shader:send("rat_IndicesBuffer", self.indexBuffer:getBuffer(1))
	end

	if shader:hasUniform("rat_ModelInstancesBuffer") then
		shader:send(
			"rat_ModelInstancesBuffer",
			self.modelInstancesBuffer:getBuffer()
		)
	end

	if shader:hasUniform("rat_MeshInstancesBuffer") then
		shader:send(
			"rat_MeshInstancesBuffer",
			self.meshInstancesBuffer:getBuffer()
		)
	end

	if shader:hasUniform("rat_ModelsBuffer") then
		shader:send("rat_ModelsBuffer", self.modelsBuffer:getBuffer())
	end

	if shader:hasUniform("rat_MeshesBuffer") then
		shader:send("rat_MeshesBuffer", self.meshesBuffer:getBuffer())
	end

	if shader:hasUniform("rat_MeshClustersBuffer") then
		shader:send(
			"rat_MeshClustersBuffer",
			self.meshClustersBuffer:getBuffer()
		)
	end

	if shader:hasUniform("rat_MeshClusterGroupsBuffer") then
		shader:send(
			"rat_MeshClusterGroupsBuffer",
			self.meshClusterGroupsBuffer:getBuffer()
		)
	end

	if shader:hasUniform("rat_MeshClusterNodesBuffer") then
		shader:send(
			"rat_MeshClusterNodesBuffer",
			self.meshClusterNodesBuffer:getBuffer()
		)
	end
end

--- @param model RatScratch.Pipeline.Graphics3D.PipelineModel
function ModelPipeline:hasModel(model)
	return self.models[model] ~= nil
end

--- @param model RatScratch.Pipeline.Graphics3D.PipelineModel
function ModelPipeline:addModel(model)
	assert(not self.models[model], "model already exists in model pipeline")

	self.models[model] = true
	table.insert(self.modelsByIndex, model)

	self.dirtyModels[model] = true
	self.dirtyModelBuffers[model] = true

	self.modelsBuffer:register(model, 1)
	self.meshesBuffer:register(model, model:getMeshCount())
	for i = 1, model:getMeshCount() do
		local mesh = model:getMesh(i)

		self.staticVertexBuffer:register(mesh, mesh:getVertexCount())

		for j = 1, self:getPipelineConfig():getVertexFormatCountByRole("skinned") do
			local vertexBufferInfo = self:getPipelineConfig()
				:getVertexFormatByRole("skinned", j)
			if mesh:hasVertexData(vertexBufferInfo:getBufferName()) then
				self.skinnedVertexBuffer:register(mesh, mesh:getVertexCount())
				break
			end
		end

		self.indexBuffer:register(mesh, mesh:getIndexCount())
	end
end

--- @param model RatScratch.Pipeline.Graphics3D.PipelineModel
function ModelPipeline:removeModel(model)
	assert(self.models[model], "model does not exist in model pipeline")

	self.models[model] = nil
	Table.remove(self.modelsByIndex, model)

	self.dirtyModels[model] = nil
	self.dirtyModelBuffers[model] = nil

	self.modelsBuffer:unregister(model)
	self.meshesBuffer:unregister(model)
	for i = 1, model:getMeshCount() do
		local mesh = model:getMesh(i)

		self.meshClustersBuffer:unregister(mesh)

		if self.meshClusterGroupsBuffer:has(mesh) then
			self.meshClusterGroupsBuffer:unregister(mesh)
		end

		if self.meshClusterNodesBuffer:has(mesh) then
			self.meshClusterNodesBuffer:unregister(mesh)
		end

		self.staticVertexBuffer:unregister(mesh)
		if self.skinnedVertexBuffer:has(mesh) then
			self.skinnedVertexBuffer:unregister(mesh)
		end

		self.indexBuffer:unregister(mesh)
	end
end

--- @param model RatScratch.Pipeline.Graphics3D.PipelineModel
function ModelPipeline:getModelPointer(model)
	return self.modelsBuffer:newPointer(model)
end

--- @param model RatScratch.Pipeline.Graphics3D.PipelineModel
function ModelPipeline:getModelIndex(model)
	local index = self.modelsBuffer:getIndexCount(model)
	return index
end

--- @param model RatScratch.Pipeline.Graphics3D.PipelineModel
function ModelPipeline:getMeshesPointer(model)
	return self.meshesBuffer:newPointer(model)
end

--- @param mesh RatScratch.Pipeline.Graphics3D.PipelineMesh
function ModelPipeline:getMeshesIndexCount(mesh)
	return self.meshesBuffer:getIndexCount(mesh)
end

--- @param mesh RatScratch.Pipeline.Graphics3D.PipelineMesh
function ModelPipeline:getClustersPointer(mesh)
	return self.meshClustersBuffer:newPointer(mesh)
end

--- @param mesh RatScratch.Pipeline.Graphics3D.PipelineMesh
--- @return integer, integer
function ModelPipeline:getClustersIndexCount(mesh)
	return self.meshClustersBuffer:getIndexCount(mesh)
end

--- @param mesh RatScratch.Pipeline.Graphics3D.PipelineMesh
function ModelPipeline:getClusterGroupsPointer(mesh)
	return self.meshClusterGroupsBuffer:newPointer(mesh)
end

--- @param mesh RatScratch.Pipeline.Graphics3D.PipelineMesh
--- @return integer, integer
function ModelPipeline:getClusterGroupsIndexCount(mesh)
	return self.meshClusterGroupsBuffer:getIndexCount(mesh)
end

--- @param mesh RatScratch.Pipeline.Graphics3D.PipelineMesh
function ModelPipeline:getClusterNodesPointer(mesh)
	return self.meshClusterNodesBuffer:newPointer(mesh)
end

--- @param mesh RatScratch.Pipeline.Graphics3D.PipelineMesh
--- @return integer, integer
function ModelPipeline:getClusterNodesIndexCount(mesh)
	return self.meshClusterNodesBuffer:getIndexCount(mesh)
end

--- @param mesh RatScratch.Pipeline.Graphics3D.PipelineMesh
--- @return RatScratch.Pipeline.Buffer.PipelinePointer<RatScratch.Pipeline.Graphics3D.PipelineMesh>
function ModelPipeline:getStaticBaseVertexPointer(mesh)
	return self.staticVertexBuffer:newPointer(mesh)
end

--- @param mesh RatScratch.Pipeline.Graphics3D.PipelineMesh
--- @return integer, integer
function ModelPipeline:getStaticBaseVertexIndexCount(mesh)
	return self.staticVertexBuffer:getIndexCount(mesh)
end

--- @param mesh RatScratch.Pipeline.Graphics3D.PipelineMesh
--- @return RatScratch.Pipeline.Buffer.PipelinePointer<RatScratch.Pipeline.Graphics3D.PipelineMesh>
function ModelPipeline:getSkinnedBaseVertexPointer(mesh)
	return self.skinnedVertexBuffer:newPointer(mesh)
end

--- @param mesh RatScratch.Pipeline.Graphics3D.PipelineMesh
--- @return integer, integer
function ModelPipeline:getSkinnedBaseVertexIndexCount(mesh)
	return self.skinnedVertexBuffer:getIndexCount(mesh)
end

--- @param mesh RatScratch.Pipeline.Graphics3D.PipelineMesh
--- @return RatScratch.Pipeline.Buffer.PipelinePointer<RatScratch.Pipeline.Graphics3D.PipelineMesh>
function ModelPipeline:getBaseIndexPointer(mesh)
	return self.indexBuffer:newPointer(mesh)
end

--- @param mesh RatScratch.Pipeline.Graphics3D.PipelineMesh
--- @return integer, integer
function ModelPipeline:getBaseIndexIndexCount(mesh)
	return self.indexBuffer:getIndexCount(mesh)
end

--- @private
--- @param model RatScratch.Pipeline.Graphics3D.PipelineModel
function ModelPipeline:_updateModelBuffer(model)
	for i = 1, model:getMeshCount() do
		local mesh = model:getMesh(i)
		for j = 1, self:getPipelineConfig():getVertexFormatCountByRole("static") do
			local vertexBufferInfo = self:getPipelineConfig()
				:getVertexFormatByRole("static", j)
			local vertexData =
				mesh:getVertexData(vertexBufferInfo:getBufferName())
			if vertexData then
				self.staticVertexBuffer:copyData(j, mesh, vertexData)
			end
		end

		if self.skinnedVertexBuffer:has(mesh) then
			for j = 1, self:getPipelineConfig():getVertexFormatCountByRole("skinned") do
				local vertexBufferInfo = self:getPipelineConfig()
					:getVertexFormatByRole("skinned", i)
				local vertexData =
					mesh:getVertexData(vertexBufferInfo:getBufferName())
				if vertexData then
					self.skinnedVertexBuffer:copyData(j, mesh, vertexData)
				end
			end
		end

		self.indexBuffer:copyData(1, mesh, mesh:getIndexData())
	end
end

--- @private
--- @param model RatScratch.Pipeline.Graphics3D.PipelineModel
--- @param mesh RatScratch.Pipeline.Graphics3D.PipelineMesh
--- @param meshIndex integer
function ModelPipeline:_updateMesh(model, mesh, meshIndex)
	local lod = mesh:getLOD()

	self.meshClustersBuffer:registerOrResize(mesh, lod:getClusterCount())
	self.meshClustersBuffer:copyData(
		mesh,
		lod:getClusterData(),
		1,
		lod:getClusterCount()
	)

	self.meshClusterGroupsBuffer:registerOrResize(mesh, lod:getGroupCount())
	self.meshClusterGroupsBuffer:copyData(
		mesh,
		lod:getGroupData(),
		1,
		lod:getGroupCount()
	)

	self.meshClusterNodesBuffer:registerOrResize(mesh, lod:getNodeCount())
	self.meshClusterNodesBuffer:copyData(
		mesh,
		lod:getNodeData(),
		1,
		lod:getNodeCount()
	)

	local clusterIndex, clusterCount =
		self.meshClustersBuffer:getIndexCount(mesh)
	local groupIndex, groupCount =
		self.meshClusterGroupsBuffer:getIndexCount(mesh)
	local nodeIndex, nodeCount = self.meshClusterNodesBuffer:getIndexCount(mesh)

	local indexOffset = self.indexBuffer:getIndexCount(mesh)
	local staticVertexIndex = self.staticVertexBuffer:getIndexCount(mesh)
	local skinnedVertexIndex = self.skinnedVertexBuffer:has(mesh)
			and self.skinnedVertexBuffer:getIndexCount(mesh)
		or 0

	self.meshesBuffer:set(
		model,
		meshIndex,
		1,
		1,
		clusterIndex - 1,
		clusterCount,
		groupIndex - 1,
		groupCount,
		nodeIndex,
		nodeCount - 1,
		lod:getRootNodeCount(),
		indexOffset - 1,
		staticVertexIndex - 1,
		skinnedVertexIndex - 1
	)
end

do
	local _modelInfo = {}

	--- @private
	--- @param model RatScratch.Pipeline.Graphics3D.PipelineModel
	function ModelPipeline:_updateModel(model)
		local modelInfo = _modelInfo
		Table.clear(modelInfo)

		Table.append(
			modelInfo,
			Transform.getTransposedMatrix(model:getTransform())
		)

		local index, count = self.meshesBuffer:getIndexCount(model)
		Table.append(modelInfo, index - 1, count)

		self.modelsBuffer:set(model, 1, 1, unpack(modelInfo))

		for i = 1, model:getMeshCount() do
			self:_updateMesh(model, model:getMesh(i), i)
		end
	end
end

--- @private
function ModelPipeline:_updateDirtyModels()
	for model in pairs(self.dirtyModels) do
		self:_updateModel(model)

		self.dirtyModels[model] = nil
	end

	self.modelsBuffer:flush()
	self.meshesBuffer:flush()
	self.meshClustersBuffer:flush()
	self.clustersSkinnedBoundsBuffer:flush()
end

--- @private
function ModelPipeline:_updateModelBuffers()
	-- TODO: async, time limit

	for model in pairs(self.dirtyModelBuffers) do
		self:_updateModelBuffer(model)

		self.dirtyModels[model] = nil
	end

	self.staticVertexBuffer:flush()
	self.skinnedVertexBuffer:flush()
	self.indexBuffer:flush()
end

--- @private
--- @param instances RatScratch.Pipeline.ModelPipeline.ModelInstancesHandle
function ModelPipeline:_updateModelInstancesHandle(instances)
	self.modelInstancesBuffer:registerOrResize(
		instances,
		instances:getHandleCount()
	)

	for i = 1, instances:getHandleCount() do
		local handle = instances:getHandle(i)

		self.meshInstancesBuffer:registerOrResize(handle, #handle.meshes)

		local meshIndex, meshCount =
			self.meshInstancesBuffer:getIndexCount(handle)
		self.modelInstancesBuffer:set(
			instances,
			i,
			1,
			math.max(instances:getObjectIndex() - 1, 0),
			self.modelsBuffer:getIndexCount(handle.model:get()) - 1,
			meshIndex - 1,
			meshCount
		)

		for j = 1, #handle.meshes do
			self.meshInstancesBuffer:set(
				handle,
				j,
				1,
				math.max(handle.meshes[j] - 1, 0)
			)
		end
	end
end

--- @private
function ModelPipeline:_updateModelInstancesHandles()
	for instances in pairs(self.dirtyModelInstances) do
		self:_updateModelInstancesHandle(instances)
		self.dirtyModelInstances[instances] = nil
	end
end

function ModelPipeline:compact()
	self.modelsBuffer:flush()
	self.meshesBuffer:flush()
	self.meshClustersBuffer:flush()
	self.clustersSkinnedBoundsBuffer:flush()

	self.staticVertexBuffer:compact()
	self.skinnedVertexBuffer:compact()

	for _, model in ipairs(self.modelsByIndex) do
		self:_updateModel(model)
	end

	self.modelInstancesBuffer:compact()
	self.meshInstancesBuffer:compact()
	for instances in pairs(self.modelInstances) do
		self:_updateModelInstancesHandle(instances)
	end
end

function ModelPipeline:flush()
	if next(self.dirtyModels) then
		self:_updateDirtyModels()
	end

	if next(self.dirtyModelBuffers) then
		self:_updateModelBuffers()
	end

	self.meshInstancesBuffer:flush()
	self.modelInstancesBuffer:flush()
end

function ModelPipeline:update()
	if next(self.dirtyModelInstances) then
		self:_updateModelInstancesHandles()
	end
end

--- @return RatScratch.Pipeline.ModelPipeline.ModelInstancesHandle
function ModelPipeline:newModelInstances()
	local instances = ModelInstancesHandle(self)
	self.modelInstances[instances] = true

	return instances
end

--- @param instances RatScratch.Pipeline.ModelPipeline.ModelInstancesHandle
function ModelPipeline:freeModelInstances(instances)
	assert(
		self:hasModelInstances(instances),
		"model instances handle does not belong to pipeline"
	)

	self.modelInstances[instances] = nil

	for i = 1, instances:getHandleCount() do
		local handle = instances:getHandle(i)
		self:unregisterModelInstance(handle)
	end
end

--- @param instances RatScratch.Pipeline.ModelPipeline.ModelInstancesHandle
function ModelPipeline:hasModelInstances(instances)
	return self.modelInstances[instances] ~= nil
end

--- @param instances RatScratch.Pipeline.ModelPipeline.ModelInstancesHandle
function ModelPipeline:updateModelInstances(instances)
	assert(
		self:hasModelInstances(instances),
		"model instances handle does not belong to pipeline"
	)

	self.dirtyModelInstances[instances] = true
end

--- @param instances RatScratch.Pipeline.ModelPipeline.ModelInstancesHandle
function ModelPipeline:getModelInstancesPointer(instances)
	assert(
		self:hasModelInstances(instances),
		"model instances handle does not belong to pipeline"
	)

	return self.modelInstancesBuffer:newPointer(instances)
end

--- @param instance RatScratch.Pipeline.ModelPipeline.ModelInstance
function ModelPipeline:registerModelInstance(instance)
	self.meshInstancesBuffer:register(instance, #instance.meshes)
end

--- @param instance RatScratch.Pipeline.ModelPipeline.ModelInstance
--- @return boolean
function ModelPipeline:hasModelInstance(instance)
	return self.meshInstancesBuffer:has(instance)
end

--- @param instance RatScratch.Pipeline.ModelPipeline.ModelInstance
--- @return RatScratch.Pipeline.Buffer.PipelinePointer<any>
function ModelPipeline:getModelInstancePointer(instance)
	assert(
		self:hasModelInstance(instance),
		"model instance does not belong to pipeline"
	)

	return self.meshInstancesBuffer:newPointer(instance)
end

--- @param instance RatScratch.Pipeline.ModelPipeline.ModelInstance
function ModelPipeline:unregisterModelInstance(instance)
	assert(
		self:hasModelInstance(instance),
		"model instance does not belong to pipeline"
	)

	self.meshInstancesBuffer:unregister(instance)
end

return ModelPipeline
