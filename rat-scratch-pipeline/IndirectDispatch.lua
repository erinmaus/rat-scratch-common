local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat

local IndirectDispatch = {}

IndirectDispatch.INDIRECT_DISPATCH_FORMAT = {
	{ location = 0, name = "dispatchX", format = "uint32" },
	{ location = 1, name = "dispatchY", format = "uint32" },
	{ location = 2, name = "dispatchZ", format = "uint32" },
}

IndirectDispatch.INDIRECT_DISPATCH_FORMAT_INSTANCE =
	BufferFormat.get(IndirectDispatch.INDIRECT_DISPATCH_FORMAT)

return IndirectDispatch
