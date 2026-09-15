local Object = require("rat-scratch-common").Object
local Table = require("rat-scratch-common.Table")

--- @class RatScratch.Pipeline.PipelineSettingPreset : RatScratch.Common.BaseObject
--- @field private presets table<string, table<string, (number | integer | boolean)[]>>
--- @overload fun(setting: RatScratch.Pipeline.PipelineSetting, preset: table<string, table<string, (number | integer | boolean)[]>>): RatScratch.Pipeline.PipelineSettingPreset
local PipelineSettingPreset = Object()

--- @param setting RatScratch.Pipeline.PipelineSetting
--- @param preset table<string, table<string, (number | integer | boolean)[]>>
function PipelineSettingPreset:new(setting, preset)
	for qualityPreset, properties in pairs(preset) do
		local count = 0
		for property in pairs(properties) do
			count = count + 1
			assert(
				setting:hasProperty(property),
				"property %s not in scope for setting %s",
				property,
				setting:getKey()
			)
		end

		assert(
			count == setting:getPropertyCount(),
			"quality preset %s missing one or more properties",
			qualityPreset
		)
	end

	self.presets = Table.deepClone(preset)
end

--- @param qualityPreset string
--- @param property string
--- @return boolean
function PipelineSettingPreset:hasValue(qualityPreset, property)
	return self.presets[qualityPreset] ~= nil
		and self.presets[qualityPreset][property] ~= nil
end

--- @param qualityPreset string
--- @param property string
--- @return boolean|number|integer ...
function PipelineSettingPreset:getValue(qualityPreset, property)
	assert(
		self:hasValue(qualityPreset, property),
		"property %s at quality preset %s is not set",
		property,
		qualityPreset
	)
	return unpack(self.presets[qualityPreset][property])
end

--- @param qualityPreset string
--- @param properties table<string, (number | integer | boolean)[]>
--- @return boolean
function PipelineSettingPreset:match(qualityPreset, properties)
	local selfProperties = self.presets[qualityPreset]

	for selfProperty, selfValues in pairs(selfProperties) do
		if properties[selfProperty] == nil then
			return false
		end

		for i, selfValue in ipairs(selfValues) do
			if selfValue ~= properties[selfProperty][i] then
				return false
			end
		end
	end

	return true
end

return PipelineSettingPreset
