local PATH = ...
local Object = require("rat-scratch-common").Object
local ResourceType = require("rat-scratch-resource").ResourceType
local ShaderPreprocessor = require("rat-scratch-graphics").ShaderPreprocessor
local ShaderFragment = require("rat-scratch-pipeline.ShaderFragment")
local ShaderResourceTypeCommon =
	require("rat-scratch-pipeline.impl.ShaderResourceTypeCommon")

--- @class RatScratch.Pipeline.ShaderFragmentResourceType.Data
--- @field public source string
local ShaderFragmentResourceTypeData = {}

--- @class RatScratch.Pipeline.ShaderFragmentResourceType.ResourceArguments
--- @field public filename string
--- @field public options? RatScratch.Graphics.ShaderPreprocessOptions
local ShaderFragmentResourceTypeData = {}

--- @param args RatScratch.Pipeline.ShaderFragmentResourceType.ResourceArguments
--- @return RatScratch.Pipeline.ShaderFragmentResourceType.ResourceArguments
local function _getResourceArguments(args)
	if type(args) == "string" then
		return {
			filename = args,
			options = ShaderResourceTypeCommon.mergePreprocessOptions(),
		}
	end

	return {
		filename = args.filename,
		options = ShaderResourceTypeCommon.mergePreprocessOptions(args.options),
	}
end

--- @class RatScratch.Pipeline.ShaderFragmentResourceType : RatScratch.Resource.ResourceType<love.Shader, RatScratch.Pipeline.ShaderFragmentResourceType.Data>
--- @overload fun(): RatScratch.Resource.ResourceType<love.Shader, RatScratch.Pipeline.ShaderFragmentResourceType.Data>
local ShaderFragmentResourceType = Object(ResourceType)

--- @param args RatScratch.Pipeline.ShaderFragmentResourceType.ResourceArguments
--- @param parentPath string
--- @return string ...
function ShaderFragmentResourceType:resolvePath(args, parentPath)
	return ResourceType.resolvePath(self, args.filename, parentPath)
end

--- @param hint RatScratch.Pipeline.ShaderFragmentResourceType.Data
function ShaderFragmentResourceType:createDefaultResource(hint)
	return ShaderFragment("// nothin'")
end

--- @param filename table
function ShaderFragmentResourceType:loadDataFromFile(filename)
	local args = _getResourceArguments(filename)

	local result = {}
	local workingDependencies = {}
	do
		local s, o = ShaderPreprocessor.preprocess(args.filename, args.options)
		local r = ShaderPreprocessor.validateResult(s, o, true)
		if r then
			error(r)
		end

		result.source = s

		if o then
			for _, d in ipairs(o.dependencies) do
				workingDependencies[d] = true
			end
		end
	end

	local dependencies = {}
	for d in pairs(workingDependencies) do
		table.insert(dependencies, d)
	end
	table.sort(dependencies)

	return result, dependencies
end

--- @param resource RatScratch.Resource.Resource<RatScratch.Pipeline.ShaderFragment>
--- @param data RatScratch.Pipeline.ShaderFragmentResourceType.Data
function ShaderFragmentResourceType:updateFromData(resource, data)
	resource:set(ShaderFragment(data.source))

	return resource
end

return ShaderFragmentResourceType
