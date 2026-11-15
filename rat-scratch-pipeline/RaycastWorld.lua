local Object = require("rat-scratch-common").Object
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local AccelerationStructure =
	require("rat-scratch-graphics.AccelerationStructure")
local BLASInstance = require("rat-scratch-graphics.BLASInstance")
local BLASInstanceBVH = require("rat-scratch-graphics.BLASInstanceBVH")
local BVH = require("rat-scratch-graphics.BVH")
local ModelPipeline = require("rat-scratch-pipeline.ModelPipeline")
local ObjectHandleEvent = require("rat-scratch-pipeline.ObjectHandleEvent")
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local Table = require("rat-scratch-common.Table")
local Transform = require("rat-scratch-math.Transform")

--- @alias RatScratch.Pipeline.RaycastWorld.impl.WeakSceneInfo {
---   objectHandles: RatScratch.Pipeline.ObjectHandle[],
---   blasInstances: RatScratch.Graphics.BLASInstance<RatScratch.Pipeline.Graphics3D.PipelineMesh>[],
---   bvh: RatScratch.Graphics.BLASInstanceBVH,
---   tlas: RatScratch.Graphics.AccelerationStructure,
---   proxy: userdata,
--- }

--- @alias RatScratch.Pipeline.RaycastWorld.impl.ObjectHandleBLASInstances {
---   count: integer,
---   instances: RatScratch.Graphics.BLASInstance<RatScratch.Pipeline.Graphics3D.PipelineMesh>[],
--- }

--- @class RatScratch.Pipeline.RaycastWorld : RatScratch.Common.BaseObject
--- @field private tlas table<RatScratch.Graphics.AccelerationStructure, true>
--- @field private scenes table<RatScratch.Pipeline.Scene, RatScratch.Pipeline.RaycastWorld.impl.WeakSceneInfo>
--- @field private blasInstancesByObjectHandle table<RatScratch.Pipeline.ObjectHandle, RatScratch.Pipeline.RaycastWorld.impl.ObjectHandleBLASInstances>
--- @field private models table<RatScratch.Pipeline.Graphics3D.PipelineModel, true>
--- @field private dirtyModels table<RatScratch.Pipeline.Graphics3D.PipelineModel, true>
--- @overload fun(world: RatScratch.Pipeline.World): RatScratch.Pipeline.RaycastWorld
local RaycastWorld = Object()

RaycastWorld.OBJECT_INDEX_FORMAT = {
	{ location = 0, name = "index", format = "uint32" },
}

RaycastWorld.DEFAULT_BVH_NODES_COUNT = 2 ^ 16
RaycastWorld.DEFAULT_BLAS_INSTANCE_COUNT = 2 ^ 16

--- @param world RatScratch.Pipeline.World
function RaycastWorld:new(world)
	self.world = world

	self.bvhNodesBuffer = PipelineBuffer(
		AccelerationStructure.NODE_FORMAT,
		{ shaderstorage = true },
		RaycastWorld.DEFAULT_BVH_NODES_COUNT
	)

	self.blasInstances = {}
	self.blasInstancesBuffer = PipelineBuffer(
		BLASInstance.FORMAT,
		{ shaderstorage = true },
		RaycastWorld.DEFAULT_BLAS_INSTANCE_COUNT
	)

	self.bvhObjectIndicesBuffer = PipelineBuffer(
		RaycastWorld.OBJECT_INDEX_FORMAT,
		{ shaderstorage = true },
		RaycastWorld.DEFAULT_BVH_NODES_COUNT
	)

	self.blasInstancesByObjectHandle = {}

	self.models = {}
	self.dirtyModels = {}

	self.scenes = setmetatable({}, { __mode = "k" })
	self.dirtyScenes = setmetatable({}, { __mode = "k" })

	self.blasInstanceData = {}
	BufferFormat.resetValue(BLASInstance.FORMAT_INSTANCE, self.blasInstanceData)
end

--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function RaycastWorld:addObjectHandle(objectHandle)
	self.blasInstancesByObjectHandle[objectHandle] =
		{ count = 0, instances = {} }

	objectHandle:listen(
		ObjectHandleEvent.SCENE_UPDATED,
		self._onObjectHandleUpdateScene,
		self
	)
end

--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function RaycastWorld:removeObjectHandle(objectHandle)
	self.blasInstancesByObjectHandle[objectHandle] = nil

	objectHandle:silence(
		ObjectHandleEvent.SCENE_UPDATED,
		self._onObjectHandleUpdateScene,
		self
	)
end

--- @private
--- @param proxy userdata
function RaycastWorld._collectSceneInfo(proxy)
	local mt = getmetatable(proxy)

	--- @type RatScratch.Pipeline.Scene
	local scene = mt.scene

	--- @type RatScratch.Pipeline.RaycastWorld
	local world = mt.world

	world.dirtyScenes[scene] = nil
