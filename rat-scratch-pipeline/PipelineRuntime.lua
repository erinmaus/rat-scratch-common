local PATH = ...
local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local Table = require("rat-scratch-common").Table
local BufferFormat = require("rat-scratch-graphics").Graphics3D.BufferFormat
local PipelineConfig = require("rat-scratch-pipeline.PipelineConfig")
local PipelineProperty = require("rat-scratch-pipeline.PipelineProperty")
local PipelineSetting = require("rat-scratch-pipeline.PipelineSetting")
local RatScratchModule = require("lib.rat-scratch-module")
local ShaderPreprocessor = require("rat-scratch-graphics.ShaderPreprocessor")
local json = require("lib.json")

--- @alias RatScratch.Pipeline.PipelineProperties table<string, table<string, (number | integer | boolean)[]>>

--- @class RatScratch.Pipeline.PipelineRuntime : RatScratch.Common.BaseObject
--- @field defaultQualityPreset string
--- @field qualityPresets string[]
--- @field qualityPresetsByName table<string, boolean>
--- @field properties RatScratch.Pipeline.PipelineProperty[]
--- @field propertiesByKey table<string, RatScratch.Pipeline.PipelineProperty>
--- @field propertiesByIdentifier table<string, RatScratch.Pipeline.PipelineProperty>
--- @field settings RatScratch.Pipeline.PipelineSetting[]
--- @field settingsByKey table<string, RatScratch.Pipeline.PipelineSetting>
--- @field propertyToSetting table<string, RatScratch.Pipeline.PipelineSetting>
--- @field virtualPaths table<string, table<string, string>>
--- @overload fun(runtime: RatScratch.Pipeline.PipelineRuntimeConfig, config: RatScratch.Pipeline.PipelineConfig, currentProperties?: RatScratch.Pipeline.PipelineProperties): RatScratch.Pipeline.PipelineRuntime
local PipelineRuntime = Object()

--- @param runtime RatScratch.Pipeline.PipelineRuntimeConfig
--- @param config RatScratch.Pipeline.PipelineConfig
--- @param currentProperties? RatScratch.Pipeline.PipelineProperties
function PipelineRuntime:new(runtime, config, currentProperties)
	self.config = config

	assert(runtime.defaultQualityPreset, "missing default quality preset")
	self.defaultQualityPreset = runtime.defaultQualityPreset

	assert(
		runtime.qualityPresets and #runtime.qualityPresets >= 1,
		"missing quality presets"
	)
	self.qualityPresets = Table.clone(runtime.qualityPresets)

	self.qualityPresetsByName = Table.arrayToSet(self.qualityPresets)
	assert(
		self:hasQualityPreset(self.defaultQualityPreset),
		"default quality preset '%s' not a valid quality preset",
		self.defaultQualityPreset
	)

	self.properties = {}
	self.propertiesByKey = {}
	self.propertiesByIdentifier = {}

	assert(
		runtime.properties and #runtime.properties >= 1,
		"expected at least one property"
	)
	for _, property in ipairs(runtime.properties) do
		assert(
			not self:hasPropertyKey(property.key),
			"property with key '%s' previously defined",
			property.key
		)
		assert(
			not self:hasPropertyIdentifier(property.identifier),
			"property with identifier '%s' previously defined",
			property.identifier
		)
		assert(
			not (
					self:hasPropertyKey(property.identifier)
					or self:hasPropertyIdentifier(property.key)
				),
			"ambigious property (identifier with key %s or key with identifier %s)",
			property.identifier,
			property.key
		)
		assert(
			property.key ~= property.identifier,
			"property key cannot be the same value as property identifier: %s",
			property.key
		)

		local propertyInstance = PipelineProperty(property)

		table.insert(self.properties, propertyInstance)
		self.propertiesByKey[property.key] = propertyInstance
		self.propertiesByIdentifier[property.identifier] = propertyInstance
	end

	self.settings = {}
	self.settingsByKey = {}
	self.propertyToSetting = {}

	for _, setting in ipairs(runtime.settings) do
		assert(
			not self.settingsByKey[setting.key],
			"setting with key %s already exists",
			setting.key
		)

		for _, property in ipairs(setting.properties) do
			assert(
				self.propertyToSetting[property] == nil,
				"property %s already used in setting %s",
				property,
				self.propertyToSetting[property]
					and self.propertyToSetting[property]:getKey()
			)
		end

		local settingInstance = PipelineSetting(setting)
		table.insert(self.settings, settingInstance)
		self.settingsByKey[setting.key] = settingInstance
		self.propertyToSetting[setting.key] = settingInstance
	end

	self.currentProperties = {}
	for _, qualityPreset in ipairs(self.qualityPresets) do
		self.currentProperties[qualityPreset] = {}
	end

	self.virtualPaths = {}
	self:setCurrentProperties(currentProperties or {})
