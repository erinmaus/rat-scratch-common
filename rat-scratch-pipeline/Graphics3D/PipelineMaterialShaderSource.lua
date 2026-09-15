local Object = require("rat-scratch-common").Object

--- @alias RatScratch.Pipeline.Graphics3D.PipelineMaterialShaderSourceType "light" | "vertex" | "fragment" | "depth"

--- @class RatScratch.Pipeline.Graphics3D.PipelineMaterialShaderSource : RatScratch.Common.BaseObject
--- @field private vertexSource? string
--- @field private fragmentSource? string
--- @field private lightSource? string
--- @field private depthSource? string
--- @overload fun(shaders?: table<RatScratch.Pipeline.Graphics3D.PipelineMaterialShaderSourceType, string>): RatScratch.Pipeline.Graphics3D.PipelineMaterialShaderSource
local PipelineMaterialShaderSource = Object()

--- @param shaders? table<RatScratch.Pipeline.Graphics3D.PipelineMaterialShaderSourceType, string>
function PipelineMaterialShaderSource:new(shaders)
	self.vertexSource = shaders and shaders.vertex or nil
	self.fragmentSource = shaders and shaders.fragment or nil
	self.lightSource = shaders and shaders.light or nil
	self.depthSource = shaders and shaders.depth or nil
end

function PipelineMaterialShaderSource:hasVertexShader()
	return self.vertexSource ~= nil
end

function PipelineMaterialShaderSource:hasFragmentShader()
	return self.fragmentSource ~= nil
end

function PipelineMaterialShaderSource:hasLightShader()
	return self.lightSource ~= nil
end

function PipelineMaterialShaderSource:hasDepthShader()
	return self.depthSource ~= nil
end

function PipelineMaterialShaderSource:getVertexShaderSource()
	return self.vertexSource or ""
end

function PipelineMaterialShaderSource:getFragmentShaderSource()
	return self.fragmentSource or ""
end

function PipelineMaterialShaderSource:getLightShaderSource()
	return self.lightSource or ""
end

function PipelineMaterialShaderSource:getDepthShaderSource()
	return self.depthSource or ""
end

--- @param shaderSourceDefinition RatScratch.Pipeline.Graphics3D.PipelineMaterialDefinitionShaderSource
function PipelineMaterialShaderSource.fromDefinition(shaderSourceDefinition)
	return PipelineMaterialShaderSource(shaderSourceDefinition)
end

return PipelineMaterialShaderSource
