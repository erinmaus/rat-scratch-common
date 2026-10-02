local PipelineLOD = {}

PipelineLOD.GROUP_FORMAT = {
	{ location = 0, name = "bounds", format = "floatvec4" },
	{ location = 1, name = "error", format = "float" },
	{ location = 2, name = "clusterIndexCount", format = "uint32vec2" },
}

PipelineLOD.CLUSTER_FORMAT = {
	{ location = 0, name = "bounds", format = "floatvec4" },
	{ location = 1, name = "error", format = "float" },
	{ location = 2, name = "refinedIndex", format = "uint32" },
	{ location = 3, name = "indexOffetCount", format = "uint32vec2" },
}

PipelineLOD.NODE_FORMAT = {
	{ location = 0, name = "bounds", format = "floatvec4" },
	{ location = 1, name = "group", format = "int32" },
	{ location = 2, name = "childOffetCount", format = "uint32vec2" },
}

return PipelineLOD