end

--- @param currentProperties RatScratch.Pipeline.PipelineProperties
function PipelineRuntime:setCurrentProperties(currentProperties)
	for qualityPreset, properties in pairs(currentProperties) do
		assert(
			self:hasQualityPreset(qualityPreset),
			"quality preset %s not found",
			qualityPreset
		)

		for property, value in pairs(properties) do
			self.currentProperties[qualityPreset][property] = {
				unpack(value),
			}
		end
	end

	for _, qualityPreset in ipairs(self.qualityPresets) do
		for _, property in ipairs(self.properties) do
			local key = property:getKey()
			if not self.currentProperties[qualityPreset][key] then
				local setting = self.propertyToSetting[key]
				local preset = setting and setting:getPreset("low")

				if not preset then
					self.currentProperties[qualityPreset][key] = {
						property:getValue(),
					}
				else
					self.currentProperties[qualityPreset][key] = {
						preset:getValue(qualityPreset, key),
					}
				end
			end
		end
	end

	self:_loadConfigShaders()
end

do
	--- @type RatScratch.Graphics.ShaderPreprocessOptions?
	local _defaultShaderOptions

	--- @private
	--- @param virtualPaths table<string, string>?
	--- @return RatScratch.Graphics.ShaderPreprocessOptions
	function PipelineRuntime._getDefaultShaderOptions(virtualPaths)
		if not _defaultShaderOptions then
			_defaultShaderOptions = {
				rootPath = ("%s/Shaders"):format(
					RatScratchModule.getSelfPath("rat-scratch-graphics")
				),
				rootPaths = {
					Pipeline = ("%s/Shaders"):format(
						RatScratchModule.getSelfPath(PATH)
					),
				},
			}
		end

		_defaultShaderOptions.virtualPaths = virtualPaths

		return _defaultShaderOptions
	end
end

--- @private
--- @param qualityPreset string
function PipelineRuntime:_loadConfigShaderForPreset(qualityPreset)
	local variables = {
		RAT_SCRATCH_PROPERTIES = {},
		RAT_SCRATCH_FLAGS = {},
	}

	for _, property in ipairs(self.properties) do
		local currentValue =
			self.currentProperties[qualityPreset][property:getKey()]

		if property:getFormat() == "boolean" then
			table.insert(variables.RAT_SCRATCH_FLAGS, {
				RAT_SCRATCH_IDENTIFIER = property:getIdentifier(),
				RAT_SCRATCH_VALUE = currentValue[1] and "true" or "false",
			})
		else
			local format = property:getFormat()
			local componentCount = BufferFormat.getFormatComponentCount(format)
			local shaderType = BufferFormat.getFormatShaderType(format)
			local scalarType = BufferFormat.getFormatShaderType(
				BufferFormat.getFormatScalar(format)
			)

			local values = {}
			for i = 1, componentCount do
				table.insert(values, {
					RAT_SCRATCH_SCALAR = scalarType,
					RAT_SCRATCH_VALUE = currentValue[i] or 0,
				})
			end

			table.insert(variables.RAT_SCRATCH_PROPERTIES, {
				RAT_SCRATCH_TYPE = shaderType,
				RAT_SCRATCH_IDENTIFIER = property:getIdentifier(),
				RAT_SCRATCH_VALUES = values,
			})
		end
	end

	local source, result = self:_preprocess(
		"@Pipeline/Config/Config.template.glsl",
		{ variables = variables }
	)

	local message = ShaderPreprocessor.validateResult(source, result)
	if message then
		error(message)
	end

	self.virtualPaths[qualityPreset] = {
		["generated:/Pipeline/Config.common.glsl"] = source,
	}
end

function PipelineRuntime:_loadConfigShaders()
	for _, qualityPreset in ipairs(self.qualityPresets) do
		self:_loadConfigShaderForPreset(qualityPreset)
	end
end

function PipelineRuntime:getVirtualPaths(qualityPreset)
	return self.virtualPaths[qualityPreset]
end

function PipelineRuntime:getConfig()
	return self.config
end

--- @return integer
function PipelineRuntime:getQualityPresetCount()
	return #self.qualityPresets
end

--- @param index integer
--- @return string
function PipelineRuntime:getQualityPreset(index)
	return self.qualityPresets[index]
end

function PipelineRuntime:getDefaultQualityPreset()
	return self.defaultQualityPreset
end

--- @param value string
--- @return boolean
function PipelineRuntime:hasQualityPreset(value)
	return self.qualityPresetsByName[value] ~= nil
