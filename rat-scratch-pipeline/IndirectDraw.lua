local IndirectDraw = {}

IndirectDraw.INDIRECT_DRAW_FORMAT = {
	{ location = 0, name = "vertexCount", format = "uint32" },
	{ location = 1, name = "instanceCount", format = "uint32" },
	{ location = 2, name = "firstVertex", format = "uint32" },
	{ location = 3, name = "firstInstance", format = "uint32" },
}

return IndirectDraw
