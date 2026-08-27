local Object = require("rat-scratch-common").Object
local BufferFormat = require("rat-scratch-graphics.Graphics3D.BufferFormat")
local PipelineMaterialShaderSource =
	require("rat-scratch-pipeline.Graphics3D.PipelineMaterialShaderSource")
local PipelineMaterialUniform =
	require("rat-scratch-pipeline.Graphics3D.PipelineMaterialUniform")

--- @alias RatScratch.Pipeline.Graphics3D.PipelineMaterial.Pass "deferred" | "forward"
--- @alias RatScratch.Pipeline.Graphics3D.PipelineMaterial.Feature "discard"

--- @class RatScratch.Pipeline.Graphics3D.PipelineMaterial : RatScratch.Common.BaseObject
--- @field private name string
--- @field private extends? string
--- @field private format RatScratch.Graphics.Graphics3D.BufferFormat
--- @field private uniforms RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform[]
--- @field private uniformsByName table<string, RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform>
--- @field private passes table<RatScratch.Pipeline.Graphics3D.PipelineMaterial.Pass, boolean>
--- @field private shader RatScratch.Pipeline.Graphics3D.PipelineMaterialShaderSource
--- @overload fun(name: string, extends?: string, features: table<RatScratch.Pipeline.Graphics3D.PipelineMaterial.Feature, boolean>, format: RatScratch.Graphics.Graphics3D.BufferFormat, uniforms: RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform[], passes: table<string, RatScratch.Pipeline.Graphics3D.PipelineMaterial.Pass>, shader: RatScratch.Pipeline.Graphics3D.PipelineMaterialShaderSource): RatScratch.Pipeline.Graphics3D.PipelineMaterial
local PipelineMaterial = Object()

--- @param name string
--- @param extends? string
--- @param features table<RatScratch.Pipeline.Graphics3D.PipelineMaterial.Feature, boolean>
--- @param format RatScratch.Graphics.Graphics3D.BufferFormat
--- @param uniforms RatScratch.Pipeline.Graphics3D.PipelineMaterialUniform[]
--- @param passes table<string, RatScratch.Pipeline.Graphics3D.PipelineMaterial.Pass>
--- @param shader RatScratch.Pipeline.Graphics3D.PipelineMaterialShaderSource
function PipelineMaterial:new(
	name,
	extends,
	features,
	format,
	uniforms,
	passes,
	shader
)
	self.name = name
	self.extends = extends
	self.features = features
	self.format = format

	local integerFormat = {}
	local floatFormat = {}
	for i = 1, self.format:getAttributeCount() do
		local attributeLocation, attributeName, attributeFormat =
			self.format:getAttribute(i)
		local scalar = self.format:getScalarType(attributeLocation)
		if BufferFormat.isFormatScalarInteger(scalar) then
			table.insert(integerFormat, {
				location = attributeLocation,
				name = attributeName,
				format = attributeFormat,
			})
		elseif BufferFormat.isFormatScalarFloat(scalar) then
			table.insert(floatFormat, {
				location = attributeLocation,
				name = attributeName,
				format = attributeFormat,
			})
		end
	end

	self.integerFormat = BufferFormat(integerFormat, true)
	self.floatFormat = BufferFormat(floatFormat, true)

	self.uniforms = uniforms
	self.uniformsByName = {}
	for _, uniform in ipairs(uniforms) do
		self.uniformsByName[uniform:getName()] = uniform
	end

	self.shader = shader

	self.passes = {
		forward = not not passes.forward,
		deferred = not not passes.deferred,
	}
end

function PipelineMaterial:getName()
	return self.name
end

function PipelineMaterial:getParentName()
	return self.extends
end

function PipelineMaterial:getFormat()
	return self.format
end

function PipelineMaterial:getIntegerFormat()
	return self.integerFormat
end

function PipelineMaterial:getFloatFormat()
	return self.integerFormat
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

function PipelineMaterial:getIsForwardCompatible()
	return self.passes.forward
end

function PipelineMaterial:getIsDeferredCompatible()
	return self.passes.deferred
end

--- @param feature RatScratch.Pipeline.Graphics3D.PipelineMaterial.Feature
--- @return boolean
function PipelineMaterial:hasFeature(feature)
	return not not self.features[feature]
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
		for i, uniform in ipairs(materialDefinition.uniforms) do
			if uniform.format == "texture" then
				table.insert(format, {
					location = i - 1,
					name = uniform.name,
					format = "uint32",
				})
			else
				table.insert(format, {
					location = i - 1,
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

	local passes = {}
	for _, pass in ipairs(materialDefinition.passes) do
		passes[pass] = true
	end
	assert(next(passes), "material must have at least one pass")

	local features = { discard = false }
	if materialDefinition.features then
		for _, flag in ipairs(materialDefinition.features) do
			features[flag] = true
		end
	end

	return PipelineMaterial(
		materialDefinition.name,
		materialDefinition.extends,
		features,
		formatInstance,
		uniforms,
		passes,
		shader
	)
end

return PipelineMaterial