end

--- @param key string
--- @return boolean
function PipelineRuntime:hasPropertyKey(key)
	return self.propertiesByKey[key] ~= nil
end

--- @param key string
--- @return boolean
function PipelineRuntime:hasPropertyIdentifier(key)
	return self.propertiesByIdentifier[key] ~= nil
end

--- @param key string | integer
--- @return boolean
function PipelineRuntime:hasProperty(key)
	return not not (
		self.propertiesByKey[key]
		or self.propertiesByIdentifier[key]
		or self.properties[key]
	)
end

--- @param key string | integer
--- @return RatScratch.Pipeline.PipelineProperty
function PipelineRuntime:getProperty(key)
	return self.propertiesByKey[key]
		or self.propertiesByIdentifier[key]
		or self.properties[key]
end

do
	--- @param source RatScratch.Graphics.ShaderPreprocessOptions?
	--- @param destination RatScratch.Graphics.ShaderPreprocessOptions
	local function _merge(source, destination)
		if not source then
			return
		end

		--- @type table<string, string>?
		local rootPaths = destination.rootPaths or {}

		--- @type table<string, string>?
		local virtualPaths = destination.virtualPaths or {}

		for k, v in pairs(source) do
			destination[k] = v
		end

		if source.rootPaths then
			for k, v in pairs(source.rootPaths) do
				rootPaths[k] = v
			end
		elseif source.rootPaths == false then
			rootPaths = nil
		end

		if source.virtualPaths then
			for k, v in pairs(source.virtualPaths) do
				virtualPaths[k] = v
			end
		elseif source.virtualPaths == false then
			virtualPaths = nil
		end

		destination.rootPaths = rootPaths
		destination.virtualPaths = virtualPaths
	end

	--- @param options? RatScratch.Graphics.ShaderPreprocessOptions
	--- @param defaultOptions RatScratch.Graphics.ShaderPreprocessOptions
	local function _getMergedOptions(options, defaultOptions)
		if not options then
			return defaultOptions
		end

		local resultOptions = {}
		_merge(defaultOptions, resultOptions)
		_merge(options, resultOptions)

		return resultOptions
	end

	--- @private
	--- @param filename string
	--- @param options? RatScratch.Graphics.ShaderPreprocessOptions
	function PipelineRuntime:_preprocess(filename, options)
		local resultOptions = _getMergedOptions(
			options,
			PipelineRuntime._getDefaultShaderOptions()
		)

		return ShaderPreprocessor.preprocess(filename, resultOptions)
	end

	--- @param filename string
	--- @param qualityPreset? string
	--- @param options? RatScratch.Graphics.ShaderPreprocessOptions
	--- @return love.Shader
	function PipelineRuntime:loadComputeShader(filename, qualityPreset, options)
		local resultOptions = _getMergedOptions(
			options,
			PipelineRuntime._getDefaultShaderOptions(
				self.virtualPaths[qualityPreset or self.defaultQualityPreset]
			)
		)

		return ShaderPreprocessor.newComputeShader(filename, resultOptions)
	end

	--- @param pixelFilename string
	--- @param vertexFilename? string
	--- @param qualityPreset? string
	--- @param options? RatScratch.Graphics.ShaderPreprocessOptions
	--- @return love.Shader
	function PipelineRuntime:loadShader(
		pixelFilename,
		vertexFilename,
		qualityPreset,
		options
	)
		local resultOptions = _getMergedOptions(
			options,
			PipelineRuntime._getDefaultShaderOptions(
				self.virtualPaths[qualityPreset or self.defaultQualityPreset]
			)
		)

		return ShaderPreprocessor.newShader(
			pixelFilename,
			vertexFilename,
			resultOptions
		)
	end
end

--- @param currentProperties? RatScratch.Pipeline.PipelineProperties
--- @return RatScratch.Pipeline.PipelineRuntime
function PipelineRuntime.loadDefault(currentProperties)
	local path = RatScratchModule.getSelfPath(PATH)
	local defaultRuntimeFilename = ("%s/Config/Default/Runtime.json"):format(
		path
	)
	local defaultRuntimeData = love.filesystem.read(defaultRuntimeFilename)

	assert(
		defaultRuntimeData,
		"could not load default runtime config at path '%s'",
		defaultRuntimeFilename
	)

	--- @type RatScratch.Pipeline.PipelineRuntimeDefinition
	local defaultRuntimeJson = json.decode(defaultRuntimeData)

	return PipelineRuntime(
		defaultRuntimeJson.runtime,
		PipelineConfig.loadDefault(),
		currentProperties
	)
end

return PipelineRuntime
