local PATH = ...
local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object

--- @class RatScratch.Pipeline.Graphics3D.PipelineMaterialShaderSource : RatScratch.Common.BaseObject
--- @overload fun(vertexSource?: string, fragmentSource?: string): RatScratch.Pipeline.Graphics3D.PipelineMaterialShaderSource
local PipelineMaterialShaderSource = Object()

function PipelineMaterialShaderSource:new(vertexSource, fragmentSource)
	self.vertexSource = vertexSource
	self.fragmentSource = fragmentSource
end

function PipelineMaterialShaderSource:hasVertexShader()
	return self.vertexSource ~= nil
end

function PipelineMaterialShaderSource:hasFragmentShader()
	return self.fragmentSource ~= nil
end

function PipelineMaterialShaderSource:getVertexShaderSource()
	return self.vertexSource or ""
end

function PipelineMaterialShaderSource:getFragmentShaderSource()
	return self.fragmentSource or ""
end

--- @param shaderSourceDefinition RatScratch.Pipeline.Graphics3D.PipelineMaterialDefinitionShaderSource
function PipelineMaterialShaderSource.fromDefinition(shaderSourceDefinition)
	return PipelineMaterialShaderSource(
		shaderSourceDefinition.vertex,
		shaderSourceDefinition.fragment
	)
end

return PipelineMaterialShaderSource
