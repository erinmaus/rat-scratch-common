local assert = require("rat-scratch-common").Debug.assert
local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common").Table
local PipelineBuffer = require("rat-scratch-pipeline.Buffer.PipelineBuffer")
local Atlas = require("rat-scratch-graphics").Atlas.Atlas
local PipelineMaterialInstance =
	require("rat-scratch-pipeline.Graphics3D.PipelineMaterialInstance")
local PipelineMaterialInstanceEvent =
	require("rat-scratch-pipeline.Graphics3D.PipelineMaterialInstanceEvent")
local PipelineMultiBuffer =
	require("rat-scratch-pipeline.Buffer.PipelineMultiBuffer")
local ffi = require("ffi")
local ImageDataAtlasHandle =
	require("rat-scratch-graphics").Atlas.ImageDataAtlasHandle

--- @class RatScratch.Pipeline.MaterialPipeline : RatScratch.Common.BaseObject
--- @field private stagingMaterialData love.ByteData
--- @field private maxMaterialComponents integer
--- @field private materialInstanceValuesFormat RatScratch.Graphics.Graphics3D.BufferFormatAttribute[][]
--- @field private materialInstanceValuesBuffer RatScratch.Pipeline.Buffer.PipelineMultiBuffer<RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance>
--- @field private materials table<RatScratch.Pipeline.Graphics3D.PipelineMaterial, true>
--- @field private materialsByName table<string, RatScratch.Pipeline.Graphics3D.PipelineMaterial>
--- @field private materialsDirty boolean
--- @field private materialsByIndex RatScratch.Pipeline.Graphics3D.PipelineMaterial[]
--- @field private materialInstances table<RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance, { setEventID: integer }>
--- @field private materialInstancesByIndex RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance[]
--- @field private materialInstancesBuffer RatScratch.Pipeline.Buffer.PipelineMultiBuffer<RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance>
--- @field private dirtyMaterialInstances table<RatScratch.Pipeline.Graphics3D.PipelineMaterialInstance, true>
--- @field private textures table<love.ImageData, RatScratch.Graphics.Atlas.ImageDataAtlasHandle>
--- @field private indexToTexture table<integer, love.ImageData>
--- @field private dirtyTextures table<love.ImageData, true>
--- @field private texturesBuffer RatScratch.Pipeline.Buffer.PipelineBuffer<love.ImageData>
--- @overload fun(): RatScratch.Pipeline.MaterialPipeline
local MaterialPipeline = Object()

MaterialPipeline.TEXTURE_FORMAT = {
	{ location = 0, name = "size", format = "floatvec2" },
	{ location = 0, name = "position", format = "floatvec2" },
	{ location = 0, name = "layer", format = "float" },
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

MaterialPipeline.MATERIAL_INSTANCE_MULTI_FORMAT_INTEGER_BUFFER = 2
MaterialPipeline.MATERIAL_INSTANCE_MULTI_FORMAT_FLOAT_BUFFER = 2

MaterialPipeline.MAX_TEXTURE_SIZE = 8192
MaterialPipeline.DEFAULT_TEXTURE_LAYERS = 8
MaterialPipeline.DEFAULT_TEXTURES_COUNT = 128
MaterialPipeline.DEFAULT_MATERIAL_INSTANCES_COUNT = 1024

function MaterialPipeline:new()
	local limits = love.graphics.getSystemLimits()

	self.maxMaterialComponents = 1

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
	self.materialsDirty = false

	self.materialInstances = {}
	self.materialInstancesByIndex = {}
	self.dirtyMaterialInstances = {}

	self.textures = {}
	self.indexToTexture = {}
	self.dirtyTextures = {}
	self.texturesBuffer = PipelineBuffer(
		MaterialPipeline.TEXTURE_FORMAT,
		{ shaderstorage = true },
		MaterialPipeline.DEFAULT_TEXTURES_COUNT
	)
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
		material:getName()
	)

	local materialInstance = PipelineMaterialInstance(material, self)
	if self.materialInstancesBuffer then
		self.materialInstancesBuffer:register(materialInstance, 1)
	end

	local id = materialInstance:listen(
		PipelineMaterialInstanceEvent.SET,
		self._onMaterialSetUniform,
		self
	)

	self.dirtyMaterialInstances[material] = true
	self.materialInstances[material] = { setEventID = id }
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

	if self.materialInstancesBuffer then
		self.materialInstancesBuffer:unregister(materialInstance)
	end

	local materialInfo = self.materialInstances[materialInstance]
	materialInstance:silence(materialInfo.setEventID)

	self.dirtyMaterialInstances[materialInstance] = nil
	self.materialInstances[materialInstance] = nil
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
		right - left,
		bottom - top,
		left,
		top,
		layer
	)
