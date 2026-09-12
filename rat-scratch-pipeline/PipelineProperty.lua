local Object = require("rat-scratch-common").Object

--- @class RatScratch.Pipeline.PipelineProperty : RatScratch.Common.BaseObject
--- @field private key string
--- @field private identifier string
--- @field private format RatScratch.Graphics.Graphics3D.BufferAttributeFormat | "boolean"
--- @field private value (integer | number | boolean)[]
--- @overload fun(property: RatScratch.Pipeline.PipelineRuntimeConfigProperty): RatScratch.Pipeline.PipelineProperty
local PipelineProperty = Object()

--- @param property RatScratch.Pipeline.PipelineRuntimeConfigProperty
function PipelineProperty:new(property)
	self.key = property.key
	self.identifier = property.identifier
	self.format = property.format
	self.value = property.default
end

--- @return string
function PipelineProperty:getKey()
	return self.key
end

--- @return string
function PipelineProperty:getIdentifier()
	return self.identifier
end

--- @return RatScratch.Graphics.Graphics3D.BufferAttributeFormat | "boolean"
function PipelineProperty:getFormat()
	return self.format
end

--- @return boolean|number|integer ...
function PipelineProperty:getValue()
	return unpack(self.value)
end

return PipelineProperty
