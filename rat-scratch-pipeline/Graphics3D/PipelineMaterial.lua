local Object = require("rat-scratch-common").Object
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")
local PipelineMaterialShaderSource =
	require("rat-scratch-pipeline.Graphics3D.PipelineMaterialShaderSource")
local PipelineMaterialUniform =
	require("rat-scratch-pipeline.Graphics3D.PipelineMaterialUniform")

--- @class RatScratch.Pipeline.Graphics3D.PipelineMaterial : RatScratch.Common.BaseObject
--- @field private format RatScratch.Graphics.Graphics3D.BufferFormat
--- @field private uniforms RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform[]
--- @field private uniformsByName table<string, RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform>
--- @field private shader RatScratch.Pipeline.Graphics3D.PipelineMaterialShaderSource
--- @overload fun(format: RatScratch.Graphics.Graphics3D.BufferFormat, uniforms: RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform[], shader: RatScratch.Pipeline.Graphics3D.PipelineMaterialShaderSource): RatScratch.Pipeline.Graphics3D.PipelineMaterial
local PipelineMaterial = Object()

--- @param name string
--- @param format RatScratch.Graphics.Graphics3D.BufferFormat
--- @param uniforms RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform[]
--- @param shader RatScratch.Pipeline.Graphics3D.PipelineMaterialShaderSource
function PipelineMaterial:new(name, format, uniforms, shader)
	self.name = name
	self.format = format

	self.uniforms = uniforms
	self.uniformsByName = {}
	for _, uniform in ipairs(uniforms) do
		self.uniformsByName[uniform:getName()] = uniform
	end

	self.shader = shader
end

function PipelineMaterial:getName()
	return self.name
end

function PipelineMaterial:getFormat()
	return self.format
end

function PipelineMaterial:getUniformCount()
	return #self.uniforms
end

--- @param key integer | string
--- @return boolean
function PipelineMaterial:hasUniform(key)
	return self:getUniform(key) ~= nil
end

--- @param key integer | string
--- @return RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform
function PipelineMaterial:getUniform(key)
	return self.uniformsByName[key] or self.uniforms[key]
end

function PipelineMaterial:getShader()
	return self.shader
end

--- @param materialDefinition RatScratch.Pipeline.Graphics3D.PipelineMaterialDefinition
function PipelineMaterial.fromDefinition(materialDefinition)
	local shader = materialDefinition.shader
			and PipelineMaterialShaderSource.fromDefinition(
				materialDefinition.shader
			)
		or PipelineMaterialShaderSource()

	--- @type RatScratch.Graphics.Graphics3D.InputBufferFormatAttribute[]
	local format = {}
	if not materialDefinition.uniforms or #materialDefinition.uniforms == 0 then
		table.insert(format, {
			name = "x_empty",
			format = "float",
		})
	else
		for _, uniform in ipairs(materialDefinition.uniforms) do
			local format
			if uniform.format == "texture" then
				table.insert(format, {
					name = uniform.name,
					format = "uint32",
				})
			else
				table.insert(format, {
					name = uniform.name,
					format = uniform.format,
				})
			end
		end
	end

	local formatInstance = BufferFormat(format)

	--- @type RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform[]
	local uniforms = {}
	if not materialDefinition.uniforms or #materialDefinition.uniforms == 0 then
		table.insert(
			uniforms,
			PipelineMaterialUniform("x_empty", "float", { 0 }, 0)
		)
	else
		for _, uniform in ipairs(materialDefinition.uniforms) do
			table.insert(
				uniform,
				PipelineMaterialUniform(
					uniform.name,
					uniform.format,
					uniform.value,
					formatInstance:getByteOffset(uniform.name)
				)
			)
		end
	end

	return PipelineMaterial(formatInstance, uniforms, shader)
end

return PipelineMaterial
