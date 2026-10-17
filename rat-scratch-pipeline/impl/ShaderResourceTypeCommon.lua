local PATH = ...
local RatScratchModule = require("lib.rat-scratch-module")

local ShaderResourceTypeCommon = {}

local REQUIRED_OPTIONS = {
	warnings = true,
	errors = true,
	safe = true,
	dependencies = true,
}

--- @param options? RatScratch.Graphics.ShaderPreprocessOptions
--- @return RatScratch.Graphics.ShaderPreprocessOptions
function ShaderResourceTypeCommon.mergePreprocessOptions(options)
	local result = {}

	if options then
		for k, v in pairs(options) do
			result[k] = v
		end
	end

	for k, v in pairs(REQUIRED_OPTIONS) do
		if not result[k] then
			result[k] = v
		end
	end

	if not result.rootPath then
		result.rootPath = ("%s/Shaders"):format(
			RatScratchModule.getSelfPath("rat-scratch-graphics")
		)
	end

	if not result.rootPaths or not result.rootPaths["Pipeline"] then
		result.rootPaths = result.rootPaths or {}
		result.rootPaths["Pipeline"] = ("%s/Shaders"):format(
			("%s/"):format(RatScratchModule.getSelfPath(PATH))
		)
	end

	return result
end

return ShaderResourceTypeCommon
