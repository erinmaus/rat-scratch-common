local Object = require("rat-scratch-common").Object
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat

--- @class RatScratch.Pipeline.IndexBufferFormat : RatScratch.Common.BaseObject
--- @overload fun(format: RatScratch.Pipeline.PipelineDefinitionIndexBuffer): RatScratch.Pipeline.IndexBufferFormat
--- @field private indexFormatInstance RatScratch.Graphics.Graphics3D.BufferFormat
local IndexBufferFormat = Object()

--- @param format RatScratch.Pipeline.PipelineDefinitionIndexBuffer
function IndexBufferFormat:new(format)
	self.indexFormatInstance = BufferFormat({
		{ location = 0, name = format.name, format = format.format },
	})

	self.bufferName = format.buffer
end

function IndexBufferFormat:getIndexFormat()
	return self.indexFormatInstance
end

function IndexBufferFormat:getBufferName()
	return self.bufferName
end

return IndexBufferFormat
