local Object = require("rat-scratch-common").Object

--- @class RatScratch.Pipeline.MeshletFormat : RatScratch.Common.BaseObject
--- @overload fun(format: RatScratch.Pipeline.PipelineDefinitionMeshleftFormat): RatScratch.Pipeline.MeshletFormat
--- @field private triangleCount integer
local MeshletFormat = Object()

--- @param format RatScratch.Pipeline.PipelineDefinitionMeshleftFormat
function MeshletFormat:new(format)
	self.triangleCount = format.triangleCount
end

--- @return integer
function MeshletFormat:getTriangleCount()
	return self.triangleCount
end

return MeshletFormat
