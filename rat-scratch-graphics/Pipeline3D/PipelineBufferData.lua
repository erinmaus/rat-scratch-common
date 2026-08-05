local Object = require("rat-scratch-common").Object
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")

--- @class RatScratch.Graphics.Pipeline3D.PipelineBufferData : RatScratch.Common.BaseObject
--- @overload fun(format: RatScratch.Graphics.Graphics3D.MeshFormatAttribute[], count: integer, dirtyContext: RatScratch.Graphics.Pipeline3D.PipelineBufferDirtyContext): RatScratch.Graphics.Pipeline3D.PipelineBufferData
--- @field private format RatScratch.Graphics.Graphics3D.BufferFormat
--- @field private count integer
local PipelineBufferData = Object()

--- @param format RatScratch.Graphics.Graphics3D.MeshFormatAttribute[]
--- @param count integer
function PipelineBufferData:new(format, count)
	self.format = BufferFormat.get(format)
	self.count = count
end

function PipelineBufferData:getFormat()
	return self.format
end

function PipelineBufferData:getCount()
	return self.count
end

--- comment
--- @param count integer
function PipelineBufferData:resize(count)
	self.count = count
end

--- @param fromIndex integer
--- @param toIndex integer
--- @param count integer
function PipelineBufferData:compact(fromIndex, toIndex, count)
	self:ABSTRACT()
end

--- @param index integer
--- @param count integer
function PipelineBufferData:initialize(index, count)
	self:ABSTRACT()
end

--- @param index integer
--- @param count integer
--- @param ... number
function PipelineBufferData:set(index, count, ...)
	self:ABSTRACT()
end

--- @param index integer
--- @param count integer
--- @param data love.ByteData
--- @param offset? integer
function PipelineBufferData:copyFromData(index, count, data, offset)
	self:ABSTRACT()
end

--- @param index integer
--- @param count integer
--- @param data number[]
--- @param offset? integer
function PipelineBufferData:copyFromTable(index, count, data, offset)
	self:ABSTRACT()
end

--- @param buffer love.graphics.GraphicsBuffer
--- @param index integer
--- @param count integer
function PipelineBufferData:toBuffer(buffer, index, count)
	self:ABSTRACT()
end

return PipelineBufferData
