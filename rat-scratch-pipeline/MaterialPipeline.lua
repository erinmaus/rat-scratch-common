local PATH = ...
local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local Atlas = require("rat-scratch-graphics").Atlas.Atlas
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local Pipeline = require("rat-scratch-pipeline.impl.Pipeline")
local PipelineMaterial =
	require("rat-scratch-pipeline.Graphics3D.PipelineMaterial")
local PipelineMaterialInstance =
	require("rat-scratch-pipeline.Graphics3D.PipelineMaterialInstance")
local PipelineMaterialInstanceEvent =
	require("rat-scratch-pipeline.Graphics3D.PipelineMaterialInstanceEvent")
local PipelineMultiBuffer =
	require("rat-scratch-pipeline.Buffer.PipelineMultiBuffer")
local ShaderPreprocessor = require("rat-scratch-graphics").ShaderPreprocessor
local ffi = require("ffi")
local ImageDataAtlasHandle =
	require("rat-scratch-graphics").Atlas.ImageDataAtlasHandle
local RatScratchModule = require("lib.rat-scratch-module")
local json = require("lib.json")

--- @alias RatScratch.Pipeline.MaterialPipeline.ShaderPass
--- | "deferred"
--- | "forward"
--- | "depth"
--- | "depth-discard"

--- @alias RatScratch.Pipeline.MaterialPipeline.ShaderType
--- | "draw"
--- | "light"

--- @class RatScratch.Pipeline.MaterialPipeline : RatScratch.Pipeline.impl.Pipeline
--- @field private shaders table<string, table<RatScratch.Pipeline.MaterialPipeline.ShaderPass, table<RatScratch.Pipeline.MaterialPipeline.ShaderType, love.Shader>> table<RatScratch.Pipeline.MaterialPipeline.ShaderPass, table<RatScratch.Pipeline.MaterialPipeline.ShaderType, love.Shader>>>
--- @field private stagingMaterialData love.ByteData
--- @field private maxMaterialIntegerComponents integer
--- @field private maxMaterialFloatComponents integer
--- @field private maxMaterialComponents integer
--- @field private materials table<RatScratch.Pipeline.Graphics3D.PipelineMaterial, true>
--- @field private materialsByName table<string, RatScratch.Pipeline.Graphics3D.PipelineMaterial>
--- @field private materialsDirty boolean
--- @field private materialsByIndex RatScratch.Pipeline.Graphics3D.PipelineMaterial[]
--- @field private materialsToIndex table<RatScratch.Pipeline.Graphics3D.PipelineMaterial, integer>
--- @field private materialInstances table<RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance, { setEventID: integer }>
--- @field private materialInstancesByIndex RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance[]
--- @field private materialInstancesBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance>
--- @field private materialInstanceValuesBuffer RatScratch.Pipeline.Buffer.PipelineMultiBuffer<RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance>
--- @field private dirtyMaterialInstances table<RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance, true>
--- @field private textures table<love.ImageData, RatScratch.Graphics.Atlas.ImageDataAtlasHandle>
--- @field private indexToTexture table<integer, love.ImageData>
--- @field private dirtyTextures table<love.ImageData, true>
--- @field private texturesBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<love.ImageData>
--- @field private srgbAtlasTextureView love.Texture
--- @overload fun(pipelineRuntime: RatScratch.Pipeline.PipelineRuntime): RatScratch.Pipeline.MaterialPipeline
local MaterialPipeline = Object(Pipeline)

MaterialPipeline.TEXTURE_FORMAT = {
	{ location = 0, name = "size", format = "floatvec2" },
	{ location = 1, name = "position", format = "floatvec2" },
	{ location = 2, name = "layer", format = "float" },
}

MaterialPipeline.MATERIAL_INSTANCE_INTEGERS_FORMAT = {
	{ location = 0, name = "value", format = "uint32" },
}

MaterialPipeline.MATERIAL_INSTANCE_FLOATS_FORMAT = {
	{ location = 0, name = "value", format = "uint32" },
}

MaterialPipeline.MATERIAL_INSTANCE_MULTI_FORMAT = {
	MaterialPipeline.MATERIAL_INSTANCE_INTEGERS_FORMAT,
	MaterialPipeline.MATERIAL_INSTANCE_FLOATS_FORMAT,
}

MaterialPipeline.MATERIAL_INSTANCES_FORMAT = {
	{ location = 0, name = "materialDefinitionIndex", format = "uint32" },
}