end

--- @private
--- @param scene RatScratch.Pipeline.Scene
function RaycastWorld:_getSceneInfo(scene)
	local sceneInfo = self.scenes[scene]
	if not sceneInfo then
		sceneInfo = {
			objectHandles = {},
			blasInstances = {},
			bvh = BLASInstanceBVH(1, 1),
			tlas = AccelerationStructure(1),
			proxy = newproxy(true),
		}

		local mt = getmetatable(sceneInfo.proxy)
		mt.world = self
		mt.scene = scene
		mt.__gc = RaycastWorld._collectSceneInfo

		self.scenes[scene] = sceneInfo
	end

	return sceneInfo
end

--- @param model RatScratch.Pipeline.Graphics3D.PipelineModel
function RaycastWorld:addModel(model)
	for i = 1, model:getMeshCount() do
		local mesh = model:getMesh(i)
		local blas = mesh:getBLAS()

		if not self.bvhNodesBuffer:has(blas) then
			self.bvhNodesBuffer:register(blas, blas:getNodeCount() + 1)
			self.bvhNodesBuffer:copyData(
				blas,
				blas:getNodeData(),
				1,
				blas:getNodeCount() + 1,
				0
			)
		end

		if not self.bvhObjectIndicesBuffer:has(blas) then
			self.bvhObjectIndicesBuffer:register(blas, blas:getIndexCount())
			self.bvhObjectIndicesBuffer:copyData(
				blas,
				blas:getIndexData(),
				1,
				blas:getIndexCount(),
				0
			)
		end
	end

	self.dirtyModels[model] = true
	self.models[model] = true
end

function RaycastWorld:removeModel(model)
	for i = 1, model:getMeshCount() do
		local mesh = model:getMesh(i)
		local blas = mesh:getBLAS()

		if self.bvhNodesBuffer:has(blas) then
			self.bvhNodesBuffer:unregister(blas)
		end

		if self.bvhObjectIndicesBuffer:has(blas) then
			self.bvhObjectIndicesBuffer:unregister(blas)
		end
	end

	self.dirtyModels[model] = nil
	self.models[model] = nil
end

--- @private
--- @param model RatScratch.Pipeline.Graphics3D.PipelineModel
function RaycastWorld:_flushModel(model)
	local modelPipeline = self.world:getPipeline(ModelPipeline)

	for i = 1, model:getMeshCount() do
		local mesh = model:getMesh(i)
		local blas = mesh:getBLAS()

		local blasIndex, c1 = self.bvhNodesBuffer:getIndexCount(blas)
		local blasIndicesIndex, c2 =
			self.bvhObjectIndicesBuffer:getIndexCount(blas)

		modelPipeline:setModelMeshBLASIndexIndicesIndex(
			model,
			i,
			blasIndex,
			blasIndicesIndex
		)
	end
end

function RaycastWorld:_flushAllModels()
	for model in pairs(self.models) do
		self:_flushModel(model)
	end
end

function RaycastWorld:_flushModels()
	for model in pairs(self.dirtyModels) do
		self:_flushModel(model)
		self.dirtyModels[model] = nil
	end
end

--- @private
--- @param event RatScratch.Pipeline.ObjectHandleEvent
--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function RaycastWorld:_onObjectHandleUpdateScene(event, objectHandle)
	local previousScene = event:getPreviousScene()

	if previousScene then
		local previousSceneInfo = self:_getSceneInfo(previousScene)
		Table.remove(previousSceneInfo.objectHandles, objectHandle)
	end

	local currentScene = event:getScene()
	local currentSceneInfo = self:_getSceneInfo(currentScene)
	table.insert(currentSceneInfo.objectHandles, objectHandle)
end

--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function RaycastWorld:updateObjectHandleModels(objectHandle)
	local modelInstancesHandle =
		self.world:getModelInstancesHandle(objectHandle)
	local blasInstances = self.blasInstancesByObjectHandle[objectHandle]
	blasInstances.count = 0

	for i = 1, modelInstancesHandle:getHandleCount() do
		local handle = modelInstancesHandle:getHandle(i)
		local model = handle.model:get()

		for j = 1, model:getMeshCount() do
			blasInstances.count = blasInstances.count + 1

			local mesh = model:getMesh(j)
			local minBounds, maxBounds = mesh:getBounds()
			local blasInstance = blasInstances.instances[blasInstances.count]
			if not blasInstance then
				blasInstance = BLASInstance(mesh, minBounds, maxBounds)
				blasInstances.instances[blasInstances.count] = blasInstance
			else
				blasInstance = blasInstance:init(mesh, minBounds, maxBounds)
			end

			table.insert(blasInstances.instances, blasInstance)
		end
	end

	self:updateBLASInstancesTransform(objectHandle)
end