end

--- @private
function MaterialPipeline:_flushTextures()
	for texture in pairs(self.dirtyTextures) do
		self:_flushTexture(texture)
		self.dirtyTextures[texture] = nil
	end
end

function MaterialPipeline:compact() end

--- @private
function MaterialPipeline:_rebuildMaterialShaders() end

--- @private
function MaterialPipeline:_rebuildMaterials()
	local maxComponents = 1
	for _, material in ipairs(self.materialsByIndex) do
		maxComponents = math.max(
			maxComponents,
			material:getIntegerFormat():getComponentCount(),
			material:getFloatFormat():getComponentCount()
		)
	end

	self.maxMaterialComponents = maxComponents

	self.materialInstancesBuffer = PipelineMultiBuffer(
		MaterialPipeline.MATERIAL_INSTANCE_MULTI_FORMAT,
		{ shaderstorage = true },
		self.materialInstancesBuffer:getCount() * self.maxMaterialComponents
	)

	self.stagingMaterialData = love.data.newByteData(maxComponents * 4)

	for _, materialInstance in ipairs(self.materialInstancesByIndex) do
		self.materialInstancesBuffer:register(
			materialInstance,
			self.maxMaterialComponents
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

	ffi.copy(
		self.stagingMaterialData:getFFIPointer(),
		materialInstance:getUniformsBuffer():getIntegerData():getFFIPointer(),
		materialInstance:getUniformsBuffer():getIntegerData():getSize()
	)

	self.materialInstancesBuffer:copyData(
		MaterialPipeline.MATERIAL_INSTANCE_MULTI_FORMAT_INTEGER_BUFFER,
		materialInstance,
		self.stagingMaterialData,
		1,
		self.maxMaterialComponents,
		0
	)

	ffi.fill(
		self.stagingMaterialData:getFFIPointer(),
		self.stagingMaterialData:getSize(),
		0
	)

	ffi.copy(
		self.stagingMaterialData:getFFIPointer(),
		materialInstance:getUniformsBuffer():getFloatData():getFFIPointer(),
		materialInstance:getUniformsBuffer():getFloatData():getSize()
	)

	self.materialInstancesBuffer:copyData(
		MaterialPipeline.MATERIAL_INSTANCE_MULTI_FORMAT_FLOAT_BUFFER,
		materialInstance,
		self.stagingMaterialData,
		1,
		self.maxMaterialComponents,
		0
	)
end

--- @private
function MaterialPipeline:_flushMaterials()
	self.materialInstancesBuffer:flush()
end

--- @private
function MaterialPipeline:_flushMaterialInstances()
	for materialInstance in pairs(self.dirtyMaterialInstances) do
		self:_rebuildMaterialInstanceUniforms(materialInstance)
		self.dirtyMaterialInstances[materialInstance] = nil
	end

	self.materialInstancesBuffer:flush()
end

function MaterialPipeline:flush()
	if next(self.dirtyTextures) then
		self:_flushTextures()
	end

	if self.materialsDirty then
		self:_rebuildMaterialShaders()
		self:_rebuildMaterials()
		self:_flushMaterials()
		self.materialsDirty = false
	end

	if next(self.dirtyMaterialInstances) then
		self:_flushMaterialInstances()
	end
end

return MaterialPipeline