MaterialPipeline.MATERIAL_INSTANCE_MULTI_FORMAT_INTEGER_BUFFER = 1
MaterialPipeline.MATERIAL_INSTANCE_MULTI_FORMAT_FLOAT_BUFFER = 2

MaterialPipeline.MAX_TEXTURE_SIZE = 8192
MaterialPipeline.DEFAULT_TEXTURE_LAYERS = 8
MaterialPipeline.DEFAULT_TEXTURES_COUNT = 128
MaterialPipeline.DEFAULT_MATERIAL_INSTANCES_COUNT = 1024

--- @param pipelineRuntime RatScratch.Pipeline.PipelineRuntime
function MaterialPipeline:new(pipelineRuntime)
	Pipeline.new(self, pipelineRuntime)

	self.shaders = {}

	self.maxMaterialIntegerComponents = 1
	self.maxMaterialFloatComponents = 1
	self.maxMaterialComponents = 1

	local limits = love.graphics.getSystemLimits()
	local textureSize =
		math.min(limits.texturesize, MaterialPipeline.MAX_TEXTURE_SIZE)
	self.atlas = Atlas(
		textureSize,
		textureSize,
		MaterialPipeline.DEFAULT_TEXTURE_LAYERS,
		limits.texturelayers
	)

	self.materials = {}
	self.materialsByName = {}
	self.materialsByIndex = {}
	self.materialToIndex = {}
	self.materialsDirty = false

	self.materialInstances = {}
	self.materialInstancesByIndex = {}
	self.dirtyMaterialInstances = {}
	self.materialInstancesBuffer = PipelineBuffer(
		MaterialPipeline.MATERIAL_INSTANCES_FORMAT,
		{ shaderstorage = true },
		MaterialPipeline.DEFAULT_MATERIAL_INSTANCES_COUNT
	)

	self.textures = {}
	self.indexToTexture = {}
	self.dirtyTextures = {}
	self.texturesBuffer = PipelineBuffer(
		MaterialPipeline.TEXTURE_FORMAT,
		{ shaderstorage = true },
		MaterialPipeline.DEFAULT_TEXTURES_COUNT
	)

	local defaultMaterialData = love.filesystem.read(
		("%s/Config/Default/BasicMaterial.json"):format(
			RatScratchModule.getSelfPath(PATH)
		)
	)
	local defaultMaterialJSON = json.decode(defaultMaterialData)

	self.defaultMaterial =
		PipelineMaterial.fromDefinition(defaultMaterialJSON.material)
	self:addMaterial(self.defaultMaterial)
end

function MaterialPipeline:bind(shader, qualityPreset)
	if shader:hasUniform("rat_FloatMaterialPropertiesBuffer") then
		shader:send(
			"rat_FloatMaterialPropertiesBuffer",
			self.materialInstanceValuesBuffer:getBuffer(
				MaterialPipeline.MATERIAL_INSTANCE_MULTI_FORMAT_FLOAT_BUFFER
			)
		)
	end

	if shader:hasUniform("rat_IntMaterialPropertiesBuffer") then
		shader:send(
			"rat_IntMaterialPropertiesBuffer",
			self.materialInstanceValuesBuffer:getBuffer(
				MaterialPipeline.MATERIAL_INSTANCE_MULTI_FORMAT_INTEGER_BUFFER
			)
		)
	end

	if shader:hasUniform("rat_TexturesBuffer") then
		shader:send("rat_TexturesBuffer", self.texturesBuffer:getBuffer())
	end

	if shader:hasUniform("rat_MaterialInstancesBuffer") then
		shader:send(
			"rat_MaterialInstancesBuffer",
			self.materialInstancesBuffer:getBuffer()
		)
	end

	if
		self.srgbAtlasTextureView
		and shader:hasUniform("rat_PipelineGammaCorrectTextureAtlasView")
	then
		shader:send(
			"rat_PipelineGammaCorrectTextureAtlasView",
			self.srgbAtlasTextureView
		)
	end

	if shader:hasUniform("rat_PipelineLinearTextureAtlasView") then
		shader:send(
			"rat_PipelineLinearTextureAtlasView",
			self.atlas:getTexture()
		)
	end
end

--- @param material RatScratch.Pipeline.Graphics3D.PipelineMaterial
function MaterialPipeline:addMaterial(material)
	assert(
		not self.materials[material],
		"material %s already exists in material pipeline",
		material:getName()
	)

	assert(
		not self.materialsByName[material],
		"material with name %s already exists in material pipeline",
		material:getName()
	)

	self.materials[material] = true
	table.insert(self.materialsByIndex, material)
	self.materialsByName[material:getName()] = material

	self.materialsDirty = true
