local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local ModelInstancesHandle =
	require("rat-scratch-pipeline.ModelInstancesHandle")
local Pipeline = require("rat-scratch-pipeline.impl.Pipeline")
local PipelineMultiBuffer =
	require("rat-scratch-pipeline.Buffer.PipelineMultiBuffer")
local Transform = require("rat-scratch-math").Transform

--- @class RatScratch.Pipeline.ObjectPipeline : RatScratch.Pipeline.impl.Pipeline
--- @field private modelsInstance RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Graphics3D.PipelineMesh>
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.ObjectPipeline
local ObjectPipeline = Object(Pipeline)

ObjectPipeline.OBJECT_INSTANCE_FORMAT = {
	{ location = 0, name = "worldTransform", format = "floatmat4x4" },
	{ location = 1, name = "modelInstanceIndexCount", format = "uint32vec2" },
	{ location = 2, name = "boneTransformIndexCount", format = "uint32vec2" },
}

ObjectPipeline.DEFAULT_OBJECT_INSTANCE_COUNT = 1024

--- @param pipelineRuntime RatScratch.Pipeline.PipelineRuntime
function ObjectPipeline:new(pipelineRuntime)
	Pipeline.new(self, pipelineRuntime)

	self.objectInstancesBuffer = PipelineBuffer(
		ObjectPipeline.OBJECT_INSTANCE_FORMAT,
		{ shaderstorage = true },
		ObjectPipeline.DEFAULT_OBJECT_INSTANCE_COUNT
	)

	self.objectHandles = {}
end

--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function ObjectPipeline:addObject(objectHandle)
	assert(not self.objectHandles[objectHandle], "object exists in pipeline")

	self.objectInstancesBuffer:register(objectHandle, 1)

	self.objectHandles[objectHandle] = true
end

--- @param objectHandle RatScratch.Pipeline.ObjectHandle
function ObjectPipeline:removeObject(objectHandle)
	assert(
		self.objectHandles[objectHandle],
		"object does not exist in pipeline"
	)

	self.objectInstancesBuffer:unregister(objectHandle)

	self.objectHandles[objectHandle] = nil
end

do
	local _bufferData = {}

	--- @param objectHandle RatScratch.Pipeline.ObjectHandle
	function ObjectPipeline:updateObject(objectHandle)
		assert(
			self.objectHandles[objectHandle],
			"object does not exist in pipeline"
		)

		local data = _bufferData
		Table.clear(data)

		local bonesPointer = objectHandle:getPointer("bones")
		local modelsPointer = objectHandle:getPointer("models")

		Table.append(
			data,
			Transform.getTransposedMatrix(objectHandle:getTransform())
		)

		local bonesOffset, bonesCount = bonesPointer:getOffsetCount()
		Table.append(data, bonesOffset, bonesCount)

		local modelsOffset, modelsCount = modelsPointer:getOffsetCount()
		Table.append(data, modelsOffset, modelsCount)

		self.objectInstancesBuffer:set(
			objectHandle,
			1,
			1,
			Table.unpack(data, 1, #data)
		)
	end
end

function ObjectPipeline:flush()
	self.objectInstancesBuffer:flush()
end

function ObjectPipeline:update()
	-- Nothing.
end

return ObjectPipeline
