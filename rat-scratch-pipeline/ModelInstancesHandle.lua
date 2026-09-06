local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table

--- @class RatScratch.Pipeline.ModelPipeline.MeshInstance
--- @field public material integer

--- @class RatScratch.Pipeline.ModelPipeline.ModelInstance
--- @field public model RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @field public index integer
--- @field public meshes integer[]

--- @class RatScratch.Pipeline.ModelPipeline.ModelInstancesHandle
--- @field private pipeline RatScratch.Pipeline.ModelPipeline
--- @field private modelsByIndex RatScratch.Pipeline.ModelPipeline.ModelInstance[]
--- @field private models table<RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>, RatScratch.Pipeline.ModelPipeline.ModelInstance>
--- @overload fun(pipeline: RatScratch.Pipeline.ModelPipeline): RatScratch.Pipeline.ModelPipeline.ModelInstancesHandle
local ModelInstancesHandle = Object()

--- @param pipeline RatScratch.Pipeline.ModelPipeline
function ModelInstancesHandle:new(pipeline)
	self.pipeline = pipeline
	self.models = {}
	self.modelsByIndex = {}
	self.objectIndex = 0
end

--- @return integer
function ModelInstancesHandle:getObjectIndex()
	return self.objectIndex
end

--- @param value integer
function ModelInstancesHandle:setObjectIndex(value)
	self.objectIndex = value
end

--- @param model RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
function ModelInstancesHandle:add(model)
	if not self.models[model] then
		table.insert(self.modelsByIndex, model)

		--- @type RatScratch.Pipeline.ModelPipeline.ModelInstance
		local modelInstance = {
			model = model,
			index = 0,
			meshes = {},
		}

		for i = 1, model:get():getMeshCount() do
			modelInstance[i] = 0
		end

		self.models[model] = modelInstance

		self:updateModelInstances(model)
		return true
	end

	return self
end

--- @param model RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
function ModelInstancesHandle:remove(model)
	if self.models[model] then
		self.pipeline:unregisterModelInstance(self.models[model])

		self.models[model] = nil
		Table.remove(self.modelsByIndex, model)
	end
end

function ModelInstancesHandle:getHandleCount()
	return #self.modelsByIndex
end

--- @param model integer | RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @return integer
function ModelInstancesHandle:getModelIndex(model)
	local handle = self:getHandle(model)
	return handle and handle.index or 0
end

--- @param model integer | RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @param index integer
function ModelInstancesHandle:setModelIndex(model, index)
	local handle = self:getHandle(model)
	if handle then
		handle.index = index
	end
end

--- @param model integer | RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @return RatScratch.Pipeline.ModelPipeline.ModelInstance
function ModelInstancesHandle:getHandle(model)
	return self.models[model] or self.models[self.modelsByIndex[model]]
end

--- @param model integer | RatScratch.Resource.Resource<RatScratch.Pipeline.Graphics3D.PipelineModel>
--- @param meshIndex integer
--- @param materialIndex integer
function ModelInstancesHandle:setMaterial(model, meshIndex, materialIndex)
	local handle = self:getHandle(model)
	if handle then
		handle.meshes[meshIndex] = materialIndex
	end
end

function ModelInstancesHandle:calculateMeshletCount()
	local count = 0
	for _, handle in ipairs(self.modelsByIndex) do
		local model = handle.model:get()
		if model then
			for i = 1, model:getMeshCount() do
				count = count + model:getMesh(i):getMeshletCount()
			end
		end
	end

	return count
end

return ModelInstancesHandle