end

--- @param material RatScratch.Pipeline.Graphics3D.PipelineMaterial
function MaterialPipeline:removeMaterial(material)
	assert(
		self.materials[material],
		"material %s not in material pipeline",
		material:getName()
	)

	self.materials[material] = nil
	Table.remove(self.materialsByIndex, material)
	self.materialsByName[material:getName()] = nil

	self.materialsDirty = true
end

--- @param name string
--- @return RatScratch.Pipeline.Graphics3D.PipelineMaterial
function MaterialPipeline:getMaterialByName(name)
	return self.materialsByName[name]
end

--- @param texture love.ImageData
--- @return integer
function MaterialPipeline:getTextureIndex(texture)
	if not self.textures[texture] then
		return 0
	end

	local index = self.texturesBuffer:getIndexCount(texture)
	return index
end

--- @param index integer
--- @return love.ImageData
function MaterialPipeline:getTextureByIndex(index)
	return self.indexToTexture[index]
end

--- @param texture love.ImageData
function MaterialPipeline:addTexture(texture)
	assert(
		not self.textures[texture],
		"texture already exists in material pipeline"
	)

	local handle = ImageDataAtlasHandle(texture)
	local success = self.atlas:add(handle)
	assert(success, "texture could not be added to atlas")

	self.textures[texture] = handle
	self.texturesBuffer:register(texture, 1)

	local index = self.texturesBuffer:getIndexCount(texture)
	self.indexToTexture[index] = texture

	self.dirtyTextures[texture] = true
end

--- @param texture love.ImageData
function MaterialPipeline:removeTexture(texture)
	assert(self.textures[texture], "texture not in material pipeline")

	local index = self.texturesBuffer:getIndexCount(texture)
	self.indexToTexture[index] = nil

	self.texturesBuffer:unregister(texture)

	local handle = self.textures[texture]
	self.atlas:remove(handle)

	self.textures[texture] = nil
end

--- @param material string | RatScratch.Pipeline.Graphics3D.PipelineMaterial
function MaterialPipeline:newMaterialInstance(material)
	material = self.materialsByName[material] or material
	--- @cast material RatScratch.Pipeline.Graphics3D.PipelineMaterial

	assert(
		self.materials[material],
		"material %s not in material pipeline",
		Object.isType(material) and material:getName() or material
	)

	local materialInstance = PipelineMaterialInstance(material, self)
	self.materialInstancesBuffer:register(materialInstance, 1)

	if self.materialInstanceValuesBuffer then
		self.materialInstanceValuesBuffer:register(
			materialInstance,
			self.maxMaterialComponents
		)
	end

	local id = materialInstance:listen(
		PipelineMaterialInstanceEvent.SET,
		self._onMaterialSetUniform,
		self
	)

	self.dirtyMaterialInstances[materialInstance] = true
	self.materialInstances[materialInstance] = { setEventID = id }
	table.insert(self.materialInstancesByIndex, materialInstance)

	return materialInstance
end

--- @private
--- @param event RatScratch.Pipeline.Graphics3D.PipelineMaterialInstanceEvent
--- @param materialInstance RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance
function MaterialPipeline:_onMaterialSetUniform(event, materialInstance)
	self.dirtyMaterialInstances[materialInstance] = true
end

--- @param materialInstance RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance
function MaterialPipeline:freeMaterialInstance(materialInstance)
	assert(
		self.materialInstances[materialInstance],
		"material instance is not in material pipeline"
	)

	if self.materialInstanceValuesBuffer then
		self.materialInstanceValuesBuffer:unregister(materialInstance)
	end

	local materialInfo = self.materialInstances[materialInstance]
	materialInstance:silence(materialInfo.setEventID)

	self.dirtyMaterialInstances[materialInstance] = nil
	self.materialInstances[materialInstance] = nil
end

--- @param materialInstance RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance
--- @return integer
function MaterialPipeline:getMaterialInstanceIndex(materialInstance)
	assert(
		self.materialInstances[materialInstance],
		"material instance is not in material pipeline"
	)

	local index = self.materialInstancesBuffer:getIndexCount(materialInstance)
	return index
end

function MaterialPipeline:repack()
	self.atlas:repack()

	for texture in pairs(self.textures) do
		self:_flushTexture(texture)
	end

	Table.clear(self.dirtyTextures)
