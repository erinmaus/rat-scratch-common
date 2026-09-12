local Object = require("rat-scratch-common").Object
local assert = require("rat-scratch-common").Debug.assert
local PipelineSettingPreset =
	require("rat-scratch-pipeline.PipelineSettingPreset")

--- @class RatScratch.Pipeline.PipelineSetting : RatScratch.Common.BaseObject
--- @field private key string
--- @field private properties string[]
--- @field private propertiesByName table<string, true>
--- @field private presets table<string, RatScratch.Pipeline.PipelineSettingPreset>
--- @overload fun(setting: RatScratch.Pipeline.PipelineRuntimeConfigSetting): RatScratch.Pipeline.PipelineSetting
local PipelineSetting = Object()

--- @param setting RatScratch.Pipeline.PipelineRuntimeConfigSetting
function PipelineSetting:new(setting)
	self.key = setting.key

	self.propertiesByName = {}
	self.properties = {}
	for _, property in ipairs(setting.properties) do
		assert(
			not self:hasProperty(property),
			"duplicate property %s",
			property
		)
		table.insert(self.properties, property)
		self.propertiesByName[property] = true
	end

	self.presets = {}
	for key, preset in pairs(setting.presets) do
		self.presets[key] = PipelineSettingPreset(self, preset)
	end
end

--- @return string
function PipelineSetting:getKey()
	return self.key
end

--- @return integer
function PipelineSetting:getPropertyCount()
	return #self.properties
end

--- @param index integer
--- @return string
function PipelineSetting:getProperty(index)
	return self.properties[index]
end

--- @param name string
--- @return boolean
function PipelineSetting:hasProperty(name)
	return self.propertiesByName[name] ~= nil
end

--- @param name string
--- @return boolean
function PipelineSetting:hasPreset(name)
	return self.presets[name] ~= nil
end

--- @param name string
--- @return RatScratch.Pipeline.PipelineSettingPreset
function PipelineSetting:getPreset(name)
	return self.presets[name]
end

--- @param instance table<string, table<string, table<string, (boolean | number | integer)[]>>>
--- @return string?
function PipelineSetting:match(instance)
	for presetName, properties in pairs(self.presets) do
		local isMatch = true
		for qualityPreset, p in pairs(instance) do
			if not properties:match(qualityPreset, p) then
				isMatch = false
				break
			end
		end

		if isMatch then
			return presetName
		end
	end

	return nil
end

return PipelineSetting
