local Object = require("rat-scratch-common").Object
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat

--- @class RatScratch.Pipeline.IndexBufferInfo : RatScratch.Common.BaseObject
--- @overload fun(format: RatScratch.Pipeline.PipelineDefinitionIndexBuffer): RatScratch.Pipeline.IndexBufferInfo
--- @field private indexFormatInstance RatScratch.Graphics.Graphics3D.BufferFormat
local IndexBufferInfo = Object()

--- @param format RatScratch.Pipeline.PipelineDefinitionIndexBuffer
function IndexBufferInfo:new(format)
	self.indexFormatInstance = BufferFormat({
		{ location = 0, name = format.name, format = format.format },
	})

	self.bufferName = format.buffer
end

function IndexBufferInfo:getIndexFormat()
	return self.indexFormatInstance
end

function IndexBufferInfo:getBufferName()
	return self.bufferName
end

return IndexBufferInfo