end

--- @private
--- @param texture love.ImageData
function MaterialPipeline:_flushTexture(texture)
	local left, right, top, bottom, layer =
		self.atlas:getTextureCoordinates(self.textures[texture])

	self.texturesBuffer:set(
		texture,
		1,
		1,
		right - left,
		bottom - top,
		left,
		top,
		layer - 1
	)
end

do
	local srgbView = {
		format = "srgba8",
		readable = true,
	}

	--- @private
	function MaterialPipeline:_flushTextures()
		for texture in pairs(self.dirtyTextures) do
			self:_flushTexture(texture)
			self.dirtyTextures[texture] = nil
		end

		if self.srgbAtlasTextureView then
			self.srgbAtlasTextureView:release()
		end

		self.srgbAtlasTextureView =
			love.graphics.newTextureView(self.atlas:getTexture(), srgbView)
	end
end

function MaterialPipeline:compact() end

--- @private
--- @param material RatScratch.Pipeline.Graphics3D.PipelineMaterial
function MaterialPipeline:_verifyParents(material)
	local currentMaterial = material
	local parents = {}

	while currentMaterial do
		assert(
			not parents[currentMaterial],
			"material %s loops (encountered parent %s more than once)",
			material:getName(),
			currentMaterial:getName()
		)
		assert(
			not currentMaterial:getParentName()
				or self.materialsByName[currentMaterial:getParentName()],
			"material %s has missing parent (%s)",
			currentMaterial:getName(),
			currentMaterial:getParentName()
		)

		parents[currentMaterial] = true
		currentMaterial = self.materialsByName[currentMaterial:getParentName()]
	end
end

--- @private
--- @param material RatScratch.Pipeline.Graphics3D.PipelineMaterial
function MaterialPipeline:_getMaterialParentComponentIndex(material)
	local count = math.max(
		material:getIntegerFormat():getAttributeCount(),
		material:getFloatFormat():getAttributeCount()
	)

	if material:getParentName() then
		return count
			+ self:_getMaterialParentComponentIndex(
				self.materialsByName[material:getParentName()]
			)
	end

	return count
end

--- @private
--- @param material RatScratch.Pipeline.Graphics3D.PipelineMaterial
function MaterialPipeline:_getMaterialComponentIndex(material)
	if material:getParentName() then
		return self:_getMaterialParentComponentIndex(
			self.materialsByName[material:getParentName()]
		) + 1
	end

	return 1
end

--- @private
--- @param a RatScratch.Pipeline.Graphics3D.PipelineMaterial
--- @param b RatScratch.Pipeline.Graphics3D.PipelineMaterial
function MaterialPipeline:_isAParentOfB(a, b)
	local currentMaterial = self.materialsByName[b:getParentName()]
	while currentMaterial do
		if currentMaterial == a then
			return true
		end
	end

	return false
end

--- @private
--- @param material RatScratch.Pipeline.Graphics3D.PipelineMaterial
--- @param materialInfo table
--- @param variables table
function MaterialPipeline:_binMaterialVariables(
	material,
	variables,
	materialInfo
)
	table.insert(variables.RAT_SCRATCH_MATERIALS, materialInfo)

	local shader = material:getShader()
	if shader:hasLightShader() then
		table.insert(variables.RAT_SCRATCH_LIGHT_MATERIALS, materialInfo)
	end

	if shader:hasVertexShader() then
		table.insert(variables.RAT_SCRATCH_VERTEX_MATERIALS, materialInfo)
	end

	if shader:hasFragmentShader() then
		table.insert(variables.RAT_SCRATCH_FRAGMENT_MATERIALS, materialInfo)
	end
end

local function _newMaterialVariables()
	return {
		RAT_SCRATCH_MATERIALS = {},
		RAT_SCRATCH_LIGHT_MATERIALS = {},
		RAT_SCRATCH_VERTEX_MATERIALS = {},
		RAT_SCRATCH_FRAGMENT_MATERIALS = {},
	}
end

