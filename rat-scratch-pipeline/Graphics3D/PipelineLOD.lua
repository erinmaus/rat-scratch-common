local Object = require("rat-scratch-common").Object
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat

--- @class RatScratch.Pipeline.Graphics3D.PipelineLOD : RatScratch.Common.BaseObject
--- @field private clusters love.Data
--- @field private groups love.Data
--- @field private nodes love.Data
--- @field private rootNodeCount integer
--- @overload fun(clusters: love.Data, groups: love.Data, nodes: love.Data, rootNodeCount: integer): RatScratch.Pipeline.Graphics3D.PipelineLOD
local PipelineLOD = Object()

PipelineLOD.GROUP_FORMAT = {
	{ location = 0, name = "boundsPositionRadius", format = "floatvec4" },
	{ location = 1, name = "error", format = "float" },
	{ location = 2, name = "lodDepth", format = "uint32" },
	{ location = 3, name = "clusterIndexCount", format = "uint32vec2" },
}

PipelineLOD.CLUSTER_FORMAT = {
	{ location = 0, name = "boundsPositionRadius", format = "floatvec4" },
	{ location = 1, name = "error", format = "float" },
	{ location = 2, name = "refinedIndex", format = "uint32" },
	{ location = 3, name = "indexOffsetCount", format = "uint32vec2" },
}

PipelineLOD.NODE_FORMAT = {
	{ location = 0, name = "boundsPositionRadius", format = "floatvec4" },
	{ location = 1, name = "error", format = "float" },
	{ location = 2, name = "groupIndex", format = "int32" },
	{ location = 3, name = "childIndexCount", format = "uint32vec2" },
}

--- @param clusters love.Data
--- @param groups love.Data
--- @param nodes love.Data
--- @param rootNodeCount integer
function PipelineLOD:new(clusters, groups, nodes, rootNodeCount)
	self.clusters = clusters
	self.clusterCount = self.clusters:getSize()
		/ BufferFormat.get(PipelineLOD.CLUSTER_FORMAT):getStride()
	self.groups = groups
	self.groupCount = self.groups:getSize()
		/ BufferFormat.get(PipelineLOD.GROUP_FORMAT):getStride()
	self.nodes = nodes
	self.nodeCount = self.nodes:getSize()
		/ BufferFormat.get(PipelineLOD.NODE_FORMAT):getStride()
	self.rootNodeCount = rootNodeCount
end

function PipelineLOD:getClusterData()
	return self.clusters
end

function PipelineLOD:getClusterCount()
	return self.clusterCount
end

function PipelineLOD:getGroupData()
	return self.groups
end

function PipelineLOD:getGroupCount()
	return self.groupCount
end

function PipelineLOD:getNodeData()
	return self.nodes
end

function PipelineLOD:getNodeCount()
	return self.nodeCount
end

function PipelineLOD:getRootNodeCount()
	return self.rootNodeCount
end

--- @param definition RatScratch.Pipeline.Graphics3D.PipelineLODDefinition
function PipelineLOD.fromDefinition(definition)
	return PipelineLOD(
		definition.clusters,
		definition.groups,
		definition.nodes,
		definition.rootNodeCount
	)
end

return PipelineLOD