do
	local _transform = love.math.newTransform()

	--- @param objectHandle RatScratch.Pipeline.ObjectHandle
	function RaycastWorld:updateBLASInstancesTransform(objectHandle)
		local modelInstancesHandle =
			self.world:getModelInstancesHandle(objectHandle)

		local blasInstances = self.blasInstancesByObjectHandle[objectHandle]
		if not blasInstances then
			return
		end

		local combinedWorldLocalTransform = _transform

		local index = 0
		for i = 1, modelInstancesHandle:getHandleCount() do
			local handle = modelInstancesHandle:getHandle(i)
			local model = handle.model:get()

			for j = 1, model:getMeshCount() do
				index = index + 1

				combinedWorldLocalTransform:setMatrix(
					model:getTransform():getMatrix()
				)
				combinedWorldLocalTransform:apply(objectHandle:getTransform())

				local blasInstance = blasInstances.instances[index]
				blasInstance:setTransform(combinedWorldLocalTransform)
			end
		end

		self.dirtyScenes[objectHandle:getScene()] = true
	end
end

function RaycastWorld:updateScene(scene)
	local sceneInfo = self:_getSceneInfo(scene)

	local objectHandles = sceneInfo.objectHandles
	local blasInstances = sceneInfo.blasInstances

	Table.clear(blasInstances)
	for _, objectHandle in ipairs(objectHandles) do
		local blasInstancesByObjectHandle =
			self.blasInstancesByObjectHandle[objectHandle]
		for i = 1, blasInstancesByObjectHandle.count do
			local blasInstance = blasInstancesByObjectHandle.instances[i]
			table.insert(blasInstances, blasInstance)
		end
	end

	local bvh = sceneInfo.bvh
	BLASInstanceBVH.fromBLASInstances(
		BVH.DEFAULT_STACKLESS_BUILD_STRATEGY,
		blasInstances,
		bvh
	)

	local tlas = sceneInfo.tlas
	AccelerationStructure.fromBVH(tlas, bvh)

	self.dirtyScenes[scene] = true
end

--- @private
--- @param scene RatScratch.Pipeline.Scene
function RaycastWorld:_prepareDirtyScene(scene)
	local sceneInfo = self.scenes[scene]
	if not sceneInfo then
		return
	end

	local tlas = sceneInfo.tlas
	do
		self.bvhNodesBuffer:registerOrResize(tlas, tlas:getNodeCount())
		self.bvhNodesBuffer:copyTable(
			tlas,
			tlas:getNodes(),
			1,
			tlas:getNodeCount(),
			1
		)

		self.bvhObjectIndicesBuffer:registerOrResize(tlas, tlas:getIndexCount())
		self.bvhObjectIndicesBuffer:copyTable(
			tlas,
			tlas:getIndices(),
			1,
			tlas:getIndexCount(),
			1
		)
	end

	local blasInstances = sceneInfo.blasInstances
	self.blasInstancesBuffer:registerOrResize(
		blasInstances,
		math.max(#blasInstances, 1)
	)
end

function RaycastWorld:_prepareDirtyScenes()
	for scene in pairs(self.dirtyScenes) do
		self:_prepareDirtyScene(scene)
	end
end

function RaycastWorld:_flushDirtyScene(scene)
	local sceneInfo = self.scenes[scene]
	if not sceneInfo then
		return
	end

	local blasInstances = sceneInfo.blasInstances
	for i, blasInstance in ipairs(blasInstances) do
		local mesh = blasInstance:getInstance()
		local blas = mesh:getBLAS()

		local bvhIndex = self.bvhNodesBuffer:getIndexCount(blas)
		local bvhOffset = self.bvhObjectIndicesBuffer:getIndexCount(blas)

		self.blasInstancesBuffer:set(
			blasInstances,
			i,
			1,
			blasInstance:getTag(),
			bvhIndex - 1,
			bvhOffset - 1,
			Transform.getTransposedMatrix(blasInstance:getTransform())
		)
	end
end

function RaycastWorld:_flushDirtyScenes()
	for scene in pairs(self.dirtyScenes) do
		self:_flushDirtyScene(scene)
	end
end

function RaycastWorld:flush()
	if next(self.dirtyScenes) then
		self:_prepareDirtyScenes()
	end

	do
		local nodesCompacted = self.bvhNodesBuffer:compact()
		local objectIndicesCompacted = self.bvhObjectIndicesBuffer:compact()
		self.blasInstancesBuffer:compact()

		local allModelsDirty = nodesCompacted or objectIndicesCompacted
		if allModelsDirty then
			self:_flushAllModels()
		else
			self:_flushModels()
		end
	end

	if next(self.dirtyScenes) then
		self:_flushDirtyScenes()
		Table.clear(self.dirtyScenes)
	end

	self.bvhNodesBuffer:flush()
	self.bvhObjectIndicesBuffer:flush()
	self.blasInstancesBuffer:flush()
end

return RaycastWorld