--- @private
function MaterialPipeline:_getMaterialVariables()
	local forwardVariables = _newMaterialVariables()
	local deferredVariables = _newMaterialVariables()
	local depthDiscardVariables = _newMaterialVariables()
	local depthVariables = _newMaterialVariables()

	--- @type RatScratch.Pipeline.Graphics3D.PipelineMaterial[]
	local sortedMaterials = {}
	for _, material in ipairs(self.materialsByIndex) do
		self:_verifyParents(material)
		table.insert(sortedMaterials, material)
	end

	Table.sort(sortedMaterials, 1, #sortedMaterials, function(a, b)
		return self:_isAParentOfB(a, b)
	end)

	for i, material in ipairs(sortedMaterials) do
		local shader = material:getShader()
		local baseOffset = self:_getMaterialComponentIndex(material)
		local materialInfo = {
			RAT_SCRATCH_MATERIAL = material:getName(),
			RAT_SCRATCH_PARENT_MATERIAL = material:getParentName() or "None",
			RAT_SCRATCH_MATERIAL_DEFINITION_INDEX = i - 1,
			RAT_SCRATCH_MATERIAL_PROPERTIES_STRIDE = self.maxMaterialComponents,
			RAT_SCRATCH_BASE_OFFSET = baseOffset - 1,
			RAT_SCRATCH_INT_PROPERTIES = {},
			RAT_SCRATCH_FLOAT_PROPERTIES = {},
			RAT_SCRATCH_PROPERTIES = {},
			RAT_SCRATCH_VERTEX_SHADER_SOURCE = shader:hasVertexShader()
					and shader:getVertexShaderSource()
				or nil,
			RAT_SCRATCH_FRAGMENT_SHADER_SOURCE = shader:hasFragmentShader()
					and shader:getFragmentShaderSource()
				or nil,
			RAT_SCRATCH_DEPTH_SHADER_SOURCE = (
				shader:hasFragmentShader() and shader:getDepthShaderSource()
			)
				or (shader:hasFragmentShader() and shader:getFragmentShaderSource())
				or nil,
			RAT_SCRATCH_LIGHT_SHADER_SOURCE = shader:hasLightShader()
					and shader:getLightShaderSource()
				or nil,
		}

		local formatInstance = material:getFormat()
		for i = 1, formatInstance:getAttributeCount() do
			local attributeLocation, attributeName, attributeFormat =
				formatInstance:getAttribute(i)
			local shaderType = formatInstance:getShaderType(attributeLocation)
			local scalarFormat = formatInstance:getScalarType(attributeLocation)

			local propertyInfo = {
				RAT_SCRATCH_TYPE = shaderType,
				RAT_SCRATCH_MATERIAL_PROPERTY = attributeName,
				RAT_SCRATCH_COMPONENTS = {},
			}

			local count, offset
			if BufferFormat.isFormatScalarFloat(scalarFormat) then
				count, offset =
					material:getFloatFormat():getCountOffset(attributeLocation)
			elseif BufferFormat.isFormatScalarInteger(scalarFormat) then
				count, offset = material
					:getIntegerFormat()
					:getCountOffset(attributeLocation)
			end

			if count and offset then
				for j = 1, count do
					local componentInfo = {
						RAT_SCRATCH_SCALAR_TYPE = BufferFormat.getFormatShaderType(
							scalarFormat
						),
						RAT_SCRATCH_BUFFER_OFFSET = (offset - 1) + (j - 1),
					}

					table.insert(
						propertyInfo.RAT_SCRATCH_COMPONENTS,
						componentInfo
					)
				end

				if BufferFormat.isFormatScalarFloat(scalarFormat) then
					table.insert(
						materialInfo.RAT_SCRATCH_FLOAT_PROPERTIES,
						propertyInfo
					)
				elseif BufferFormat.isFormatScalarInteger(scalarFormat) then
					table.insert(
						materialInfo.RAT_SCRATCH_INT_PROPERTIES,
						propertyInfo
					)
				end
			end
			table.insert(materialInfo.RAT_SCRATCH_PROPERTIES, propertyInfo)
		end

		if material:getIsDeferredCompatible() then
			self:_binMaterialVariables(
				material,
				deferredVariables,
				materialInfo
			)

			local v = material:hasFeature("discard") and depthDiscardVariables
				or depthVariables

			if material:getShader():hasDepthShader() then
				local depthMaterialInfo = Table.deepClone(materialInfo)
				depthMaterialInfo.RAT_SCRATCH_VERTEX_SHADER_SOURCE =
					depthMaterialInfo.RAT_SCRATCH_DEPTH_SHADER_SOURCE
				self:_binMaterialVariables(material, v, depthMaterialInfo)
			else
				self:_binMaterialVariables(material, v, materialInfo)
			end
		end

		if material:getIsForwardCompatible() then
			self:_binMaterialVariables(material, forwardVariables, materialInfo)
		end
	end

	return {
		deferred = deferredVariables,
		forward = forwardVariables,
		depth = depthVariables,
		depthDiscard = depthDiscardVariables,
	}
