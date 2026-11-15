local Object = require("rat-scratch-common").Object
local Vector3 = require("rat-scratch-math").Vector3
local ffi = require("ffi")
local AccelerationStructure =
	require("rat-scratch-graphics").AccelerationStructure

--- @class RatScratch.Pipeline.Graphics3D.PipelineBLAS : RatScratch.Common.BaseObject
--- @field private nodes love.Data
--- @field private indices love.Data
--- @field private minBounds RatScratch.Math.Vector3
--- @field private maxBounds RatScratch.Math.Vector3
--- @field private blas RatScratch.Graphics.AccelerationStructure
--- @overload fun(nodes: love.Data, indices: love.Data, minBounds: RatScratch.Math.Vector3, maxBounds: RatScratch.Math.Vector3): RatScratch.Pipeline.Graphics3D.PipelineBLAS
local PipelineBLAS = Object()

--- @param nodes love.Data
--- @param indices love.Data
--- @param minBounds RatScratch.Math.Vector3
--- @param maxBounds RatScratch.Math.Vector3
function PipelineBLAS:new(nodes, indices, minBounds, maxBounds)
	self.nodes = nodes
	self.nodeCount = math.floor(
		nodes:getSize() / AccelerationStructure.NODE_FORMAT_INSTANCE:getStride()
	)
	self.indices = indices
	self.indexCount = math.floor(indices:getSize() / ffi.sizeof("uint32_t"))
	self.minBounds = minBounds
	self.maxBounds = maxBounds
end

function PipelineBLAS:getNodeData()
	return self.nodes
end

function PipelineBLAS:getNodeCount()
	return self.nodeCount
end

function PipelineBLAS:getIndexData()
	return self.nodes
end

function PipelineBLAS:getIndexCount()
	return self.nodeCount
end

function PipelineBLAS:getBounds()
	return self.minBounds, self.maxBounds
end

function PipelineBLAS:getBLAS()
	if not self.blas then
		self.blas =
			AccelerationStructure.fromData(nil, self.nodes, self.indices)
	end

	return self.blas
end

--- @param definition RatScratch.Pipeline.Graphics3D.PipelineBLASDefinition
function PipelineBLAS.fromDefinition(definition)
	return PipelineBLAS(
		definition.nodes,
		definition.indices,
		Vector3(unpack(definition.minBounds)),
		Vector3(unpack(definition.maxBounds))
	)
end

return PipelineBLAS