end

--- @private
--- @param path string
--- @param config RatScratch.Graphics.ShaderPreprocessOptions
--- @return string
function MaterialPipeline:_rebuildMaterialTemplateShader(path, config)
	local shaderSource, result = ShaderPreprocessor.preprocess(path, config)

	local message =
		ShaderPreprocessor.validateResult(shaderSource, result, true)
	if message then
		error(message)
	end

	return shaderSource
end

--- @private
--- @param baseConfig RatScratch.Graphics.ShaderPreprocessOptions
--- @param variables table
function MaterialPipeline:_rebuildMaterialTemplateShadersPass(
	baseConfig,
	variables
)
	--- @type RatScratch.Graphics.ShaderPreprocessOptions
	local config = {
		rootPath = baseConfig.rootPath,
		rootPaths = baseConfig.rootPaths,
		variables = variables,
	}

	local result = {
		["generated:/Pipeline/Material/Fragment.common.glsl"] = self:_rebuildMaterialTemplateShader(
			"@Pipeline/Base/Material/Fragment.template.glsl",
			config
		),
		["generated:/Pipeline/Material/Properties.common.glsl"] = self:_rebuildMaterialTemplateShader(
			"@Pipeline/Base/Material/Properties.template.glsl",
			config
		),
		["generated:/Pipeline/Material/Vertex.vert.glsl"] = self:_rebuildMaterialTemplateShader(
			"@Pipeline/Base/Material/Vertex.template.glsl",
			config
		),
		["generated:/Pipeline/Light/ApplyLights.common.glsl"] = self:_rebuildMaterialTemplateShader(
			"@Pipeline/Base/Light/ApplyLights.template.glsl",
			config
		),
		["generated:/Pipeline/Light/Lights.common.glsl"] = self:_rebuildMaterialTemplateShader(
			"@Pipeline/Base/Light/Lights.template.glsl",
			config
		),
	}

	local other = self:getPipelineConfig():getVirtualShaders()
	for filename, source in pairs(other) do
		result[filename] = source
	end

	return result
end

--- @private
--- @param qualityPreset string
--- @param baseConfig RatScratch.Graphics.ShaderPreprocessOptions
--- @param virtualPaths table
function MaterialPipeline:_rebuildDeferredShaders(
	qualityPreset,
	baseConfig,
	virtualPaths
)
	--- @type RatScratch.Graphics.ShaderPreprocessOptions
	local config = {
		rootPath = baseConfig.rootPath,
		rootPaths = baseConfig.rootPaths,
		virtualPaths = virtualPaths,
	}

	-- TODO: layered rendering
	return {
		draw = self:getPipelineRuntime():loadShader(
			"@Pipeline/Base/Deferred/Fragment.frag.glsl",
			"@Pipeline/Base/Vertex/Vertex.vert.glsl",
			qualityPreset,
			config
		),
		light = self:getPipelineRuntime():loadShader(
			"@Pipeline/Base/Deferred/Light.frag.glsl",
			"@Pipeline/Base/Deferred/Light.vert.glsl",
			qualityPreset,
			config
		),
	}
end

--- @private
--- @param qualityPreset string
--- @param baseConfig RatScratch.Graphics.ShaderPreprocessOptions
--- @param virtualPaths table
function MaterialPipeline:_rebuildForwardShaders(
	qualityPreset,
	baseConfig,
	virtualPaths
)
	--- @type RatScratch.Graphics.ShaderPreprocessOptions
	local config = {
		rootPath = baseConfig.rootPath,
		rootPaths = baseConfig.rootPaths,
		virtualPaths = virtualPaths,
	}

	-- TODO: layered rendering
	return {
		draw = self:getPipelineRuntime():loadShader(
			"@Pipeline/Base/Forward/Fragment.frag.glsl",
			"@Pipeline/Base/Vertex/Vertex.vert.glsl",
			qualityPreset,
			config
		),
	}
end

--- @private
--- @param qualityPreset string
--- @param baseConfig RatScratch.Graphics.ShaderPreprocessOptions
--- @param virtualPaths table
function MaterialPipeline:_rebuildDepthShaders(
	qualityPreset,
	baseConfig,
	virtualPaths
)
	--- @type RatScratch.Graphics.ShaderPreprocessOptions
	local config = {
		rootPath = baseConfig.rootPath,
		rootPaths = baseConfig.rootPaths,
		virtualPaths = virtualPaths,
	}

	-- TODO: layered rendering
	return {
		draw = self:getPipelineRuntime():loadShader(
			"@Pipeline/Base/Deferred/Depth.frag.glsl",
			"@Pipeline/Base/Vertex/Vertex.vert.glsl",
			qualityPreset,
			config
		),
	}
end

--- @private
--- @param qualityPreset string
--- @param baseConfig RatScratch.Graphics.ShaderPreprocessOptions
--- @param virtualPaths table
function MaterialPipeline:_rebuildDepthDiscardShaders(
	qualityPreset,
	baseConfig,
	virtualPaths
)
	--- @type RatScratch.Graphics.ShaderPreprocessOptions
	local config = {
		rootPath = baseConfig.rootPath,
		rootPaths = baseConfig.rootPaths,
		virtualPaths = virtualPaths,
	}

	-- TODO: layered rendering
	return {
		draw = self:getPipelineRuntime():loadShader(
			"@Pipeline/Base/Deferred/DepthDiscard.frag.glsl",
			"@Pipeline/Base/Vertex/Vertex.vert.glsl",
			qualityPreset,
			config
		),
	}
end

--- @private
--- @param qualityPreset string
--- @param baseConfig RatScratch.Graphics.ShaderPreprocessOptions
--- @param virtualPaths table
function MaterialPipeline:_rebuildShaders(
	qualityPreset,
	baseConfig,
	virtualPaths
)
	self.shaders[qualityPreset] = {
		deferred = self:_rebuildDeferredShaders(
			qualityPreset,
			baseConfig,
			virtualPaths.deferred
		),
		forward = self:_rebuildForwardShaders(
			qualityPreset,
			baseConfig,
			virtualPaths.forward
		),
		depth = self:_rebuildDepthShaders(
			qualityPreset,
			baseConfig,
			virtualPaths.depth
		),
		depthDiscard = self:_rebuildDepthDiscardShaders(
			qualityPreset,
			baseConfig,
			virtualPaths.depthDiscard
		),
	}
end

--- @private
function MaterialPipeline:_rebuildMaterialShaders()
	local variables = self:_getMaterialVariables()
	local baseConfig = {
		rootPath = ("%s/Shaders"):format(
			RatScratchModule.getSelfPath("rat-scratch-graphics")
		),
		rootPaths = {
			Pipeline = ("%s/Shaders"):format(
				RatScratchModule.getSelfPath(PATH)
			),
			Generated = "generated:/",
		},
	}

	local baseVirtualShaders = {
		deferred = self:_rebuildMaterialTemplateShadersPass(
			baseConfig,
			variables.deferred
		),
		forward = self:_rebuildMaterialTemplateShadersPass(
			baseConfig,
			variables.forward
		),
		depth = self:_rebuildMaterialTemplateShadersPass(
			baseConfig,
			variables.depth
		),
		depthDiscard = self:_rebuildMaterialTemplateShadersPass(
			baseConfig,
			variables.depthDiscard
		),
	}

	local runtime = self:getPipelineRuntime()
	for i = 1, runtime:getQualityPresetCount() do
		self:_rebuildShaders(
			runtime:getQualityPreset(i),
			baseConfig,
			baseVirtualShaders
		)
	end
end

--- @param qualityPreset string
--- @param pass RatScratch.Pipeline.MaterialPipeline.ShaderPass
--- @param name RatScratch.Pipeline.MaterialPipeline.ShaderType
--- @return love.Shader
function MaterialPipeline:getShader(qualityPreset, pass, name)
	return self.shaders[qualityPreset][pass][name]
end

--- @private
function MaterialPipeline:_rebuildMaterials()
	Table.clear(self.materialToIndex)
	for i, material in ipairs(self.materialsByIndex) do
		self.materialToIndex[material] = i
	end

	local maxIntegerComponents = 1
	local maxFloatComponents = 1
	for _, material in ipairs(self.materialsByIndex) do
		local integerCount = material:getIntegerFormat():getComponentCount()
		local floatCount = material:getFloatFormat():getComponentCount()

		local current = self.materialsByName[material:getParentName()]
		while current do
			integerCount = integerCount
				+ current:getIntegerFormat():getComponentCount()
			floatCount = floatCount
				+ current:getFloatFormat():getComponentCount()

			current = self.materialsByName[material:getParentName()]
		end

		maxIntegerComponents = math.max(maxIntegerComponents, integerCount)
		maxFloatComponents = math.max(maxFloatComponents, floatCount)
	end

	self.maxMaterialIntegerComponents = maxIntegerComponents
	self.maxMaterialFloatComponents = maxFloatComponents
	self.maxMaterialComponents =
		math.max(maxIntegerComponents, maxFloatComponents)

	self.materialInstanceValuesBuffer = PipelineMultiBuffer(
		MaterialPipeline.MATERIAL_INSTANCE_MULTI_FORMAT,
		{ shaderstorage = true },
		(
			self.materialInstanceValuesBuffer
				and self.materialInstanceValuesBuffer:getCount()
			or MaterialPipeline.DEFAULT_MATERIAL_INSTANCES_COUNT
		) * self.maxMaterialComponents
	)

	self.stagingMaterialData =
		love.data.newByteData(self.maxMaterialComponents * 4)

	for _, materialInstance in ipairs(self.materialInstancesByIndex) do
		self.materialInstanceValuesBuffer:register(
			materialInstance,
			self.maxMaterialIntegerComponents
		)
		self:_rebuildMaterialInstanceUniforms(materialInstance)
	end

	Table.clear(self.dirtyMaterialInstances)
end

--- @private
--- @param materialInstance RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance
function MaterialPipeline:_rebuildMaterialInstanceUniforms(materialInstance)
	ffi.fill(
		self.stagingMaterialData:getFFIPointer(),
		self.stagingMaterialData:getSize(),
		0
	)

	local index = self.materialToIndex[materialInstance:getMaterial()]
	self.materialInstancesBuffer:set(materialInstance, 1, 1, index - 1)

	return self:_rebuildMaterialInstanceUniformsImpl(materialInstance)
end

--- @private
--- @param materialInstance RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance
--- @return integer
function MaterialPipeline:_rebuildMaterialInstanceUniformsImpl(materialInstance)
	local index = 1
	if materialInstance:getParent() then
		index = index
			+ self:_rebuildMaterialInstanceUniformsImpl(
				materialInstance:getParent()
			)
	end

	local offset = math.max(
		materialInstance:getMaterial():getIntegerFormat():getComponentCount(),
		materialInstance:getMaterial():getFloatFormat():getComponentCount()
	)

	ffi.copy(
		ffi.cast("uint8_t *", self.stagingMaterialData:getFFIPointer())
			+ ((index - 1) * ffi.sizeof("uint32_t")),
		materialInstance:getUniformsBuffer():getIntegerData():getFFIPointer(),
		materialInstance:getUniformsBuffer():getIntegerData():getSize()
	)

	self.materialInstanceValuesBuffer:copyData(
		MaterialPipeline.MATERIAL_INSTANCE_MULTI_FORMAT_INTEGER_BUFFER,
		materialInstance,
		self.stagingMaterialData,
		index,
		offset,
		0
	)

	ffi.fill(
		self.stagingMaterialData:getFFIPointer(),
		self.stagingMaterialData:getSize(),
		0
	)

	ffi.copy(
		ffi.cast("uint8_t *", self.stagingMaterialData:getFFIPointer())
			+ ((index - 1) * ffi.sizeof("float")),
		materialInstance:getUniformsBuffer():getFloatData():getFFIPointer(),
		materialInstance:getUniformsBuffer():getFloatData():getSize()
	)

	self.materialInstanceValuesBuffer:copyData(
		MaterialPipeline.MATERIAL_INSTANCE_MULTI_FORMAT_FLOAT_BUFFER,
		materialInstance,
		self.stagingMaterialData,
		index,
		offset,
		0
	)

	return index + offset
end

--- @private
function MaterialPipeline:_flushMaterials()
	self.materialInstanceValuesBuffer:flush()
end

--- @private
function MaterialPipeline:_flushMaterialInstances()
	for materialInstance in pairs(self.dirtyMaterialInstances) do
		self:_rebuildMaterialInstanceUniforms(materialInstance)
		self.dirtyMaterialInstances[materialInstance] = nil
	end

	self.materialInstanceValuesBuffer:flush()
end

function MaterialPipeline:flush()
	if next(self.dirtyTextures) then
		self:_flushTextures()
		self.texturesBuffer:flush()
	end

	if self.materialsDirty then
		self:_rebuildMaterials()
		self:_rebuildMaterialShaders()
		self:_flushMaterials()
		self.materialsDirty = false
	end
end

function MaterialPipeline:update()
	if next(self.dirtyMaterialInstances) then
		self:_flushMaterialInstances()
	end
end

return MaterialPipeline
